#!/usr/bin/env bash

# Script to start SL on sentinel node. This means swci is started 
# with an init script (swci/swci-init) that runs the build and run tasks.

joinToken=$1
DNSIP=10.10.0.3
APLSIP=172.17.0.4
MLVMIP=172.17.0.4

echo "Assumption: APLS running with licence installed. DNS image available."
echo "Assumption: DNS running at: "$DNSIP
# BUILD DNS: 
#if [[ -z "$(docker images -q bind9:hus.org)" ]]; then
#    docker build -t bind9:hus.org --build-arg http_proxy= --build-arg https_proxy= --build-arg no_proxy= - < /opt/hpe/swarm-learning/examples/reverse-proxy/common/Bind-Dockerfile
#fi

# RUN DNS: 
docker run -d --name=swarm-bind9 -e no_proxy= bind9:hus.org -d swarm

# API: 
docker exec swarm-bind9 add-dns -d api.sn.hus.org.swarm -i $MLVMIP
# P2P: 
docker exec swarm-bind9 add-dns -d p2p.sn.hus.org.swarm -i $MLVMIP
# FS: 
docker exec swarm-bind9 add-dns -d fs.sl.hus.org.swarm -i $MLVMIP

# API: 
docker exec swarm-bind9 add-dns -d api.sn.hustmp.org.swarm -i 13.79.76.164 
# P2P: 
docker exec swarm-bind9 add-dns -d p2p.sn.hustmp.org.swarm -i 13.79.76.164 
# FS: 
docker exec swarm-bind9 add-dns -d fs.sl.hustmp.org.swarm -i 13.79.76.164 

# ADD JOINT TOKEN TO AGENT:
sed -f - "/opt/hpe/hus/internal-VM-workspace/spire-agent/agent.conf.template" > /opt/hpe/hus/internal-VM-workspace/spire-agent/agent.conf << _EOF
s/<JOIN-TOKEN>/${joinToken}/g
_EOF

# RUN SPIRE AGENT:
echo "RUN SPIRE AGENT" 
docker run -dt --name spire-agent --network-alias spire-agent -v /tmp:/tmp -v /var/run/docker.sock:/var/run/dock
er.sock -v /opt/hpe/hus/internal-VM-workspace/spire-agent:/opt/spire/conf/agent --pid=host gcr.io/spiffe-io/spire-agent:1.5.1 
sleep 10

# RUN APLS: 
#if [[ ! "$(docker ps -q -f name=apls)" ]]; then
#    docker run -d --name=apls -p 5814:5814 hub.myenterpriselicense.hpe.com/hpe_eval/swarm-learning/apls:0.3.0
#fi

# INSERT LICENSE: 

#echo \"Please go to https://172.17.0.4:5814 and enter the license. User: admin, Password: password. Find more information here: https://github.com/HewlettPackard/swarm-learning/blob/master/docs/HPE%20AutoPass%20License%20Server%20User%20Guide.pdf\"

# CHECK IF LICENSE HAS BEEN INSERTERD
#echo "Did you enter license into APLS (yes)?"

#read choice

#if [ "$choice" != "yes" ]; then
#    echo "Invalid choice"
#    exit 1
#fi

# CREATE VOLUME
echo "CREATE VOLUME"
docker volume rm sl-cli-lib
docker volume create sl-cli-lib
docker container create --name helper -v sl-cli-lib:/data hello-world
docker cp -L /opt/hpe/swarm-learning/lib/swarmlearning-client-py3-none-manylinux_2_24_x86_64.whl helper:/data
docker rm helper

# RUN SN: 
echo "Starting SN..."
#/opt/hpe/swarm-learning/scripts/bin/run-sn --name=sn-hus.org --label type=sn --hostname=sn-hus.org --dns=DNSIP --sn-api-service=api.sn.hus.org.swarm --sn-p2p-service=p2p.sn.hus.org.swarm:30353 -p 30353:30303 -p 30374:30304 --sentinel --apls-ip=172.17.0.4 -e no_proxy= --socket-path /tmp/agent.sock 
/opt/hpe/swarm-learning/scripts/bin/run-sn -d --name=sn-hus.org --hostname=sn-hus.org --label type=sn --sn-api-service=api.sn.hus.org.swarm:30374 -p 30374:30304 --sn-p2p-service=p2p.sn.hus.org.swarm:30353 --apls-ip=$APLSIP --dns=$DNSIP --sentinel -e no_proxy= --socket-path /tmp/agent.sock

# CHECK IF SN API IS UP
retries=10
while [[ ${retries} -gt 0 ]]
do
    echo $retries
    if docker logs sn-hus.org | grep -q 30304; then
        echo "SN API service is Started"
        break
    else
        echo "Waiting for SN API to come up..."
        if [[ ${retries} = 1 ]]
        then
            echo "API is not running, exiting ..."
            exit 1
        fi
        retries=$((retries-1))
        sleep 60
    fi
 done
 
# RUN SWOP: 
echo "Starting SWOP..."
/opt/hpe/swarm-learning/scripts/bin/run-swop -d --name=swop-hus.org --label type=swop --dns=DNSIP --sn-api-service=api.sn.hus.org.swarm --apls-ip=$APLSIP -e no_proxy= -e http_proxy= -e https_proxy= -e SWOP_KEEP_CONTAINERS=1 --usr-dir=/opt/hpe/swarm-learning/projects/FinOmopSL/swop --profile-file-name=swop_profile.yaml --socket-
path /tmp/agent.sock 


# RUN SWCI: 
/opt/hpe/swarm-learning/scripts/bin/run-swci --rm=false -dt --name=swci-hus.org --label type=swci --dns=DNSIP --apls-ip=$APLSIP -e no_proxy= -e http_proxy= -e https_proxy= --usr-dir=/opt/hpe/swarm-learning/projects/FinOmopSL/swci --init-script-name=swci-init --socket-path /tmp/agent.sock