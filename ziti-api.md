# To Enable OpenZiti Network

## Prerequisites

- **Controller Running:** Ensure the OpenZiti controller is running, typically managed by DevOps.
- **Session Token:** Obtain a session token by logging into the controller to execute any API calls. 

Prefer [API Reference](https://openziti.io/docs/reference/developer/api/edge-management-reference). if want to get additional options of configuring api

## Terminologies

- **Router:** Deployed in a network (VPC) to access its resources, making everything in that network accessible as localhost for the router.
  
- **Service:** Specifies the URL (e.g., localhost:5432) within the network that the router exposes for access.

- **Identities:** Used to access specific services under a router via jwts into the tunnel , where as it can be router identity types also but that is like for giving name of router and creating jwt to be used in the router


- **Service Policies:** Define rules governing which identities can route traffic to services or which routers can send traffic to services.

```sh
export ZITI_URL="https://ec2-13-60-60-200.eu-north-1.compute.amazonaws.com:1280"
export USERNAME="admin"
export password=$(kubectl get secrets "ziti-controller-admin-secret" \
--namespace "ziti" \
--output go-template='{{index .data "admin-password" | base64decode }}')

response=$(curl -s -X POST "$ZITI_URL/edge/management/v1/authenticate?method=password" \
-H "Content-Type: application/json" \
-d "{\"username\": \"$USERNAME\", \"password\": \"$password\"}" --insecure)

# Extract the session token from the response
session=$(echo $response | jq -r '.data.token')
```


### Let's say a client stepped and clicked create cluster and choosed private network (private subnet) since knorket has no access to private network it will have to install routers in the client cluster during setup and then access it , the way it works is 

### Routers are installed during startup of the client's clusters 
### First get the jwt by creating new router identity 

#### STEP 1:

```sh
routerName="router-test6"
roleAttributes=("router-group")
isTunnelerEnabled=true  # Set this to true

# Create the edge router identity
routerResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/edge-routers" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "'"$routerName"'",
    "roleAttributes": ["'"${roleAttributes[@]}"'"],
    "isTunnelerEnabled": '$isTunnelerEnabled'
  }' --insecure)

# Output the created edge router details
echo "Created Edge Router:"
echo "$routerResponse" | jq

edgeRouterId=$(echo $edgeRouterResponse | jq -r '.data.id')

echo "routerID is $edgeRouterId"

edgeRouterResponse=$(curl -s -X GET "$edgeRouterEndpoint" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  --insecure)

enrollmentJwt=$(echo $edgeRouterResponse | jq -r '.data.enrollmentJwt')

## to update the router identity

routerId=".OAbqESuQ"  # you will get this from routerResponse
newRoleAttributes=("new-router-group")  # New role attributes to assign

# Make the API request to update the edge router identity
updateResponse=$(curl -s -X PATCH "$ZITI_URL/edge/management/v1/identities/$routerId" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "roleAttributes": ["'"${newRoleAttributes[@]}"'"]
  }' --insecure)


```

### used the above jwt for running the router and check if router is online

### To check if router is online 

```sh
edgeRouterEndpoint="$ZITI_URL/edge/management/v1/edge-routers/$edgeRouterId"

edgeRouterResponse=$(curl -s -X GET "$edgeRouterEndpoint" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  --insecure)

echo "$edgeRouterResponse" | jq  
```

### Then install the actual router via helm if using k8s 

```sh
helm upgrade --install "router-name" openziti/ziti-router \
--namespace ziti \
--set-file enrollmentJwt=./router1.jwt \
--set edge.advertisedHost=private-router123-edge.ziti.svc.cluster.local \
--set linkListeners.transport.service.enabled=false \
--set ctrl.endpoint="https://ec2-13-60-60-200.eu-north-1.compute.amazonaws.com:6262"
```

### now routers are installed which means we can access client's private cluster but we need identity

### STEP 2:

### When knorket wants to talk to those services behind routers it creates client Identity , get the jwt and adds it to its tunnel 

```sh
IdentityName=client-7
ClientAttribute=client-group-6

IdentityResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/identities" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "'"$IdentityName"'",
    "isAdmin": false,
    "type": "User",
    "roleAttributes": ["'"$ClientAttribute"'"],
    "enrollment": {
      "type": "OTT"  
    }
  }' --insecure)
  

# Extract Identity ID
ClientId=$(echo $IdentityResponse | jq -r .data.id)
# jR5BRdjpG

enrollmentsEndpoint="$ZITI_URL/edge/management/v1/enrollments"

# Example enrollment data (adjust as per your requirements)
enrollmentData='{
  "expiresAt": "2034-08-24T14:15:22Z",
  "identityId": "'"$ClientId"'",
  "method": "ott"
}'

# Create enrollment
enrollmentResponse=$(curl -s -X POST "$enrollmentsEndpoint" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d "$enrollmentData" \
  --insecure)

# Extract the enrollment ID from the response
enrollmentId=$(echo $enrollmentResponse | jq -r '.data.id')

# Retrieve enrollment details to get the JWT token
enrollmentDetailsEndpoint="$enrollmentsEndpoint/$enrollmentId"
enrollmentDetailsResponse=$(curl -s -X GET "$enrollmentDetailsEndpoint" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  --insecure)

# Extract the JWT token from enrollmentDetailsResponse using jq
jwtToken=$(echo $enrollmentDetailsResponse | jq -r '.data.jwt')

# Output the JWT token
echo "JWT Token: $jwtToken"

then use in tunnel this jwttoken 

## make sure to install tunnel if not installed https://openziti.io/docs/reference/tunnelers/linux/debian-package

## then add the identity

sudo ziti-edge-tunnel add --jwt "$(< ./$IdentityName.jwt)" --identity "$IdentityName"

sudo chown -cR :ziti        /opt/openziti/etc/identities
sudo chmod -cR ug=rwX,o-rwx /opt/openziti/etc/identities

# package users can restart with systemd
sudo systemctl restart ziti-edge-tunnel.service

```
### Now to create service behind that router and add rules that router can access that service 

### STEP 3:

### To find the host id you can use this request , but since I already did and stored ID you ca avoid

```sh
curl -s -X GET "$ZITI_URL/edge/management/v1/config-types" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  --insecure | jq '.data[] | select(.name == "host.v1")'
# Create Intercept Config for a goal to prepare ziti domain behind your service in this case it will be post.ziti.internal:5432

interceptConfigResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/configs" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "service-6-intercept",
    "configTypeId": "g7cIWbcGg", ## use this as default for intercept config
    "data": {
      "protocols": ["tcp"],
      "addresses": ["post.ziti.internal"],
      "portRanges": [{"low": 5432, "high": 5432}]
    }
  }' --insecure)

interceptConfigId=$(echo $interceptConfigResponse | jq -r '.data.id')

echo "Intercept Config is $interceptConfigId"

## Intercept Config is R15ZcOGsxKWvVgiy0EwCL
```


### STEP 4:
### Create Host Config for a goal to expose the service where the router is installed in this case its  localhost:5432
```sh
hostConfigResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/configs" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "service-6-host",
    "configTypeId": "NH5p4FpGR",
    "data": {
      "protocol": "tcp",
      "address": "localhost",
      "port": 5432
    }
  }' --insecure)

hostConfigId=$(echo $hostConfigResponse | jq -r '.data.id')

echo "host Config is $hostConfigId"

# host Config is 2Ad5hcUg1Nfd8G1ESKW8tM

```

### STEP 5:
### Create Service the actual service resource  to expose the private service

from above we got R15ZcOGsxKWvVgiy0EwCL from intercept and 2Ad5hcUg1Nfd8G1ESKW8tM on # host so thats what will use it here 

```sh
serviceResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/services" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "service-6",
    "configs": ["R15ZcOGsxKWvVgiy0EwCL", "2Ad5hcUg1Nfd8G1ESKW8tM"],
    "encryptionRequired": true
  }' --insecure)

serviceId=$(echo $serviceResponse | jq -r '.data.id')
# 1Oh311d9m0gm2vUET6cjya
```

### STEP 6:
### Create Dial Policy --> which means the clients should be able to connect this service in our case its client-group-6 attribute group which we want to allow

```sh
createDialPolicyResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/service-policies" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "service-6-dial-policy",
    "type": "Dial",
    "semantic": "AllOf",
    "serviceRoles": ["#all"],
    "identityRoles": ["#client-group-6"]
  }' --insecure)

echo "$createDialPolicyResponse" | jq 

# 39ZQKEsWgoDKVzCDHZP66E
```

### STEP 7:
### Create Bind Policy so routers above this service can route the traffic
 the tag value which you see 1Oh311d9m0gm2vUET6cjya is fetched from service created 

```sh
createBindPolicyResponse=$(curl -s -X POST "$ZITI_URL/edge/management/v1/service-policies" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" \
  -d '{
    "name": "service-6-bind-policy",
    "type": "Bind",
    "semantic": "AllOf",
    "serviceRoles": ["@1Oh311d9m0gm2vUET6cjya"],
    "identityRoles": ["#router-group"]
  }' --insecure)

echo "$createBindPolicyResponse" | jq -r .data.id
```

### STEP 8:
### Checking terminators associated with the service ID gives a confirmation that the service can send the request to the private network 

```sh
terminatorsResponse=$(curl -s -X GET "$ZITI_URL/edge/management/v1/services/1Oh311d9m0gm2vUET6cjya/terminators" \
  -H "Content-Type: application/json" \
  -H "Zt-Session: $session" --insecure)

### Output the terminators (make sure not empty for that particular service)
echo "$terminatorsResponse" | jq .data
```

## By having the above scenario now you can work flexibility with those terminologies 

### Let's say user want to bring their external private database which has url abcd:123

### We to access that network would deploy router in their network , we cant reach their network so we will create router and give jwt , they will use jwt and run the router  and also take the url they want to expose in the ui so since we are creating service we would have to input which url to exactly expose 

```sh
ziti-router --jwt router.jwt 
```

### Now we have router in their network which means we can access their network 

### We would have associated unique attribute for this router , and then we create services , policies , identities referencing that attribute and can access their service
