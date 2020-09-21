# Setup Kubernetes Platform
Vanila Kubernetes Platform with Monitoring, Logging & Backup

https://www.katacoda.com/courses/kubernetes/getting-started-with-kubeadm

## Prepare ALL Servers for Kubernetes (K8s)
OS ```CentOS 7``` to be ready before hand to start kubernetes deployment using kubeadm

### Setup Kubernetes with latest

On Master host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> bash -s master```

On Node host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> bash -s node```

### Setup Kubernetes with version

Find Kubernetes version 

curl -s https://packages.cloud.google.com/apt/dists/kubernetes-xenial/main/binary-amd64/Packages | grep Version | awk '{print $2}' | more

On Master host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> K8S_VER=1.18.2 bash -s master```

On Node host run following command

```curl -s https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/host-setup.sh | KUBEMASTER=<MASTER-IP> K8S_VER=1.18.2 bash -s node```
