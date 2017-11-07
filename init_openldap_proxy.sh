#!/bin/bash -e

# This script initializes the OpenLDAP Proxy container of SLA. 
# It needs to reside in the same directory as the docker-compose.yml
# file.

# Implementation details:
#     1. The .env and the sla_openldap_proxy.env environment variable files 
#        should be configured properly before running the script.
#     2. Start a new container

# Author: ruifengm@sg.ibm.com
# Date: 2017-Oct-27

export DTR_HOST='sla-dtr.sby.ibm.com'
# export DTR_DEV_ORG='dev-user'
export DTR_DEV_ORG='gts-tia-sdad-sla-core-dev'
export DTR_PROD_ORG='gts-tia-sdad-sla-core'

CUR_DIR=$(dirname $0)
cd "${CUR_DIR}" && CUR_DIR=$PWD
[[ ! -d tmp ]] && mkdir tmp

ops='dev,release:,dtr-user:,dtr-pass:'
declare DEV_DEPLOY='false'
declare {RELEASE,DTR_USER,DTR_PASS}=''

USAGE="\n\033[0;36mUsage: $0 [--dev] [--release ivt_yyyymmdd-hhmm.###] [--dtr-user dtr_username] [--dtr-pass dtr_password]\033[0m\n"
OPTIONS=$(getopt --options '' --longoptions ${ops} --name "$0" -- "$@")
[[ $? != 0 ]] && exit 3

eval set -- "${OPTIONS}"
while true
do
    case "${1}" in
        --dev)
            DEV_DEPLOY='true'
            shift
            ;;
        --release)
            RELEASE="$2"
            shift 2
            ;;
        --dtr-user)
            DTR_USER="$2"
            shift 2
            ;;
        --dtr-pass)
            DTR_PASS="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo -e "\n\nUndefined options given!"
            echo "$*"
            echo -e "${USAGE}"
            exit 3
            ;;
    esac
done

[[ "${RELEASE}" == '' ]] && (echo -e "\033[0;31mError: no release tag specified! Check script usage.\033[0m\n$USAGE" && exit 1)
[[ "${DTR_USER}" == '' ]] && (echo -e "\033[0;31mError: no DTR username specified! Check script usage.\033[0m\n$USAGE" && exit 1)
[[ "${DTR_PASS}" == '' ]] && (echo -e "\033[0;31mError: no DTR password specified! Check script usage.\033[0m\n$USAGE" && exit 1)

if [[ "$DEV_DEPLOY" == 'true' ]]; then
    IMAGE_LOCATION="${DTR_HOST}/${DTR_DEV_ORG}"
else
    IMAGE_LOCATION="${DTR_HOST}/${DTR_PROD_ORG}"
fi

# Check for required environment variable files
[[ ! -f .env ]] && (echo -e "\033[0;31mError: .env file NOT found in current directory "${CUR_DIR}". Please make sure it's configured.\033[0m" && exit 1)
[[ ! -f sla_openldap_proxy.env ]] && (echo -e "\033[0;31mError: sla_openldap_proxy.env file NOT found in current directory "${CUR_DIR}". Please make sure it's configured.\033[0m" && exit 1)

# Set release tag
sed -i -e "s/.*RELEASE=.*/RELEASE=${RELEASE}/g" .env

# Start up
docker login -u ${DTR_USER} -p ${DTR_PASS} ${DTR_HOST}
docker pull ${IMAGE_LOCATION}/sla-openldap-proxy:${RELEASE} # pull image explicitly
export HOSTNAME=$(hostname)
export MAC_ADDRESS=$(ip link | grep -A 1 eth0: | grep ether | awk -F' ' '{print $2}')
# For first time deployment, store the mac address on the server in case its value gets changed
[[ ! -d /root/.secure ]] && mkdir -p /root/.secure
echo ${MAC_ADDRESS} >> /root/.secure/mac_address
docker-compose up -d

# Encrypt secrets
./encrypt_env_vars.sh

# Status check
docker ps
docker-compose logs

