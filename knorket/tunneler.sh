ziti edge update identity "router5" \
    --role-attributes trino-hosts

ziti edge create identity "trino-client" \
    --role-attributes trino-clients \
    --jwt-output-file trino-client.jwt

ziti edge create config "trino-intercept-config" intercept.v1 \
    '{"protocols":["tcp"],"addresses":["trino.ziti.internal"], "portRanges":[{"low":8080, "high":8080}]}'

ziti edge create config "trino-host-config" host.v1 \
    '{"protocol":"tcp", "address":"trino-cluster-trino.default.svc","port":8080}'

ziti edge create service "trino-service" \
    --configs trino-intercept-config,trino-host-config


ziti edge create edge-router-policy "default" \
    --edge-router-roles '#all' --identity-roles '#all'

ziti edge create service-edge-router-policy "default" \
    --edge-router-roles '#all' --service-roles '#all'

ziti edge create service-policy "trino-dial-policy" Dial \
    --service-roles '@trino-service' --identity-roles '#trino-clients'

ziti edge create service-policy "trino-bind-policy" Bind \
    --service-roles '@trino-service' --identity-roles '#trino-hosts'

ziti edge policy-advisor services trino-service -q 


### then use trino-client id as 

curl -sSLf https://get.openziti.io/tun/scripts/install-ubuntu.bash | bash

sudo systemctl enable --now ziti-edge-tunnel.service

sudo ziti-edge-tunnel add --jwt "$(< ./trino-client.jwt)" --identity trino-client

sudo chown -cR :ziti        /opt/openziti/etc/identities
sudo chmod -cR ug=rwX,o-rwx /opt/openziti/etc/identities

# package users can restart with systemd
sudo systemctl restart ziti-edge-tunnel.service