#!/bin/bash

# Purpose: Docker utils
# Author : Anh K. Huynh
# Date   : 2015 May 04th

# Return IP address of a docker container
# Input : $1: Docker container ID / name
# Output: The IP address
docker_to_ip() {
  docker inspect --format='{{.NetworkSettings.IPAddress}}' $1
}

# Return iptables (NAT) rules for a running container
# Input : Container ID/Name
# Output: iptables commands
container_to_nat() {
  local _ip=
  local _id="${1:-xxx}"

  _ip="$(docker_to_ip $_id)"
  [[ $? -eq 0 ]] || return $?

  docker inspect \
    --format='{{range $p, $conf := .NetworkSettings.Ports}} {{if $conf}} {{printf "%s/%s\n" (index $conf 0).HostPort $p}} {{end}} {{end}}' \
    $_id \
  | grep /\
  | awk \
      -F/\
      -vIP=$_ip \
      -vCONTAINER_ID=$_id \
      '{
        printf("iptables -t nat -C POSTROUTING -s %s/32 -d %s/32 -p tcp -m tcp --dport %s -j MASQUERADE 2>/dev/null \\\n", IP, IP, $2);
        printf("|| iptables -t nat -A POSTROUTING -s %s/32 -d %s/32 -p tcp -m tcp --dport %s -j MASQUERADE\n", IP, IP, $2);

        printf("iptables -t nat -C DOCKER ! -i docker0 -p tcp -m tcp --dport %s -j DNAT --to-destination %s:%s 2>/dev/null \\\n", $1, IP, $2);
        printf("|| iptables -t nat -A DOCKER ! -i docker0 -p tcp -m tcp --dport %s -j DNAT --to-destination %s:%s\n", $1, IP, $2);

        printf("iptables -C DOCKER -d %s/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport %s -j ACCEPT 2>/dev/null \\\n", IP, $2);
        printf("|| iptables -A DOCKER -d %s/32 ! -i docker0 -o docker0 -p tcp -m tcp --dport %s -j ACCEPT\n", IP, $2);
      }'
}

# Return iptables (NAT) rules for all running containers
# Input : NONE
# Output: all iptables rules for running container
containers_to_nat() {
  while read CONTAINER_ID; do
    echo >&2 ":: docker/firewall: Generating rule for $CONTAINER_ID..."
    container_to_nat $CONTAINER_ID
  done < <(docker ps -q)
}