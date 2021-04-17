## Kubenetes Multi Cluster Monitoring with Cortex


### Setup Cortex


### Setup Kubernetes Cluster with KIND

Edit KIND yaml ```kind-single-node.yaml``` file and change ```apiServerAddress``` with server (VM) IP Address.

Then run below command ....

```kind create cluster --config kind-single-node.yaml```

### Setup Prometheus Monitoring 

Edit ```kubemon.yaml``` file and change cluster name in ```external_labels``` section and change ```IP Address``` of cortex server in ```remote_write``` section.

Then run below command ....

```
kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
```
