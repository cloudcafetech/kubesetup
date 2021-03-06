#!/bin/bash
# Setup Velero backup script for Kubernetes

# Setup Velero backup
#MinIO=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
MinIO=10.128.0.9
velver=v1.4.2

mkdir backup
cd backup

wget https://github.com/vmware-tanzu/velero/releases/download/$velver/velero-$velver-linux-amd64.tar.gz
tar -xvzf velero-$velver-linux-amd64.tar.gz
mv -v velero-$velver-linux-amd64/velero /usr/local/bin/velero
echo "alias vel=/usr/local/bin/velero" >> /root/.bash_profile

cat <<EOF > credentials-velero
[default]
aws_access_key_id = admin
aws_secret_access_key = admin2675
EOF

velero install \
    --provider aws \
    --bucket backup \
    --plugins velero/velero-plugin-for-aws:v1.1.0 \
    --use-restic \
    --secret-file ./credentials-velero \
    --use-volume-snapshots=true \
    --backup-location-config region=minio,s3ForcePathStyle="true",s3Url=http://$MinIO:9000 \
    --snapshot-location-config region=minio
    
#kubectl patch deploy velero -n velero --type merge -p '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/os": "linux"}}}}}'
#kubectl patch ds restic -n velero --type merge -p '{"spec": {"template": {"spec": {"nodeSelector": {"beta.kubernetes.io/os": "linux"}}}}}'    
    
wget https://raw.githubusercontent.com/cloudcafetech/velero-backup-restore/master/velero-volume-controller.yaml    
kubectl create -f velero-volume-controller.yaml    

wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/backup/backup.sh
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/backup/restore.sh
chmod +x ./backup.sh
chmod +x ./restore.sh
