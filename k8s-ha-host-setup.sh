#!/usr/bin/env bash
# Kubernetes host setup script for CentOS

master=$1
HA_PROXY_LB_DNS=172.31.28.205
HA_PROXY_LB_PORT=6443

MASTER1_HOSTNAME=ip-172-31-26-135.us-east-2.compute.internal
MASTER2_HOSTNAME=ip-172-31-21-124.us-east-2.compute.internal
MASTER3_HOSTNAME=ip-172-31-31-51.us-east-2.compute.internal
MASTER1_IP=172.31.26.135
MASTER2_IP=172.31.21.124
MASTER3_IP=172.31.31.51

if [[ ! $master =~ ^( |master1|node|lb)$ ]]; then 
 echo "Usage: host-setup.sh <master1 or lb>"
 echo "Example: host-setup.sh master1/lb"
 exit
fi

PUB=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
MinIO=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
velver=v1.4.2

#K8S_VER=1.14.5
#K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2)
#curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
CERTKEY=d60a03f140d7f245c06879ac6ab22aa3408b85a60edb94917d67add3dc2a5fa7

# Install some of the tools (including CRI-O, kubeadm & kubelet) we’ll need on our servers.
yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet tc dos2unix java-1.7.0-openjdk

# Install Docker
if ! command -v docker &> /dev/null;
then
  echo "MISSING REQUIREMENT: docker engine could not be found on your system. Please install docker engine to continue: https://docs.docker.com/get-docker/"
  echo "Trying to Install Docker..."
  if [[ $(uname -a | grep amzn) ]]; then
    echo "Installing Docker for Amazon Linux"
    amazon-linux-extras install docker -y
  else
    curl -s https://releases.rancher.com/install-docker/19.03.sh | sh
  fi    
fi

# Setup for HA Proxy Load Balancer
if [[ "$master" == "lb" ]]; then

systemctl start docker; systemctl status docker; systemctl enable docker

echo "Initialize HA Proxy Load Balancer"
yum install -y haproxy

# Setup HAProxy LB
cat <<EOT >> /etc/haproxy/haproxy.cfg
frontend fe-apiserver
   bind 0.0.0.0:6443
   mode tcp
   option tcplog
   default_backend be-apiserver

backend be-apiserver
   mode tcp
   option tcplog
   option tcp-check
   balance roundrobin
   default-server inter 10s downinter 5s rise 2 fall 2 slowstart 60s maxconn 250 maxqueue 256 weight 100

       server $MASTER1_HOSTNAME $MASTER1_IP:6443 check
       server $MASTER2_HOSTNAME $MASTER2_IP:6443 check
       server $MASTER3_HOSTNAME $MASTER3_IP:6443 check
EOT

systemctl restart haproxy;systemctl status haproxy

# Verify
echo "Verify HA Proxy Load Balancer .."
nc -v localhost 6443

# Install Kubectl
  if ! command -v kubectl &> /dev/null;
  then
   echo "Installing Kubectl"
   K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
   wget -q https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/amd64/kubectl
   chmod +x ./kubectl; mv ./kubectl /usr/bin/kubectl
   echo "alias oc=/usr/bin/kubectl" >> /root/.bash_profile
  fi 

# Install Backup tool
  if ! command -v velero &> /dev/null;
  then
   echo "Installing Backup tool"
   wget https://github.com/vmware-tanzu/velero/releases/download/$velver/velero-$velver-linux-amd64.tar.gz
   tar -xvzf velero-$velver-linux-amd64.tar.gz
   mv -v velero-$velver-linux-amd64/velero /usr/local/bin/velero
   echo "alias vel=/usr/local/bin/velero" >> /root/.bash_profile
   rm -rf velero-$velver-linux-amd64*
   fi

# Install Minio CLI
  if ! command -v mc &> /dev/null;
  then
   echo "Installing Minio CLI"
   wget https://dl.min.io/client/mc/release/linux-amd64/mc; chmod +x mc; mv -v mc /usr/local/bin/mc
  fi

# Setup Minio
  mkdir -p /root/minio/data
  mkdir -p /root/minio/config

  chcon -Rt svirt_sandbox_file_t /root/minio/data
  chcon -Rt svirt_sandbox_file_t /root/minio/config

  docker run -d -p 9000:9000 --restart=always --name minio \
  -e "MINIO_ACCESS_KEY=admin" \
  -e "MINIO_SECRET_KEY=admin2675" \
  -v /root/minio/data:/data \
  -v /root/minio/config:/root/.minio \
  minio/minio server /data

  sleep 25
# Checks Mino Container running or not
  if [ $(docker inspect -f '{{.State.Running}}' minio) = "true" ]; then echo Running; else echo Not Running; fi

# Creating Bucket in Minio
  mc config host add minio http://$MinIO:9000 admin admin2675 --insecure
  mc mb minio/monitoring --insecure
  mc mb minio/logging --insecure
  mc mb minio/tracing --insecure
  mc mb minio/backup --insecure

# Setting Kubeconfig
  mkdir -p $HOME/.kube
  touch $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bash_profile

# download node Joinging script
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/node-joining-script.sh
chmod 755 node-joining-script.sh

# Install Krew
set -x; cd "$(mktemp -d)" &&
  curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew.{tar.gz,yaml}" &&
  tar zxvf krew.tar.gz &&
  KREW=./krew-"$(uname | tr '[:upper:]' '[:lower:]')_amd64" &&
  "$KREW" install --manifest=krew.yaml --archive=krew.tar.gz &&
  "$KREW" update

  export PATH="${KREW_ROOT:-$HOME/.krew}/bin:$PATH"

  kubectl krew install modify-secret
  kubectl krew install ctx
  kubectl krew install ns
  kubectl krew install cost

  echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> /root/.bash_profile
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

# Change default cgroup driver to systemd 
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF

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


# After installing container runtime and our kubernetes tools
# we’ll need to enable the services so that they persist across reboots, and start the services so we can use them right away.
systemctl enable --now kubelet; systemctl start kubelet; systemctl status kubelet

# Checking Load Balancer response
LBTEST=`nc -w 2 -v $HA_PROXY_LB_DNS $HA_PROXY_LB_PORT </dev/null; echo $?`
if [[ "$LBTEST" == "0" ]]; then
  echo "OK - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) responding."
else 
  echo "NOT Good - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) NOT responding."
  echo "Please Check Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT), before proceeding."
  exit
fi

# Start First Master Host Initialization
#echo "Initialize Master1"
#kubeadm init --control-plane-endpoint "$HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT" --upload-certs --pod-network-cidr=192.168.0.0/16 --kubernetes-version $(kubeadm version -o short) --ignore-preflight-errors=all | tee kubeadm-output.txt

# Start First Master Host Initialization
if [[ "$master" == "master1" ]]; then
  echo "Initialize Master#1"
  kubeadm init --token=$TOKEN --control-plane-endpoint "$HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT" --upload-certs --certificate-key=$CERTKEY --pod-network-cidr=192.168.0.0/16 --kubernetes-version $(kubeadm version -o short) --ignore-preflight-errors=all | tee kubeadm-output.txt
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config
  # Deploying Calico Network
  kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
  exit
fi

# Setting up Kubernetes Node using Kubeadm
if [[ "$master" == "node" ]]; then
  echo "For Controller and node Run joining script"
  exit
fi
