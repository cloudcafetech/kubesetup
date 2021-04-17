## Kubenetes Multi Cluster Monitoring with Cortex


### Setup Cortex


### Setup Kubernetes Cluster with KIND


### Setup Prometheus Monitoring 

Edit ```kubemon.yaml``` file and change cluster name in ```external_labels``` section and change ip address of cortex server in ```remote_write``` section.

Then run below command ....

```
kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
```
