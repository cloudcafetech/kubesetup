#!/usr/bin/env bash
# Controlpane & node joining script
# Note: If certificate-key expire, generate new using (kubeadm init phase upload-certs --upload-certs)

HA_PROXY_LB_DNS=172.31.28.205
HA_PROXY_LB_PORT=6443
MASTER1_IP=172.31.26.135
MASTER2_IP=172.31.21.124
MASTER3_IP=172.31.31.51
NODE1=172.31.18.134
DATE=$(date +"%d%m%y")
TOKEN=$DATE.1a7dd4cc8d1f4cc5
CERTKEY=d60a03f140d7f245c06879ac6ab22aa3408b85a60edb94917d67add3dc2a5fa7

joinMaster="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --control-plane --certificate-key=$CERTKEY --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"
joinNode="sudo kubeadm join $HA_PROXY_LB_DNS:$HA_PROXY_LB_PORT --token=$TOKEN --discovery-token-ca-cert-hash sha256:$tokenSHA --ignore-preflight-errors=all"

# Setup for Master 2
echo "Initialize Masters #2"
ssh ec2-user@$MASTER2_IP -i key.pem $joinMaster

# Setup for Master 3
echo "Initialize Masters #3"
ssh ec2-user@$MASTER3_IP -i key.pem $joinMaster

# Node
for nip in NODE1
do
echo "Initialize Nodes"
ssh ec2-user@$nip -i key.pem $joinNode
done
