FROM ubuntu:14.04

MAINTAINER ""

RUN ["/bin/bash", "-c", "mkdir -p /build/config/{etc/glusterfs,var/lib/glusterd,var/log/glusterfs}"]

RUN apt-get update && \
    apt-get install -y python-software-properties software-properties-common 

RUN add-apt-repository -y ppa:gluster/glusterfs-3.7 && \
    apt-get update && \
    apt-get install -y glusterfs-server curl lvm2 xfsprogs

RUN cp -pr /etc/glusterfs/* /build/config/etc/glusterfs && \
    cp -pr /var/lib/glusterd/* /build/config/var/lib/glusterd && \
    cp -pr /var/log/glusterfs/* /build/config/var/log/glusterfs 2> /dev/null || true

ADD entrypoint.sh /build/entrypoint.sh
ADD utils.sh /build/utils.sh
ADD create_cluster.sh /build/create_cluster.sh

EXPOSE 24007 2049 6010 6011 6012 38465 38466 38468 \
       38469 49152 49153 49154 49156 49157 49158 49159 49160 49161 49162

ENTRYPOINT ["/build/entrypoint.sh"]

