#!/usr/bin/env bash
# Kubernetes host setup script for CentOS

master=$1
#KUBEMASTER=10.128.0.5
#K8S_VER=1.14.5
#K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2)
#curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5

if [[ ! $master =~ ^( |master|node)$ ]]; then 
 echo "Usage: host-setup.sh <master or node>"
 echo "Example: host-setup.sh master/node"
 exit
fi

# Stopping and disabling firewalld by running the commands on all servers:
systemctl stop firewalld
systemctl disable firewalld

# Disable swap. Kubeadm will check to make sure that swap is disabled when we run it, so lets turn swap off and disable it for future reboots.
swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

# Disable SELinux
setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

# Add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 
cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-\$basearch
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kubelet kubeadm kubectl
EOF

# Install some of the tools (including CRI-O, kubeadm & kubelet) we’ll need on our servers.
yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet dos2unix java-1.7.0-openjdk

# Setup for docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

systemctl start docker; systemctl status docker; systemctl enable docker

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
systemctl restart docker

# Installation with specefic version
#yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER kubernetes-cni-0.6.0 --disableexcludes=kubernetes
if [[ "$K8S_VER" == "" ]]; then
 yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes
else
 yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER --disableexcludes=kubernetes
fi


# After installing crio and our kubernetes tools, we’ll need to enable the services so that they persist across reboots, and start the services so we can use them right away.
systemctl enable --now kubelet; systemctl start kubelet; systemctl status kubelet

# Setting up Kubernetes Node using Kubeadm
if [[ "$master" == "node" ]]; then
  echo ""
  echo "Waiting for Master ($KUBEMASTER) API response .."
  while ! echo break | nc $KUBEMASTER 6443 &> /dev/null; do printf '.'; sleep 2; done
  kubeadm join --discovery-token-unsafe-skip-ca-verification --token=$TOKEN $KUBEMASTER:6443
  exit
fi

# Setting up Kubernetes Master using Kubeadm
kubeadm init --token=$TOKEN --pod-network-cidr=10.244.0.0/16 --kubernetes-version $(kubeadm version -o short) --ignore-preflight-errors=all | grep -Ei "kubeadm join|discovery-token-ca-cert-hash" 2>&1 | tee kubeadm-output.txt

sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf
echo "export KUBECONFIG=$HOME/admin.conf" >> $HOME/.bash_profile
echo "alias oc=/usr/bin/kubectl" >> /root/.bash_profile

mkdir setup-files
cd setup-files

wget https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
kubectl create -f kube-flannel.yml

sleep 20
kubectl get nodes

# Make Master scheduble
MASTER=`kubectl get nodes | grep master | awk '{print $1}'`
kubectl taint nodes $MASTER node-role.kubernetes.io/master-
kubectl get nodes -o json | jq .items[].spec.taints

# Setup Metric Server
kubectl apply -f https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/monitoring/metric-server.yaml

# Setup Ingress
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/kube-ingress.yaml
sed -i "s/kube-master/$MASTER/g" kube-ingress.yaml
kubectl create ns kube-router
kubectl create -f kube-ingress.yaml

# Setup Helm Chart
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/misc/helm-setup.sh
chmod +x ./helm-setup.sh
./helm-setup.sh

# Setup for Monitring and Logging
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/misc/monitoring-setup.sh
chmod +x ./monitoring-setup.sh
#./monitoring-setup.sh

# Deploying dynamic NFS based persistant storage
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/misc/nfsstorage-setup.sh
chmod +x ./nfsstorage-setup.sh
#./nfsstorage-setup.sh

# Setup Velero Backup
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/misc/backup-setup.sh
chmod +x ./backup-setup.sh
#./backup-setup.sh
    
# Setup Demo Application
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/demo/mongo-employee.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/tracing/hotrod-app.yaml
#kubectl create ns demo-mongo
#kubectl create -f mongo-employee.yaml -n demo-mongo

# Setup Tracing Backup
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/misc/tracing-setup.sh
chmod +x ./tracing-setup.sh
#./tracing-setup.sh

# Kafka setup
wget https://raw.githubusercontent.com/cloudcafetech/ocpsetup/master/kafka-setup.sh
chmod +x ./kafka-setup.sh
#./kafka-setup.sh

# Install krew
set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
  "$KREW" update
  
export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

# Install kubectl plugins using krew
kubectl krew install modify-secret
kubectl krew install ctx
kubectl krew install ns

echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> /root/.bash_profile

Kubectl get nodes
