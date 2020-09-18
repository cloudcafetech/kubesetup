#!/bin/bash
# Install monitoring and logging in Kubernetes

wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/logging/kubelog.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/logging/loki.yaml
#wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/logging/loki-ds.json
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/monitoring/kubemon.yaml
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/monitoring/pod-monitoring.json
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/monitoring/kube-monitoring-overview.json
wget https://raw.githubusercontent.com/cloudcafetech/kubesetup/master/monitoring/cluster-cost.json

kubectl create ns monitoring
kubectl create -f kubemon.yaml -n monitoring
kubectl create ns logging
kubectl create secret generic loki -n logging --from-file=loki.yaml
kubectl create -f kubelog.yaml -n logging

## Upload Grafana dashboard & loki datasource
echo ""
echo "Waiting for Grafana POD ready to upload dashboard .."
while [[ $(kubectl get pods kubemon-grafana-0 -n monitoring -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

HIP=`ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1`
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @pod-monitoring.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @kube-monitoring-overview.json -H 'Content-Type: application/json'
curl -vvv http://admin:admin2675@$HIP:30000/api/dashboards/db -X POST -d @cluster-cost.json -H 'Content-Type: application/json'
#curl -vvv http://admin:admin2675@$HIP:30000/api/datasources -X POST -d @loki-ds.json -H 'Content-Type: application/json'
