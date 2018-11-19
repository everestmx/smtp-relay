#!/bin/bash

echo "Setup iptables rules"
iptables -F
iptables --policy INPUT ACCEPT
iptables --policy OUTPUT ACCEPT
iptables --policy FORWARD ACCEPT
iptables -A INPUT -i lo -j ACCEPT
iptables -A FORWARD -i eno3 -o eno3 -j ACCEPT

iptables -A INPUT -p tcp -m tcp -s 4.3.2.1 -d 1.2.3.4 --dport 25 -j ACCEPT
iptables -A INPUT -p tcp -m tcp --dport 25 -j DROP

echo "Start build image"
docker build -t postex-relay . > /dev/null 2>&1

echo "Kill all containers"
docker kill $(docker ps -q -a) > /dev/null 2>&1

echo "Remove all containers"
docker rm $(docker ps -q -a) > /dev/null 2>&1

echo "Setup haproxy"
cat <<EOF > /etc/haproxy/haproxy.cfg
listen smtp-gw
    bind 1.2.3.4:25
    mode tcp
    option tcplog
    balance roundrobin
    timeout connect 5s
    timeout client 3s
    timeout server 3s
EOF

COUNTER=0

# Setup Docker Configuration
for IP in $(ip addr show eno3 | grep 'inet ' | grep 'eno3:' | awk '{print $2}' | awk -F'/' '{print $1}')
do
    COUNTER=$((COUNTER+1))
    MAILNAME=$(dig +short -x $IP | sed 's/.$//')

    if [[ "$MAILNAME" != *"domain.mail"* ]]; then
      echo "Skip [smtp-$COUNTER-gw] on: $IP with PTR: $MAILNAME"
      continue
    fi

    echo "Run [smtp-$COUNTER-gw] on: $IP:25, PTR: $MAILNAME"

    docker run -d \
        -p $IP:25:25 \
        -e BIND_IP="$IP" \
        -e MAILNAME="$MAILNAME" \
        -e NETWORKS="1.2.3.4/32, 4.3.2.1/32, $IP/32" \
        -v $(pwd)/spool/$MAILNAME:/var/spool/postfix:rw \
        --name=smtp-$COUNTER-gw \
        --hostname=$MAILNAME \
        --network=host \
        --dns-search=postex.email \
        --dns=8.8.8.8 \
        --dns=8.8.4.4 \
        --log-driver gelf \
        --log-opt gelf-address=udp://graylog-server:12401 \
        postex-relay > /dev/null 2>&1

    # Add ip to haproxy config
    echo "    server smtp-$COUNTER-gw $IP:25 check" >> /etc/haproxy/haproxy.cfg
done

echo "Restart haproxy service"
service haproxy restart
