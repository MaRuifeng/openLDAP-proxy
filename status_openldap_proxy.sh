#!/bin/bash -e

# Check the running status of the openLDAP proxy container

# Author:
#  Ruifeng Ma <ruifengm@sg.ibm.com>
# Date:
#  2017-Oct-26

TOPDIR=$(dirname $0)
cd $TOPDIR && TOPDIR=$PWD

docker-compose ps
docker-compose logs