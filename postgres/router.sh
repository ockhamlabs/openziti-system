wget https://get.openziti.io/install.bash

## update /opt/openziti/etc/router/bootstrap.env

sudo bash ./install.bash openziti-router

sudo systemctl restart ziti-router.service