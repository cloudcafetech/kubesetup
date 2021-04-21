## Kubenetes Multi Cluster Monitoring with Thanos

### Setup Kubernetes Cluster with KIND

Edit KIND yaml ```kind-single-node.yaml``` file and change ```apiServerAddress``` with server (VM) IP Address.

Then run below command ....

```kind create cluster --config kind-single-node.yaml```

### Setup Ingress Controller

```
kubectl apply -f https://raw.githubusercontent.com/cloudcafetech/kafka-on-container/master/kube-kind-ingress.yaml
kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
kubectl delete ValidatingWebhookConfiguration ingress-nginx-admission
sleep 15
kubectl delete job.batch/ingress-nginx-admission-patch -n kube-router
```

### Setup Prometheus Monitoring on Edge Cluster

Edit ```kubemon.yaml``` file and change cluster name in ```external_labels``` section and change ```IP Address``` of cortex server in ```remote_write``` section.

Then run below command ....

```
kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
```

### Setup Prometheus Monitoring on Edge Cluster



### CTOP (Container TOP)
Top-like Interface for Monitoring Docker Containers

```
export VER="0.7.3"
wget https://github.com/bcicen/ctop/releases/download/v${VER}/ctop-${VER}-linux-amd64 -O ctop
chmod +x ctop
sudo mv ctop /usr/local/bin/ctop
```
