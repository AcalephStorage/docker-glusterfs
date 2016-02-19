#!/bin/bash


if [ -e /build/utils.sh ]; then
  . /build/utils.sh
fi

function check_running_gluster {

  netstat -tan | grep 24007 &> /dev/null
  return $?
}

function valid_lvname {
  local size=${#1}
  local sfx=${1: -2}

  # a gluster snapshot lv looks like 03613e95ee644159919541c32f45b45d_0
  # so, look at the lvname and if it looks like a snapshot return a 
  # not valid result
  if [ $size -ge 34 ] && [ $sfx == "_0" ]; then
    return 1
  else
    return 0
  fi
}

function configure_brick {
  # check if a glusterfs brick is present, and mount accordingly
  #
  # Assume the vg is called gluster, and the thin pool is called brickpool 
  #local lv_list=($(lvs --noheadings -S vg_name=gluster,pool_lv=brickpool -o lv_name 2> /dev/null))
  local lv_list=($(lvs -o lv_name,vg_name,pool_lv --noheadings | awk '$3 == "brickpool" {print $1}' 2> /dev/null))

  if [ ${#lv_list[@]} -gt 0 ]; then
    mkdir /gluster
    for lv in ${lv_list[@]}; do
      if valid_lvname $lv; then
        brick=$(echo "${lv}" | sed 's/\ //g')
        log_msg "Adding LV ${brick} to fstab at /gluster/${brick}"
        mkdir /gluster/${brick}
        echo -e "/dev/gluster/${brick}\t/gluster/${brick}\t\txfs\t"\
          "defaults,inode64,noatime\t0 0" | tee -a /etc/fstab > /dev/null
    else
        log_msg "Skipping ${lv} - not a valid name to mount to the filesystem (snapshot?)"
      fi

    done
    log_msg "Mounting the brick(s) to this container"
    mount -a
  else
    log_msg "No compatible disks detected on this host"
  fi

}

function get_own_ip {
  get_peer_addresses $K8S_URL

  local found=0
  for peer_ip in "${IP_LIST[@]}"; do
    if IP_OK $peer_ip; then
      log_msg "own ip is $peer_ip"
      NODE_IP=$peer_ip;
      found=1
    fi
  done

  if [ $found -eq 0 ]; then
    log_msg "failed to get own ip"
  fi
}


function configure_network {
  #
  # Check networking available to the container, and configure accordingly
  #

  log_msg "checking $NODE_IP is available on this host"
  if IP_OK $NODE_IP; then

    # IP address provided is valid, so configure the services
    log_msg "$NODE_IP is valid"

    #log_msg "Checking glusterd is only binding to $NODE_IP"
    #if ! grep $NODE_IP /etc/glusterfs/glusterd.vol &> /dev/null; then
    #  log_msg "Updating glusterd to bind only to $NODE_IP"
    #  sed -i.bkup "/end-volume/i \ \ \ \ option transport.socket.bind-address ${NODE_IP}" /etc/glusterfs/glusterd.vol
    #else
    #  log_msg "glusterd already set to $NODE_IP"
    #fi

  else

    log_msg "IP address $NODE_IP is not available on this host. Can not start the container"
    exit 1

  fi
}

if [ ! -e /etc/glusterfs/glusterd.vol ]; then
  # this is the first run, so we need to seed the configuration
  log_msg "Seeding the configuration directories"
  cp -pr /build/config/etc/glusterfs/* /etc/glusterfs
  cp -pr /build/config/var/lib/glusterd/* /var/lib/glusterd
  cp -pr /build/config/var/log/glusterfs/* /var/log/glusterfs
fi

if ! check_running_gluster; then

  get_own_ip
  configure_network
  configure_brick

  if empty_dir /var/lib/glusterd/peers  ; then
    log_msg "Existing peer node definitions have not been found"
    log_msg "Using the list of peers from the etcd configuration"
    log_msg "Forking the create_cluster process"
    /build/create_cluster.sh &

  else
    log_msg "Using peer definition from previous container start"
  fi

  # run gluster
  /usr/sbin/glusterd -N -p /var/run/glusterd.pid 
else
  # log: notify that another glusterservice is running in such node
  log_msg "Unable to start the container, a gluster instance is already running on this host"
fi 


