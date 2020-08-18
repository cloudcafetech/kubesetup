#!/bin/bash
# Setup Velero backup script for Kubernetes

# Setup Velero backup
MinIO=10.128.0.9
velver=v1.4.2

wget https://github.com/vmware-tanzu/velero/releases/download/$velver/velero-$velver-linux-amd64.tar.gz
tar -xvzf velero-$velver-linux-amd64.tar.gz
mv -v velero-$velver-linux-amd64/velero /usr/local/bin/velero
echo "alias vel=/usr/local/bin/velero" >> /root/.bash_profile

cd 
cat <<EOF > credentials-velero
[default]
aws_access_key_id = admin
aws_secret_access_key = admin2675
EOF

cp /home/centos/rootCA.pem $HOME/

velero install \
    --provider aws \
    --bucket velero-cluster1 \
    --plugins velero/velero-plugin-for-aws:v1.1.0 \
    --use-restic \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=true \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=https://$MinIO,insecureSkipTLSVerify="true" \
    --cacert rootCA.pem \
    --snapshot-location-config region=minio
    
wget https://raw.githubusercontent.com/cloudcafetech/velero-backup-restore/master/velero-volume-controller.yaml    
kubectl create -f velero-volume-controller.yaml    

wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/backup/backup.sh
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/backup/restore.sh
chmod +x ./backup.sh
chmod +x ./restore.sh
