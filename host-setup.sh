#!/bin/bash
# Kubernetes host setup script for CentOS

master=$1
KUBEMASTER=10.128.0.5
MinIO=10.128.0.9
NFSRV=10.128.0.9
NFSMOUNT=/root/nfs/nfsdata
#K8S_VER=1.14.5
K8S_VER=$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt | cut -d v -f2)
CRI=docker
velver=v1.4.2
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
#CRI=crio

if [[ "$master" == "" || "$master" != "master" || "$master" != "node" ]]; then
 echo "Usage: host-setup.sh <master or node>"
 echo "Example: host-setup.sh master/node"
 exit
fi


#Stopping and disabling firewalld by running the commands on all servers:

systemctl stop firewalld
systemctl disable firewalld

#Disable swap. Kubeadm will check to make sure that swap is disabled when we run it, so lets turn swap off and disable it for future reboots.

swapoff -a
sed -i.bak -r 's/(.+ swap .+)/#\1/' /etc/fstab

#Disable SELinux

setenforce 0
sed -i --follow-symlinks 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/sysconfig/selinux

#Add the kubernetes repository to yum so that we can use our package manager to install the latest version of kubernetes. 

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
exclude=kube*
EOF

#Install some of the tools (including CRI-O, kubeadm & kubelet) we’ll need on our servers.

yum install -y git curl wget bind-utils jq httpd-tools zip unzip nfs-utils go nmap telnet

if [[ $CRI != "docker" ]]
then

# Setup for CRIO

modprobe overlay
modprobe br_netfilter

cat > /etc/sysctl.d/99-kubernetes-cri.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOF

sysctl --system

# Install CRI-O prerequisites & tool

cat << EOF > /etc/yum.repos.d/crio.repo
[cri-o]
name=CRI-O Packages for CentOS 7 — $basearch
baseurl=http://mirror.centos.org/centos/7/paas/x86_64/openshift-origin311/
enabled=1
gpgcheck=0
EOF

# Install CRI-O
yum -y install cri-o cri-tools

# Modify CRI-O config in cgroup_manager = "systemd" to "cgroupfs"
sed -i 's/cgroup_manager = "systemd"/cgroup_manager = "cgroupfs"/g' /etc/crio/crio.conf

# Modify CRI-O config for disabling selinux
sed -i 's/selinux = true/selinux = false/g' /etc/crio/crio.conf

# upgrade crio version due to POD hostNetwork loopback (127.0.0.1) ip address
yum install -y https://cbs.centos.org/kojifiles/packages/cri-o/1.13.9/1.el7/x86_64/cri-o-1.13.9-1.el7.x86_64.rpm

# To escape error "failed: no ...directory"
mkdir -p /usr/share/containers/oci/hooks.d

# Remove CRI-o default CNI configuration
rm -rf /etc/cni/net.d/*

# Start CRI-O
systemctl start crio
systemctl enable crio

else

# Setup for docker

yum install -y docker

# Modify /etc/sysconfig/docker file as follows.

more /etc/sysconfig/docker | grep OPTIONS
sed -i "s/^OPTIONS=.*/OPTIONS='--selinux-enabled --signature-verification=false'/g" /etc/sysconfig/docker
more /etc/sysconfig/docker | grep OPTIONS

systemctl enable docker
systemctl start docker

cat <<EOF > /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system
systemctl restart docker

fi

# Installation with speceifc version
yum install -y kubelet-$K8S_VER kubeadm-$K8S_VER kubectl-$K8S_VER kubernetes-cni-0.6.0 --disableexcludes=kubernetes

# After installing crio and our kubernetes tools, we’ll need to enable the services so that they persist across reboots, and start the services so we can use them right away.

systemctl enable kubelet; systemctl start kubelet

# Setting up Kubernetes Node using Kubeadm

if [[ "$master" == "node" ]]; then
  echo ""
  echo "Waiting for Master ($KUBEMASTER) API response .."
  while [[ $(nc $KUBEMASTER 6443 &> /dev/null) != "True" ]]; do printf '.'; sleep 2; done
  kubeadm join --discovery-token-unsafe-skip-ca-verification --token=$TOKEN $KUBEMASTER:6443
  exit
fi

# Setting up Kubernetes Master using Kubeadm

if [[ "$master" == "master" && $CRI != "docker" ]]; then
  kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version $(kubeadm version -o short) --cri-socket "/var/run/crio/crio.sock" --ignore-preflight-errors=all 2>&1 | tee kubeadm-output.txt
else
  kubeadm init --token=$TOKEN --pod-network-cidr=10.244.0.0/16 --kubernetes-version $(kubeadm version -o short) --ignore-preflight-errors=all | grep -Ei "kubeadm join|discovery-token-ca-cert-hash" 2>&1 | tee kubeadm-output.txt
fi

sudo cp /etc/kubernetes/admin.conf $HOME/
sudo chown $(id -u):$(id -g) $HOME/admin.conf
export KUBECONFIG=$HOME/admin.conf
echo "export KUBECONFIG=$HOME/admin.conf" >> $HOME/.bash_profile
echo "alias oc=/usr/bin/kubectl" >> /root/.bash_profile

wget https://raw.githubusercontent.com/coreos/flannel/2140ac876ef134e0ed5af15c65e414cf26827915/Documentation/kube-flannel.yml
kubectl create -f kube-flannel.yml

sleep 20

kubectl get nodes

# Make Master scheduble
MASTER=`kubectl get nodes | grep master | awk '{print $1}'`
kubectl taint nodes $MASTER node-role.kubernetes.io/master-
kubectl get nodes -o json | jq .items[].spec.taints

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
kubectl krew install doctor
kubectl krew install ctx
kubectl krew install ns

echo 'export PATH="${PATH}:${HOME}/.krew/bin"' >> /root/.bash_profile

# Deploying Ingress
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/kube-ingress.yaml
sed -i "s/kube-master/$MASTER/g" kube-ingress.yaml
kubectl create ns kube-router
kubectl create -f kube-ingress.yaml

# Deploying dynamic NFS based persistant storage
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/nfs-rbac.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/nfs-deployment.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/kubenfs-storage-class.yaml
sed -i "s/10.128.0.9/$NFSRV/g" nfs-deployment.yaml
sed -i "s|/root/nfs/kubedata|$NFSMOUNT|g" nfs-deployment.yaml
kubectl create ns kubenfs
kubectl create -f nfs-rbac.yaml -f nfs-deployment.yaml -f kubenfs-storage-class.yaml -n kubenfs
SC=`kubectl get sc | grep kubenfs | awk '{print $1}'`	
kubectl patch sc $SC -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'	

# Setup Velero
wget https://github.com/vmware-tanzu/velero/releases/download/$velver/velero-$velver-linux-amd64.tar.gz
tar -xvzf velero-$velver-linux-amd64.tar.gz
mv -v velero-$velver-linux-amd64/velero /usr/local/bin/velero
echo "alias vel=/usr/local/bin/velero" >> /root/.bash_profile

cd 
cat <<EOF > credentials-velero
[default]
aws_access_key_id = admin
aws_secret_access_key = bappa2675
EOF

HOST_NAME=$(hostname)
HOST_IP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout private.key -out public.crt -subj "/CN=$HOST_IP/O=$HOST_NAME"

velero install \
    --provider aws \
    --bucket velero-cluster1 \
    --plugins velero/velero-plugin-for-aws:v1.1.0 \
    --use-restic \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=true \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://$MinIO:9000 \
    --snapshot-location-config region=minio
    
# Setup Helm Chart
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/setup-helm.sh
chmod +x setup-helm.sh
./setup-helm.sh

# Setup for monitring and logging
#exit
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/kubemon.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/kubelog.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/loki.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/loki-ds.json
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/pod-monitoring.json
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/kube-monitoring-overview.json
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/cluster-cost.json

kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
kubectl create ns logging
kubectl create secret generic loki -n logging --from-file=loki.yaml
kubectl create -f kubelog.yaml -n logging

## Upload Grafana dashboard & loki datasource
echo ""
echo "Waiting for Grafana POD ready to upload dashboard & loki datasource .."
while [[ $(kubectl get pods kubemon-grafana-0 -n monitoring -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @pod-monitoring.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @kube-monitoring-overview.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @cluster-cost.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP:30000/api/datasources -X POST -d @loki-ds.json -H 'Content-Type: application/json' 

# Setup Demo application
#exit
wget https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/mongo-employee.yaml
kubectl create ns demo-mongo
kubectl create -f mongo-employee.yaml -n demo-mongo

