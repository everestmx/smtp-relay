#!/bin/bash

# Defaults
if [ -z "$MAILNAME" ]; then
    echo "smtp >> Error: MAILNAME not specified"
    exit 1
else
    echo "$MAILNAME" > /etc/hostname
    echo "$MAILNAME" > /etc/mailname
    postconf -e myhostname="$MAILNAME"
fi

# Set Local networks
if [ -z "$NETWORKS" ]; then
    postconf -e mynetworks="127.0.0.0/8, 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16"
else
    postconf -e mynetworks="$NETWORKS"
fi

# Bind IP
if [ ! -z "$BIND_IP" ]; then
    postconf -e inet_interfaces="$BIND_IP"
    postconf -e smtp_bind_address="$BIND_IP"
    postconf -e smtp_address_preference=ipv4
    postconf -e postscreen_upstream_proxy_protocol=haproxy
fi

postconf -e maximal_queue_lifetime=3h
postconf -e bounce_queue_lifetime=3h
postconf -e delay_warning_time=0h
postconf -e queue_run_delay=300s

service syslog-ng start
service postfix start

touch /var/log/mail.log
touch /var/log/mail.err
touch /var/log/mail.warn

chmod a+rw /var/log/mail.*
tail -F /var/log/mail.log
