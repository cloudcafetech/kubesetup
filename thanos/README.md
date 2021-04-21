## Kubenetes Multi Cluster Monitoring with Thanos

### Setup Kubernetes Cluster with KIND

Edit KIND yaml ```kind-single-node.yaml``` file and change ```apiServerAddress``` with server (VM) IP Address.

Then run below command ....

```kind create cluster --config kind-single-node.yaml```

### Setup Ingress Controller

```
kubectl apply -f https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/thanos/kube-kind-ingress.yaml
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
kubectl delete ValidatingWebhookConfiguration ingress-nginx-admission
sleep 15
kubectl delete job.batch/ingress-nginx-admission-patch -n kube-router
```

### Setup Minio for S3 type long term storage and create two (thanos & thanos-ruler) buckets

```
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

MinIO=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
wget https://dl.min.io/client/mc/release/linux-amd64/mc; chmod +x mc; mv -v mc /usr/local/bin/mc
mc config host add minio http://$MinIO:9000 admin admin2675 --insecure
mc mb minio/thanos --insecure
mc mb minio/thanos-ruler --insecure
```

### Setup Prometheus Monitoring on Edge Cluster

Edit ```kubemon.yaml``` file and change cluster name in ```external_labels``` section and change ```IP Address``` of cortex server in ```remote_write``` section.

Then run below command ....

```
kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
```

### Setup Prometheus Monitoring on Central Observibility Cluster



### CTOP (Container TOP)
Top-like Interface for Monitoring Docker Containers

```
export VER="0.7.3"
wget https://github.com/bcicen/ctop/releases/download/v${VER}/ctop-${VER}-linux-amd64 -O ctop
chmod +x ctop
sudo mv ctop /usr/local/bin/ctop
```
