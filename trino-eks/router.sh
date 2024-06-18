# this in eks cluster 

ziti edge create edge-router "router5" -t -o ./router5.jwt

helm upgrade --install "private-router" openziti/ziti-router \
--namespace ziti \
--set-file enrollmentJwt=./router5.jwt \
--set edge.advertisedHost=private-router.ziti.svc.cluster.local \
--set linkListeners.transport.service.enabled=false \
--set ctrl.endpoint="ec2-13-60-60-200.eu-north-1.compute.amazonaws.com:6262"


