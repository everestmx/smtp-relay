FROM debian:stretch

MAINTAINER NEO Dev <everestmx@gmail.com>

ENV DEBIAN_FRONTEND noninteractive

RUN set -xe; \
    apt-get update && apt-get install -y --no-install-recommends \
    wget curl sudo procps git apt-utils debconf postfix syslog-ng net-tools

# Allow ports
EXPOSE 25

ADD ./postfix/main.cf /etc/postfix/main.cf
ADD ./postfix/start.sh /etc/postfix/start.sh

RUN set -xe; \
    chmod 0700 /etc/postfix/start.sh

# Clean system
RUN set -xe; \
        apt-get clean && \
    rm -rf /tmp/* && \
    rm -rf /var/lib/apt/lists/* && \
    rm -rf /var/tmp/* && \
    rm -rf /var/cache/apt/archive/*.deb

ENTRYPOINT ["/etc/postfix/start.sh"]
