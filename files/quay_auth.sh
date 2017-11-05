#!/bin/bash -v

# TODO: only write if not there
echo 'ECS_ENGINE_AUTH_DATA={"https://quay.io": {"auth": "${quay_auth}", "email": ".", "username": "${quay_user}"}}' >>/etc/ecs/ecs.config

# If this runs after docker starts
#sudo service docker stop
#sudo service docker start
#sudo start ecs
