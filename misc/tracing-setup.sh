#!/bin/bash
# Install Jaeger distributed tracing in Kubernetes

#JAEGER_VER=v1.19.0
mkdir tracing
cd tracing

if [[ "$JAEGER_VER" == "" ]]; then
 DOWNLOAD=master
else
 DOWNLOAD=$JAEGER_VER
fi

kubectl create namespace tracing

wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/crds/jaegertracing.io_jaegers_crd.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/service_account.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/role.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/role_binding.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/operator.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/cluster_role.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/$DOWNLOAD/deploy/cluster_role_binding.yaml

sed -i '0,/fieldP/{//d;}' operator.yaml; sed -i '0,/fieldR/{//d;}' operator.yaml; sed -i '0,/valueFrom:/{s/valueFrom:/value: ""/}' operator.yaml
sed -i 's/Deployment/StatefulSet/g' operator.yaml; awk '1;/replicas/{ print "  serviceName: jaeger-operator"}' operator.yaml > tmp && mv -f tmp operator.yaml

sed -i "s/observability/tracing/g" cluster_role_binding.yaml

#kubectl create -f jaegertracing.io_jaegers_crd.yaml -f service_account.yaml -f role.yaml -f role_binding.yaml -f operator.yaml -n tracing
kubectl create -f . -n tracing

echo "Waiting for Jaeger POD ready .."
while [[ $(kubectl get pods jaeger-operator-0 -n tracing -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do printf '.'; sleep 2; done

kubectl apply -n tracing -f - <<EOF
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: simplest
EOF
