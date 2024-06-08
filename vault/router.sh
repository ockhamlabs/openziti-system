ziti edge create edge-router "router12" -t -o ./router12.jwt

ziti edge update identity "router12" \
    --role-attributes vault-hosts2

ziti edge create identity "vault-client2" \
    --role-attributes vault-clients2 \
    --jwt-output-file vault-client2.jwt

ziti edge create config "vault-intercept-config2" intercept.v1 \
    '{"protocols":["tcp"],"addresses":["vault1.ziti.internal"], "portRanges":[{"low":8203, "high":8203}]}'

ziti edge create config "vault-host-config2" host.v1 \
    '{"protocol":"tcp", "address":"13.60.60.200","port":8203}'

ziti edge create service "vault-service2" \
    --configs vault-intercept-config2,vault-host-config2


ziti edge create edge-router-policy "default" \
    --edge-router-roles '#all' --identity-roles '#all'

ziti edge create service-edge-router-policy "default" \
    --edge-router-roles '#all' --service-roles '#all'

ziti edge create service-policy "vault-dial-policy2" Dial \
    --service-roles '@vault-service2' --identity-roles '#vault-clients2'

ziti edge create service-policy "vault-bind-policy2" Bind \
    --service-roles '@vault-service2' --identity-roles '#vault-hosts2'

ziti edge policy-advisor services vault-service2 -q 


### then use vault-client id as 

curl -sSLf https://get.openziti.io/tun/scripts/install-ubuntu.bash | bash

sudo systemctl enable --now ziti-edge-tunnel.service

sudo ziti-edge-tunnel add --jwt "$(< ./vault-client.jwt)" --identity vault-client

sudo chown -cR :ziti        /opt/openziti/etc/identities
sudo chmod -cR ug=rwX,o-rwx /opt/openziti/etc/identities

# package users can restart with systemd
sudo systemctl restart ziti-edge-tunnel.service