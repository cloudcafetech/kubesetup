#!/usr/bin/env bash
# Controlpane & node joining script
# Note: If certificate-key expire, generate new using (kubeadm init phase upload-certs --upload-certs)

HA_PROXY_LB_DNS=172.31.28.212
HA_PROXY_LB_PORT=6443
MASTER1_IP=172.31.17.140
MASTER2_IP=172.31.21.8
MASTER3_IP=172.31.30.167
NODE1=172.31.22.99

USER=ec2-user
PEMKEY=key.pem

DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
CERTKEY=d60a03f140d7f245c06879ac6ab22aa3408b85a60edb94917d67add3dc2a5fa7

# Checking Load Balancer Response
LBTEST=`nc -w 2 -v $HA_PROXY_LB_DNS $HA_PROXY_LB_PORT </dev/null; echo $?`
if [[ "$LBTEST" == "0" ]]; then
  echo "OK - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) responding."
else 
  echo "NOT Good - Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT) NOT responding."
  echo "Please Check Load Balancer ($HA_PROXY_LB_DNS) on port ($HA_PROXY_LB_PORT), before proceeding."
  exit
fi

# Checking All Deployment Hosts Response
for rip in $MASTER1_IP $MASTER2_IP $MASTER3_IP $NODE1
do
HTEST=`nc -w 2 -v $rip 22 </dev/null; echo $?`
if [[ "$HTEST" == "1" ]]; then
  echo "NOT Good - Host ($rip) on ssh port (22) NOT responding."
  echo "Please Check Host ($rip) on ssh port (22), before proceeding."
  exit  
else 
  echo "OK - Host ($rip) on ssh port (22) responding."
fi
done

# Host Preparation
for hip in $MASTER1_IP $MASTER2_IP $MASTER3_IP $NODE1
do
echo "K8S Host Preparation on $hip"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/k8s-host-setup.sh"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "chmod +x /home/$USER/k8s-host-setup.sh"
ssh $USER@$hip -o 'StrictHostKeyChecking no' -i $PEMKEY "/home/$USER/k8s-host-setup.sh"
done

# Setup for Master 1
echo "Initialize Masters #1"
# For Calico Networking
joinMaster1="sudo kubeadm init --token=$TOKEN --control-plane-endpoint $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --pod-network-cidr=192.168.0.0/16 --upload-certs --certificate-key=$CERTKEY --ignore-preflight-errors=all | tee kubeadm-output.txt"
# For Flannel & WeaveNet Networking
#joinMaster1="sudo kubeadm init --token=$TOKEN --control-plane-endpoint $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --upload-certs --certificate-key=$CERTKEY --ignore-preflight-errors=all | tee kubeadm-output.txt"
ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY $joinMaster1
ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo cp /etc/kubernetes/admin.conf /home/$USER/config"
ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo chown $USER:$USER /home/$USER/config"
mkdir -p $HOME/.kube
scp -o 'StrictHostKeyChecking no' -i $PEMKEY $USER@$MASTER1_IP:/home/$USER/config $HOME/.kube/
sudo chown $(id -u):$(id -g) $HOME/.kube/config

tokenSHA=$(ssh $USER@$MASTER1_IP -o 'StrictHostKeyChecking no' -i $PEMKEY "sudo openssl x509 -in /etc/kubernetes/pki/ca.crt -noout -pubkey | sudo openssl rsa -pubin -outform DER 2>/dev/null | sha256sum | cut -d' ' -f1")
joinMaster="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --control-plane --certificate-key=$CERTKEY --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
joinNode="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
# Setup for Master 2
echo "Joining Masters #2"
ssh $USER@$MASTER2_IP -o 'StrictHostKeyChecking no' -i $PEMKEY $joinMaster

# Setup for Master 3
echo "Joining Masters #3"
ssh $USER@$MASTER3_IP -o 'StrictHostKeyChecking no' -i $PEMKEY $joinMaster

# Node
for nip in $NODE1
do
echo "Joining Nodes"
ssh $USER@$nip -o 'StrictHostKeyChecking no' -i $PEMKEY $joinNode
done

# Setup K8S Networking using Calico
echo "export KUBECONFIG=$HOME/.kube/config" >> $HOME/.bash_profile
export KUBECONFIG=$HOME/.kube/config
kubectl get node
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/calico.yaml
kubectl apply -f calico.yaml
#kubectl apply -f https://docs.projectcalico.org/v3.8/manifests/calico.yaml
#kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
#kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml
