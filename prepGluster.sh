#!/usr/bin/bash

function prep_directories {
  echo "- creating directories for glusterfs config and logging"  
  mkdir /etc/glusterfs \
        /var/lib/glusterd \
        /var/log/glusterfs

  #chcon -Rt svirt_sandbox_file_t /etc/glusterfs
  #chcon -Rt svirt_sandbox_file_t /var/lib/glusterd
  #chcon -Rt svirt_sandbox_file_t /var/log/glusterfs
}

function disk_used {
  return $(blkid $1 &> /dev/null; echo $?)
}

function format_device {
	
  # Addition logic is needed here to account for RAID LUNs to ensure the 
  # alignment is correct. The code here is ONLY suitable for POC/demo
  # purposes.	
	
  echo "- configuring $BRICK_DEV with LVM"
  
  pvcreate $BRICK_DEV
  vgcreate gluster $BRICK_DEV
  
  local meta_data_size
  local size_limit=1099511627776
  local disk_size=$(vgs gluster --noheadings --nosuffix --units b -o vg_size)
  local extent_size=$(vgs gluster --nosuffix --unit b --noheadings -o vg_extent_size)
  local vg_free=$(vgs gluster --noheadings -o vg_free_count)
  
  # Use 'extents' as unit of calculation
  if [ ${disk_size} -gt ${size_limit} ]; then 
    # meta data size is 16GB
    meta_data_size=$((17179869184/extent_size))
  else
    # metadata size is 0.5% of the disk's extent count
    meta_data_size=$((vg_free/200))
  fi
  
  # create the pool - must be a multiple of 512
  total_meta_data=$((meta_data_size*2))
  local pool_size=$((vg_free-total_meta_data))
  lvcreate -L $((pool_size*extent_size))b -T gluster/brickpool -c 256K \
           --poolmetadatasize $((meta_data_size*extent_size))b \
           --poolmetadataspare y
  
  # lvcreate thin dev @ 90% of the brick pool, assuming snapshot support
  local lv_size=$(((pool_size/100)*90))
  lvcreate -V $((lv_size*extent_size))b -T gluster/brickpool -n brick1
  
  echo "- Creating XFS filesystem"
  # mkfs.xfs
  mkfs.xfs -i size=512 /dev/gluster/brick1 1> /dev/null
  if [ $? -eq 0 ]; then 
    echo "- filesystem created successfully"
  else 
    exit 1
  fi
}


function prep_disk {
  # Assumptions
  # 1. a host will provide a single RAID-6 LUN
  # 2. logic deals with prior runs, not random disk configurations
  #
  	
  echo -e "\nPreparing $BRICK_DEV for gluster use"
  if ! disk_used $BRICK_DEV ; then 
    format_device $BRICK_DEV
  else
    echo -e "\nthe device $BRICK_DEV specified is already used"
  fi
}

function check_block {
  local len=${#1}
  local dev=${1:0:5}
  if [ $len -le 5 ] || [ $dev != "/dev/"  ]; then
    return 1
  else
    return 0
  fi
}


echo -e "\nChecking configuration directories"
if [ ! -e /etc/glusterfs ] ; then 
  prep_directories
else 
  echo -e "- glusterfs directories already present, nothing to do"
fi

BRICK_DEV=$1

if [ -z $BRICK_DEV ]; then
  echo "No device specified."
else
  if check_block $BRICK_DEV; then
    prep_disk
  else 
    echo -e "\nInvalid device: $BRICK_DEV"
  fi
fi
  
