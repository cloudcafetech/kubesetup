## Istio Setup in Kubernetes

- Install Istio tool

```
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.3.5 sh -

curl -L https://git.io/getLatestIstio | sh -  # For latest

istioctl version
```

- Create 'istio-system' namespace

```kubectl create ns istio-system```

- Switch to istio installation dir and install istio into the cluster.

```
istioctl install \
  --set values.tracing.enabled=true \
  --set values.kiali.enabled=true \
  --set values.prometheus.enabled=false \
  --set values.grafana.enabled=false \
  --namespace istio-system 

# Wait until pods are in Running or Completed state
kubectl get pods -n istio-system
```

- Label the **default** namespace for auto sidecar injection

```
kubectl label namespace default istio-injection=enabled
kubectl get namespace -L istio-injection
```

- Set up the application

```kubectl apply -f ../istio/tracing/testapp```

#### Reference

https://rinormaloku.com/istio-an-introduction/

