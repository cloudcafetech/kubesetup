# Kubernetes Platform
Vanila Kubernetes Platform with Monitoring, Logging & Backup

https://www.katacoda.com/courses/kubernetes/getting-started-with-kubeadm

## Prepare ALL Servers for Kubernetes (K8s)
OS ```CentOS 7``` to be ready before hand to start kubernetes deployment using kubeadm

### Setup Kubernetes

On Master host run following command
```
curl -LO https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/host-setup.sh; chmod +x ./host-setup.sh
./host-setup.sh master
```

On Node host run following command
```
curl -LO https://raw.githubusercontent.com/cloudcafetech/kube-katakoda/master/host-setup.sh; chmod +x ./host-setup.sh
./host-setup.sh node
```
