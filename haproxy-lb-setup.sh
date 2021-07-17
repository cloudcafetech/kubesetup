#!/bin/bash
# Install & Configure HA Proxy LB & Management Server

MASTER1_HOSTNAME=ip-172-31-26-73.us-east-2.compute.internal
MASTER2_HOSTNAME=ip-172-31-23-236.us-east-2.compute.internal
MASTER3_HOSTNAME=ip-172-31-20-131.us-east-2.compute.internal
MASTER1_IP=172.31.26.73
MASTER2_IP=172.31.23.236
MASTER3_IP=172.31.20.131

PUB=`curl http://169.254.169.254/latest/meta-data/public-ipv4`
MinIO=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
velver=v1.4.2

# Install packages
echo "Installing Packges"
yum install -q -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils dos2unix nmap telnet java-1.8.0-openjdk haproxy

# Install Docker
if ! command -v docker &> /dev/null;
then
  echo "MISSING REQUIREMENT: docker engine could not be found on your system. Please install docker engine to continue: https://docs.docker.com/get-docker/"
  echo "Trying to Install Docker..."
  if [[ $(uname -a | grep amzn) ]]; then
    echo "Installing Docker for Amazon Linux"
    amazon-linux-extras install docker -y
    systemctl enable docker;systemctl start docker
    docker ps -a
  else
    curl -s https://releases.rancher.com/install-docker/19.03.sh | sh
    systemctl enable docker;systemctl start docker
    docker ps -a
  fi    
fi


# Install KIND
if ! command -v kind &> /dev/null;
then
 echo "Installing Kind"
 curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
 chmod +x ./kind; mv ./kind /usr/local/bin/kind
fi

# Install Kubectl
if ! command -v kubectl &> /dev/null;
then
 echo "Installing Kubectl"
 K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)
 wget -q https://storage.googleapis.com/kubernetes-release/release/$K8S_VER/bin/linux/amd64/kubectl
 chmod +x ./kubectl; mv ./kubectl /usr/bin/kubectl
 echo "alias oc=/usr/bin/kubectl" >> /root/.bash_profile
fi 

# Install Minio CLI
if ! command -v mc &> /dev/null;
then
 echo "Installing Minio CLI"
 wget https://dl.min.io/client/mc/release/linux-amd64/mc; chmod +x mc; mv -v mc /usr/local/bin/mc
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

systemctl restart haproxy
systemctl status haproxy

# Verify
echo "Verify HA Proxy Load Balancer .."
nc -v -w 1 localhost 6443

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

# Host setup Script Download
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/k8s-host-setup.sh
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/node-joining-script.sh
chmod +x ./k8s-host-setup.sh
chmod +x ./node-joining-script.sh

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
