#!/bin/bash -e

# Start the openLDAP proxy container

# Author:
#  Ruifeng Ma <ruifengm@sg.ibm.com>
# Date:
#  2017-Oct-26

TOPDIR=$(dirname $0)
cd $TOPDIR && TOPDIR=$PWD

export HOSTNAME=$(hostname)
export MAC_ADDRESS=${cat /root/.secure/mac_address} || export MAC_ADDRESS=$(ip link | grep -A 1 eth0: | grep ether | awk -F' ' '{print $2}')

docker-compose up -d --no-recreate