# Setup Kubernetes Platform
Vanila Kubernetes Platform with Monitoring, Logging & Backup

https://www.katacoda.com/courses/kubernetes/getting-started-with-kubeadm

## Prepare ALL Servers for Kubernetes (K8s)
OS ```CentOS 7``` to be ready before hand to start kubernetes deployment using kubeadm

### Setup Kubernetes

On Master host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> bash -s master```

On Node host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> bash -s node```
