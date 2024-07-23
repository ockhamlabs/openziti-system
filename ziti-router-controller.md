## Steps taken to deploy controller or public router in k3d 

### First install k3d and open the ports for router to create service type of loadbalancer

```sh
k3d cluster create ziti-local \
--port 1280:1280@loadbalancer \
--port 6262:6262@loadbalancer \
--port 3022:3022@loadbalancer \
--port 10080:10080@loadbalancer

```

### Make note of NODE_IP of ec2 machine 

```sh
IP=$(docker inspect k3d-ziti-local-serverlb|jq -r '.[].NetworkSettings.Networks[].IPAddress')

NODE_IP=$(dig +short -x "$IP")
```

### To install controller 


#### Install the Cert Manager and Trust Manager Custom Resource Definitions

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.7.0/deploy/crds/trust.cert-manager.io_bundles.yaml
```

```sh
helm upgrade --install "ziti-controller" openziti/ziti-controller \
--namespace "ziti" --create-namespace \
--set clientApi.advertisedHost="${NODE_IP}" \
--set clientApi.advertisedPort=1280 \
--set clientApi.service.type=LoadBalancer \
--set ctrlPlane.advertisedHost="${NODE_IP}" \
--set ctrlPlane.advertisedPort=6262 \
--set ctrlPlane.service.type=LoadBalancer \
--set trust-manager.app.trust.namespace=ziti \
--set trust-manager.enabled=true \
--set cert-manager.enabled=true
```

### Install public router 



```sh
ziti edge create edge-router "router" -t -o ./router.jwt
```

#### Note: pass ctrl.endpoint is taken from advertised host and port of ctrlPlane controller in our case "${NODE_IP}:6262"

```sh
helm upgrade --install "ziti-router" openziti/ziti-router \
--namespace "ziti" \
--set-file enrollmentJwt=./router.jwt \
--set edge.advertisedHost="${NODE_IP}" \
--set edge.advertisedPort=3022 \
--set edge.service.type=LoadBalancer \
--set linkListeners.transport.advertisedHost="${NODE_IP}" \
--set linkListeners.transport.advertisedPort=10080 \
--set linkListeners.transport.service.type=LoadBalancer \
--set tunnel.mode=host \
--set ctrl.endpoint="${NODE_IP}:6262"
```



## Steps taken to deploy controller or public router in EKS Cluster

### For controller 

#### Install the Cert Manager and Trust Manager Custom Resource Definitions

```sh
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.7.0/deploy/crds/trust.cert-manager.io_bundles.yaml
```


```sh
vim controller-helm.yaml
```

```yaml
clientApi:
  advertisedHost: client.example.co
  advertisedPort: 443
  service:
    type: ClusterIP
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      kubernetes.io/ingress.allow-http: "false"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"

ctrlPlane:
  advertisedHost: ctrl.example.co
  advertisedPort: 443
  service:
    enabled: true
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      kubernetes.io/ingress.allow-http: "false"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"
  
cert-manager:
  enabled: true
  enableCertificateOwnerRef: true
  installCRDs: false

trust-manager:
  enabled: true
  app:
    trust:
      namespace: ziti
  crds:
    enabled: false

ingress-nginx:
  enabled: true
  controller:
    extraArgs:
      enable-ssl-passthrough: "true"
```      

#### We are using ingress and letting ssl passthrough so mtls can be handled by ziti controller 

#### We used example.co as domain as later after seeing loadbalancer url we can add CNAME entry to new subdomain and update helm chart



```sh
helm upgrade --install "ziti-controller" openziti/ziti-controller \
--namespace "ziti" --create-namespace \
  --values=controller-helm.yaml 
```

#### Once deployed note down the loadbalancer uri and create 2 subdomains 
#### one for client 
```sh
clientApi:
  advertisedHost:
  ```

  ### other for controller

```sh
  ctrlPlane:
  advertisedHost: example.co
 ```

 #### Once you create and add entry for subdomains modify the values here and update the helm chart 

### For router

```sh
vim router-helm.yaml
```

```yaml
linkListeners:
  transport:  # https://docs.openziti.io/docs/reference/configuration/router/#transport
    containerPort: 10080
    advertisedHost: link.example.co
    advertisedPort: 443
    service:
      enabled: true
      type: ClusterIP
      labels:
      annotations:
    ingress:
      enabled: true
      ingressClassName: nginx
      annotations:
        kubernetes.io/ingress.allow-http: "false"
        nginx.ingress.kubernetes.io/ssl-passthrough: "true"

# listen for edge clients
edge:
  enabled: true
  containerPort: 3022
  advertisedHost: edge.example.co
  advertisedPort: 443
  service:
    enabled: true
    # -- expose the service as a ClusterIP, NodePort, or LoadBalancer
    type: ClusterIP
    # -- service labels
    labels:
    # -- service annotations
    annotations:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      kubernetes.io/ingress.allow-http: "false"
      nginx.ingress.kubernetes.io/ssl-passthrough: "true"

tunnel:
  mode: host

```

#### We have same scenario here wrt ssl passthrough and domain . Create the subdomain add cname entry and re update the chart

```sh
ziti edge create edge-router "router1" -t -o ./router1.jwt
```

#### Note: pass ctrl.endpoint is taken from advertised host and port of ctrlPlane controller in our case ctrl.example.co:443

```sh
helm upgrade "ziti-router" openziti/ziti-router \
  --namespace "ziti" \
  --values=ziti-router-helm.yaml \
  --set-file enrollmentJwt=./router1.jwt \
  --set ctrl.endpoint="example.co:443"
```
