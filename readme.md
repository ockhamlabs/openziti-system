## Setup Order

### follow steps from relevant folders

### controller in knorket

### Postgres

### Trino cluster

### then access trino from trino 



![Alt text](./trino_setup.png)

For deploying tunnels as agent 

refer https://openziti.io/docs/reference/tunnelers/kubernetes/kubernetes-daemonset

```sh
helm install coredns-custom k8s-nodelocaldns-helm/node-local-dns
```

```sh
helm install ziti-edge-tunnel openziti/ziti-edge-tunnel --set-file zitiIdentity=vault1-client.json
```

but modify the coredns related configmaps to 

```yaml
Corefile:
----
.:53 {
    errors
    health {
        lameduck 5s
      }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
      pods insecure
      fallthrough in-addr.arpa ip6.arpa
    }
    prometheus :9153
    forward . /etc/resolv.conf
    cache 30
    loop
    reload
    loadbalance
}
vault1.ziti.internal:53 {
    forward . 100.64.0.2
} 
```
