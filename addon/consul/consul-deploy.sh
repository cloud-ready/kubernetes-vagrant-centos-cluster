#!/usr/bin/env bash

#./consul-deploy.sh "172.17.8.101,172.17.8.102" "dev" "consul" "8.8.8.8"
#dig @localhost -p 53 consul.service.dev.consul
#dig @localhost -p 53 consul-server1.node.dev.consul
# see: [DNS Interface](https://www.consul.io/docs/agent/dns.html)

# Problems binding client to 0.0.0.0 using client_addr
# see: https://github.com/hashicorp/consul/issues/3924

CONSUL_BIND_INTERFACE="eth1"
HOST_IPADDRESS="$(ip addr show ${CONSUL_BIND_INTERFACE} | grep -Po 'inet \K[\d.]+')"
CONSUL_IMAGE="cloudready/consul:1.4.4-SNAPSHOT"

echo "CONSUL_BIND_INTERFACE: ${CONSUL_BIND_INTERFACE}"
echo "HOST_IPADDRESS: ${HOST_IPADDRESS}"
echo "CONSUL_IMAGE: ${CONSUL_IMAGE}"


CONSUL_RECURSORS=$4
CONSUL_DOMAIN=$3
CONSUL_DATACENTER=$2

_SERVERS="$1"
if [[ -z "${_SERVERS}" ]]; then echo "no servers specified."; exit 1; fi
IFS=',' read -a SERVERS <<< "${_SERVERS}"

HOST_IS_SERVER="false"
RETRY_JOIN=""
for server in ${SERVERS[@]}; do
    (( SERVER_NUM += 1 ))
    RETRY_JOIN="${RETRY_JOIN} -retry-join=${server}"
    if [[ "${HOST_IPADDRESS}" == "${server}" ]]; then HOST_IS_SERVER="true"; break; fi
done

echo "_SERVERS: ${_SERVERS}"
echo "CONSUL_DATACENTER: ${CONSUL_DATACENTER}"
echo "CONSUL_DOMAIN: ${CONSUL_DOMAIN}"
echo "CONSUL_RECURSORS: ${CONSUL_RECURSORS}"


CONSUL_HOSTNAME="consul"
CONSUL_COMMAND="agent -bind=${HOST_IPADDRESS} -client=0.0.0.0"
CONSUL_COMMAND="${CONSUL_COMMAND} -datacenter=${CONSUL_DATACENTER:-dev} -dns-port=53 -domain=${CONSUL_DOMAIN:-consul}"
CONSUL_COMMAND="${CONSUL_COMMAND} ${RETRY_JOIN} -retry-interval=30s -retry-max=0"
CONSUL_COMMAND="${CONSUL_COMMAND} -ui=true"
if [[ "${HOST_IS_SERVER}" == "true" ]]; then
    CONSUL_COMMAND="${CONSUL_COMMAND} -bootstrap-expect=${#SERVERS[@]} -server"
    #CONSUL_HOSTNAME="${CONSUL_HOSTNAME}-server$(echo ${HOST_IPADDRESS} | awk -F. '{print $NF}')"
    CONSUL_HOSTNAME="${CONSUL_HOSTNAME}-server${SERVER_NUM}"
else
    CONSUL_HOSTNAME="${CONSUL_HOSTNAME}-client$(echo ${HOST_IPADDRESS} | awk -F. '{print $NF}')"
fi

echo "CONSUL_HOSTNAME: ${CONSUL_HOSTNAME}"
echo "CONSUL_COMMAND: ${CONSUL_COMMAND}"


docker pull ${CONSUL_IMAGE}
#    -p 8300:8300/tcp \
#    -p 8302:8302/tcp \
#    -p 8302:8302/udp \
#    -p 8500:8500/tcp \
#    -v /tmp:/consul/data
docker stop ${CONSUL_HOSTNAME} || echo error on docker stop ${CONSUL_HOSTNAME}
docker rm -fv ${CONSUL_HOSTNAME} || echo error on docker rm -fv ${CONSUL_HOSTNAME}
docker run \
    --cap-add=NET_BIND_SERVICE \
    -d \
    -e CONSUL_ALLOW_PRIVILEGED_PORTS="1" \
    -e CONSUL_BIND_INTERFACE="${CONSUL_BIND_INTERFACE:-eth0}" \
    -e CONSUL_LOCAL_CONFIG="{\"leave_on_terminate\": true}" \
    -e CONSUL_RECURSORS="${CONSUL_RECURSORS:-8.8.8.8}" \
    -e HOST_IPADDRESS="${HOST_IPADDRESS:-0.0.0.0}" \
    -h ${CONSUL_HOSTNAME} \
    --name=${CONSUL_HOSTNAME} \
    --network=host \
    -v /etc/resolv.conf:/var/lib/host_etc_resolv.conf \
    --restart=always \
    ${CONSUL_IMAGE} ${CONSUL_COMMAND}

# see: https://github.com/gliderlabs/registrator
# see: http://gliderlabs.github.io/registrator/latest/user/run/
# see: http://gliderlabs.github.io/registrator/latest/user/backends/
docker stop registrator-consul || echo error on docker stop registrator-consul
docker rm -fv registrator-consul || echo error on docker rm -fv registrator-consul
docker run \
    -d \
    --name=registrator-consul \
    --net=host \
    --volume=/var/run/docker.sock:/tmp/docker.sock \
    gliderlabs/registrator:latest \
    -cleanup=true \
    -deregister="always" \
    -internal=true \
    -resync=0 \
    -retry-attempts=-1 \
    -retry-interval=5000 \
    -tags="registrator" \
    -ttl=0 \
    -ttl-refresh=0 \
    consul://localhost:8500

# Test registrator
#docker run -d -P -e "SERVICE_6379_NAME=redis" -e "SERVICE_6379_ID=redis1" --name=redis1 redis
#docker run -d -P -e "SERVICE_6379_NAME=redis" -e "SERVICE_6379_ID=redis2" --name=redis2 redis
#curl "http://localhost:8500/v1/catalog/service/redis"
#dig @localhost redis.service.consul SRV
#dig @localhost -p 53 redis.service.dev.consul +answer

#docker run -d -p :80 -e "SERVICE_80_NAME=http" -e "SERVICE_80_ID=nginx1" -e "SERVICE_80_CHECK_HTTP=true" -e "SERVICE_80_CHECK_HTTP=/" -e "SERVICE_80_CHECK_TTL=30s" --name=nginx1 nginx
#docker run -d -p :80 -e "SERVICE_80_NAME=http" -e "SERVICE_80_ID=nginx2" -e "SERVICE_80_CHECK_HTTP=true" -e "SERVICE_80_CHECK_HTTP=/" -e "SERVICE_80_CHECK_TTL=30s" --name=nginx2 nginx
#dig @localhost http.service.consul SRV
#dig @localhost -p 53 http.service.dev.consul +answer
