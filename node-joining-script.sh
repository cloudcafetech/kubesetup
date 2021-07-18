#!/usr/bin/env bash
# Controlpane & node joining script
# Note: If certificate-key expire, generate new using (kubeadm init phase upload-certs --upload-certs)

HA_PROXY_LB_DNS=172.31.28.212
HA_PROXY_LB_PORT=6443
MASTER1_IP=172.31.17.140
MASTER2_IP=172.31.21.8
MASTER3_IP=172.31.30.167
NODE1=172.31.22.99
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
CERTKEY=d60a03f140d7f245c06879ac6ab22aa3408b85a60edb94917d67add3dc2a5fa7

# Host Preparation
for hip in $MASTER1_IP $MASTER2_IP $MASTER3_IP $NODE1
do
echo "K8S Host Preparation on $hip"
#scp ec2-user@$hip -i key.pem ./k8s-host-setup.sh ec2-user@$hip:/home/ec2-user/k8s-host-setup.sh
ssh ec2-user@$hip -o 'StrictHostKeyChecking no' -i key.pem "wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/k8s-host-setup.sh"
ssh ec2-user@$hip -o 'StrictHostKeyChecking no' -i key.pem "chmod +x /home/ec2-user/k8s-host-setup.sh"
ssh ec2-user@$hip -o 'StrictHostKeyChecking no' -i key.pem "/home/ec2-user/k8s-host-setup.sh"
done

# Setup for Master 1
echo "Initialize Masters #1"
joinMaster1="sudo kubeadm init --token=$TOKEN --control-plane-endpoint $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --upload-certs --certificate-key=$CERTKEY --pod-network-cidr=192.168.0.0/16 --ignore-preflight-errors=all | tee kubeadm-output.txt"
ssh ec2-user@$MASTER1_IP -o 'StrictHostKeyChecking no' -i key.pem $joinMaster1
ssh ec2-user@$MASTER1_IP -o 'StrictHostKeyChecking no' -i key.pem "sudo cp /etc/kubernetes/admin.conf /home/ec2-user/config"
ssh ec2-user@$MASTER1_IP -o 'StrictHostKeyChecking no' -i key.pem "sudo chown ec2-user:ec2-user /home/ec2-user/config"
mkdir -p $HOME/.kube
scp -o 'StrictHostKeyChecking no' -i key.pem ec2-user@$MASTER1_IP:/home/ec2-user/config $HOME/.kube/
sudo chown $(id -u):$(id -g) $HOME/.kube/config

joinMaster="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --control-plane --certificate-key=$CERTKEY --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
joinNode="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
# Setup for Master 2
echo "Joining Masters #2"
ssh ec2-user@$MASTER2_IP -o 'StrictHostKeyChecking no' -i key.pem $joinMaster

# Setup for Master 3
echo "Joining Masters #3"
ssh ec2-user@$MASTER3_IP -o 'StrictHostKeyChecking no' -i key.pem $joinMaster

# Node
for nip in $NODE1
do
echo "Joining Nodes"
ssh ec2-user@$nip -o 'StrictHostKeyChecking no' -i key.pem $joinNode
done
