## run this commands on eks client 

ziti edge create edge-router "router10" -t -o ./router10.jwt


ziti edge update identity "router10" \
    --role-attributes hello-hosts7


ziti edge create identity "hello-client13" \
    --role-attributes hello-clients7 \
    --jwt-output-file hello-client13.jwt

# ziti edge enroll hello-client13.jwt

# kubectl create secret generic "hello-client13" \
#     --from-file=hello-client13.json  

## use the above secrets for tunnels with trino    

## maybe these expires
ziti edge create config "hello-intercept-config7" intercept.v1 \
    '{"protocols":["tcp"],"addresses":["postgres.ziti.internal"], "portRanges":[{"low":5432, "high":5432}]}'

ziti edge create config "hello-host-config7" host.v1 \
    '{"protocol":"tcp", "address":"localhost","port":5432}'

ziti edge create service "hello-service7" \
    --configs hello-intercept-config7,hello-host-config7


ziti edge create edge-router-policy "default8" \
    --edge-router-roles '#all' --identity-roles '#all'

ziti edge create service-edge-router-policy "default8" \
    --edge-router-roles '#all' --service-roles '#all'

ziti edge create service-policy "hello-dial-policy8" Dial \
    --service-roles '@hello-service7' --identity-roles '#hello-clients7'

ziti edge create service-policy "hello-bind-policy8" Bind \
    --service-roles '@hello-service7' --identity-roles '#hello-hosts7'

ziti edge policy-advisor services hello-service7 -q 
