## Available Prometheus Metrics

| Metric       | Description                                                                                            |
| ------------ | ------------------------------------------------------------------------------------------------------ |
| node_cpu_hourly_cost | Hourly cost per vCPU on this node  |
| node_gpu_hourly_cost | Hourly cost per GPU on this node  |
| node_ram_hourly_cost   | Hourly cost per Gb of memory on this node                       |
| node_total_hourly_cost   | Total node cost per hour                       |
| kubecost_load_balancer_cost   | Hourly cost of a load balancer                 |
| kubecost_cluster_management_cost | Hourly management fee per cluster                 |
| container_cpu_allocation   | Average number of CPUs requested over last 1m                      |
| container_memory_allocation_bytes   | Average bytes of RAM requested over last 1m                 |

## Kubernetes Cost Example Queries

Once Kubecost’s cost model is running in your cluster and you have added it in your Prometheus scrape configuration, you can hit Prometheus with useful queries like these:

#### Monthly cost of all nodes

```
sum(node_total_hourly_cost) * 730
```

#### Hourly cost of all load balancers broken down by namespace

```
sum(kubecost_load_balancer_cost) by (namespace)
```

#### Monthly rate of each namespace’s CPU request

```
sum(container_cpu_allocation * on (node) group_left node_cpu_hourly_cost) by (namespace) * 730
```

#### Historical memory request spend for all `fluentd` pods in the `kube-system` namespace

```
avg_over_time(container_memory_allocation_bytes{namespace="kube-system",pod=~"fluentd.*"}[1d])
  * on (pod,node) group_left
avg(count_over_time(container_memory_allocation_bytes{namespace="kube-system"}[1d:1m])/60) by (pod,node)
  * on (node) group_left
avg(avg_over_time(node_ram_hourly_cost[1d] )) by (node)
```


## Setting Cost Alerts

Custom cost alerts can be implemented with a set of Prometheus queries and can be used for alerting with AlertManager or Grafana alerts. Below are example alerting rules.

#### Determine in real-time if the monthly cost of all nodes is > $1000

```
sum(node_total_hourly_cost) * 730 > 1000
```
