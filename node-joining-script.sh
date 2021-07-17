#!/usr/bin/env bash
# Controlpane & node joining script
# Note: If certificate-key expire, generate new using (kubeadm init phase upload-certs --upload-certs)

HA_PROXY_LB_DNS=172.31.28.205
HA_PROXY_LB_PORT=6443
MASTER1_IP=172.31.26.135
MASTER2_IP=172.31.21.124
MASTER3_IP=172.31.31.51
NODE1=172.31.22.99
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
CERTKEY=d60a03f140d7f245c06879ac6ab22aa3408b85a60edb94917d67add3dc2a5fa7

joinMaster1="sudo kubeadm init --token=$TOKEN --control-plane-endpoint "$HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT" --upload-certs --certificate-key=$CERTKEY --pod-network-cidr=192.168.0.0/16 --kubernetes-version $(kubeadm version -o short) --ignore-preflight-errors=all | tee kubeadm-output.txt"
joinMaster="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --control-plane --certificate-key=$CERTKEY --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
joinNode="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"


# Host Preparation
for hip in $MASTER1_IP $MASTER2_IP $MASTER3_IP $NODE1
do
echo "K8S Host Preparation on $hip"
scp ec2-user@$hip -i key.pem k8s-host-setup.sh ec2-user@$nip:/home/ec2-user/
ssh ec2-user@$hip -i key.pem /home/ec2-user/k8s-host-setup.sh
done

# Setup for Master 1
echo "Initialize Masters #1"
ssh ec2-user@$MASTER1_IP -i key.pem $joinMaster1

# Setup for Master 2
echo "Joining Masters #2"
ssh ec2-user@$MASTER2_IP -i key.pem $joinMaster

# Setup for Master 3
echo "Joining Masters #3"
ssh ec2-user@$MASTER3_IP -i key.pem $joinMaster

# Node
for nip in $NODE1
do
echo "Joining Nodes"
ssh ec2-user@$nip -i key.pem $joinNode
done
