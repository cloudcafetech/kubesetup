#!/bin/bash
# NFS based persistant storage setup script for Kubernetes

# Deploying dynamic NFS based persistant storage

NFSRV=10.128.0.9
NFSMOUNT=/root/nfs/nfsdata

mkdir nfsstorage
cd nfsstorage

wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/nfs-storage/nfs-rbac.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/nfs-storage/nfs-deployment.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/nfs-storage/kubenfs-storage-class.yaml

sed -i "s/10.128.0.9/$NFSRV/g" nfs-deployment.yaml
sed -i "s|/root/nfs/kubedata|$NFSMOUNT|g" nfs-deployment.yaml

kubectl create ns kubenfs
kubectl create -f nfs-rbac.yaml -f nfs-deployment.yaml -f kubenfs-storage-class.yaml -n kubenfs
SC=`kubectl get sc | grep kubenfs | awk '{print $1}'`	
kubectl patch sc $SC -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'	
