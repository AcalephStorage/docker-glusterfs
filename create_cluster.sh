#!/bin/bash

API_SERVER=kubernetes.default
ABORT_TIMEOUT=600
CHECK_INTERVAL=10
GLUSTERD_PORT=24007

if [ -e /build/utils.sh ]; then
  . /build/utils.sh
fi

function detect_glusterd_nodes {
  local elapsed=0

  while [ $elapsed -lt $ABORT_TIMEOUT ]; do

    FOUND_OPEN=0
    sleep $CHECK_INTERVAL
    elapsed=$((elapsed + CHECK_INTERVAL))
    for peer_ip in "${IP_LIST[@]}"; do

      if port_open $peer_ip $GLUSTERD_PORT; then
        log_msg "glusterd detected on $peer_ip"
        FOUND_OPEN=$((FOUND_OPEN + 1)) 
      else
        log_msg "glusterd not detected on $peer_ip"
      fi            

    done

    if [ $FOUND_OPEN -eq $((NUM_PEERS)) ]; then
      break
    fi

  done
}

function create_cluster {
  local total_nodes=$((NUM_PEERS))
  local peers_added=1
  log_msg "All nodes required are available, creating a trusted storage pool of $total_nodes nodes"
  for peer_ip in "${IP_LIST[@]}"; do
    if IP_OK $peer_ip; then
      log_msg "skip self..."
    else 
      local glfs_response=$(gluster peer probe $peer_ip)
      if [ $? -eq 0 ]; then
        log_msg "Added node $peer_ip .... ( $glfs_response)"
        peers_added=$((peers_added + 1))
      else
        log_msg "Addition of $peer_ip to the cluster failed ($glfs_response)"
        exit 1
      fi
    fi
  done

  if [ $peers_added -eq $((NUM_PEERS)) ]; then
    log_msg "All nodes requested added to the cluster successfully"
  else
    log_msg "Error encountered adding node(s) to the cluster. Unable to continue"
  fi
}

get_peer_addresses $K8S_URL
NUM_PEERS=${#IP_LIST[@]}

detect_glusterd_nodes

if [ $FOUND_OPEN -eq $((NUM_PEERS)) ] ; then
  create_cluster
else
  log_msg "Not all peers detected, and timeout threshold ($ABORT_TIMEOUT) exceeded."
fi



