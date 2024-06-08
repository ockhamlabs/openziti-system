## install ziti cli 

curl -sS https://get.openziti.io/install.bash \
| sudo bash -s openziti

k3d cluster create ziti-local \
--port 1280:1280@loadbalancer \
--port 6262:6262@loadbalancer \
--port 3022:3022@loadbalancer \
--port 10080:10080@loadbalancer

NODE_IP=ec2-13-60-60-200.eu-north-1.compute.amazonaws.com

helm repo add "openziti" https://openziti.io/helm-charts
helm repo update "openziti"

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/latest/download/cert-manager.crds.yaml
kubectl apply -f https://raw.githubusercontent.com/cert-manager/trust-manager/v0.9.0/deploy/crds/trust.cert-manager.io_bundles.yaml

helm upgrade --install "ziti-controller" openziti/ziti-controller \
--namespace "ziti" --create-namespace \
--set clientApi.advertisedHost="ec2-13-60-60-200.eu-north-1.compute.amazonaws.com" \
--set clientApi.advertisedPort=1280 \
--set clientApi.service.type=LoadBalancer \
--set ctrlPlane.advertisedHost="ec2-13-60-60-200.eu-north-1.compute.amazonaws.com" \
--set ctrlPlane.advertisedPort=6262 \
--set ctrlPlane.service.type=LoadBalancer \
--set trust-manager.app.trust.namespace=ziti \
--set trust-manager.enabled=true \
--set cert-manager.enabled=true


export pass=$(kubectl get secrets "ziti-controller-admin-secret" \
--namespace "ziti" \
--output go-template='{{index .data "admin-password" | base64decode }}') 

ziti edge login ec2-13-60-60-200.eu-north-1.compute.amazonaws.com:1280 \
--yes --username "admin" \
--password $pass
