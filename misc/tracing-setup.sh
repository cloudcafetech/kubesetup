#!/bin/bash
# Install tracing in Kubernetes

kubectl create namespace tracing

wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/crds/jaegertracing.io_jaegers_crd.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/service_account.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/role_binding.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/operator.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role.yaml
wget https://raw.githubusercontent.com/jaegertracing/jaeger-operator/master/deploy/cluster_role_binding.yaml

sed -i "s/observability/tracing/g" cluster_role_binding.yaml

kubectl create -f jaegertracing.io_jaegers_crd.yaml -f service_account.yaml -f role.yaml -f role_binding.yaml -f operator.yaml -n tracing
