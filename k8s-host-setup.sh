#!/usr/bin/env bash
# Kubernetes host setup script for Linux (CentOS,RHEL,Amazon)

#K8S_VER=1.14.5
#K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2)
#curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more

# Install some of the tools (including CRI-O, kubeadm & kubelet) we’ll need on our servers.
sudo yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet tc dos2unix java-1.7.0-openjdk

# Install Docker
if ! command -v docker &> /dev/null;
then
  echo "MISSING REQUIREMENT: docker engine could not be found on your system. Please install docker engine to continue: https://docs.docker.com/get-docker/"
  echo "Trying to Install Docker..."
  if [[ $(uname -a | grep amzn) ]]; then
    echo "Installing Docker for Amazon Linux"
    sudo amazon-linux-extras install docker -y
  else
    sudo curl -s https://releases.rancher.com/install-docker/19.03.sh | sh
  fi    
fi

sudo systemctl start docker; sudo systemctl status docker; sudo systemctl enable docker

# Stopping and disabling firewalld by running the commands on all servers:
sudo systemctl stop firewalld
sudo systemctl disable firewalld

# Disable swap. Kubeadm will check to make sure that swap is disabled when we run it, so lets turn swap off and disable it for future reboots.
sudo swapoff -a
sudo sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

# Disable SELinux
sudo setenforce 0
sudo sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# Add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 
sudo cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Change default cgroup driver to systemd 
sudo cat > daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

sudo cp daemon.json /etc/docker/daemon.json
sudo systemctl start docker; sudo systemctl status docker; sudo systemctl enable docker

sudo cat <<EOF > k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sudo cp k8s.conf /etc/sysctl.d/k8s.conf
sudo sysctl --system
sudo systemctl restart docker
sudo systemctl status docker

# Installation with specefic version
#yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER kubernetes-cni-0.6.0 --disableexcludes=kubernetes
if [[ "$K8S_VER" == "" ]]; then
 sudo yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
else
 sudo yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER --disableexcludes=kubernetes
fi

# After installing container runtime and our kubernetes tools
# we’ll need to enable the services so that they persist across reboots, and start the services so we can use them right away.
sudo systemctl enable --now kubelet; sudo systemctl start kubelet; sudo systemctl status kubelet
