## To install a router 

ziti edge create edge-router "router10" -t -o ./router10.jwt

pip install ziti-router 
ziti-router --jwt router10.jwt --tunnelListener 'host' --controller=ec2-13-60-60-200.eu-north-1.compute.amazonaws.com --controllerFabricPort=6262 --force