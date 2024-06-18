## install tunnel as nodeagent 

kubectl create secret generic trino-client1001 --from-file=persisted-identity=trino-client1001.json
helm install ziti-edge-tunnel openziti/ziti-edge-tunnel --set secret.existingSecretName=trino-client1001

## modify the coredns configmap to use

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
postgres.ziti.internal:53 {
    forward . 100.64.0.2
} 
```
