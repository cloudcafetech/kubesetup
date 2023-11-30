#!/usr/bin/env bash
# Kubernetes host setup script using Kubeadm for Debian & Redhat distribution

K8S_VER=1.26.0-00
#K8S_LATEST=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2)
#curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more
if [[ -n $(uname -a | grep -iE 'ubuntu|debian') ]]; then OS=Ubuntu; fi

if [[ "$K8S_VER" == "" ]]; then K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2); fi
K8S_VER_MJ=$(echo "$K8S_VER" | cut -c 1-4)

# Disable swap
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

cat <<EOF |sudo tee /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

cat <<EOF | sudo tee /etc/modules-load.d/containerd.conf 
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

sysctl --system

## Installation based on OS

### For Debian distribution
if [[ "$OS" == "Ubuntu" ]]; then
 # Stopping and disabling firewalld by running the commands on all servers:
 systemctl stop ufw
 systemctl disable ufw
 # Install some of the tools, we’ll need on our servers.
 apt update
 apt install apt-transport-https ca-certificates gpg nfs-common curl wget git net-tools unzip jq zip nmap telnet dos2unix apparmor -y
 mkdir -m 755 /etc/apt/keyrings
 curl -fsSL https://pkgs.k8s.io/core:/stable:/v${K8S_VER_MJ}/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
 echo deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VER_MJ/deb/ / | sudo tee /etc/apt/sources.list.d/kubernetes.list

 # Install Container Runtime, Kubeadm, Kubelet & Kubectl
 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
 add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" -y
 apt update
 rm -I /etc/containerd/config.toml 
 apt install -y containerd.io
 apt install -y kubelet kubeadm kubectl
 apt-mark hold kubelet kubeadm kubectl

### For Redhat distribution

else
 # Stopping and disabling firewalld & SELinux
 systemctl stop firewalld
 systemctl disable firewalld
 setenforce 0
 sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux
 # Install some of the tools, we’ll need on our servers.
 yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet dos2unix java-1.7.0-openjdk

# Add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v$K8S_VER_MJ/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v$K8S_VER_MJ/rpm/repodata/repomd.xml.key
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

 # Install Container Runtime, Kubeadm, Kubelet & Kubectl
 yum config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
 yum install -y yum-utils containerd.io && rm -I /etc/containerd/config.toml
 yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
fi

## Installation based on OS 

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml 
sed -i -e 's\            SystemdCgroup = false\            SystemdCgroup = true\g' /etc/containerd/config.toml

cat <<EOF | tee /etc/crictl.yaml
runtime-endpoint: "unix:///run/containerd/containerd.sock"
timeout: 0
debug: false
EOF

# After installing containerd, kubernetes tools  & enable the services so that they persist post reboots.
systemctl enable --now containerd; systemctl start containerd
#systemctl status containerd
systemctl enable --now kubelet; systemctl start kubelet
#systemctl status kubelet

# K8s images pull
kubeadm config images pull
