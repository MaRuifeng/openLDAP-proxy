#!/bin/bash -e

##########################################################################################
# CCSSD OpenLDAP Proxy build for docker environment
# 1. Build docker image(s) with proper version tag and push it(them) to DTR
# Note: this build script is primarily written for Jenkins use (https://itaas-build.sby.ibm.com:9443/),
#       and it takes git resources and environment variables from preceding steps.
# 2. Package deployment scripts/files into a tar ball

# Author:
#  Ruifeng Ma <ruifengm@sg.ibm.com>
# Date:
#  2017-Oct-27
##########################################################################################


# ============= Build and push docker images (Start) ============= #
DTR_HOST='gts-sla-docker-local.artifactory.swg-devops.com'
# DTR_ORG='dev-user'
DTR_ORG='gts-tia-sdad-sla-core-dev'
DTR="${DTR_HOST}/${DTR_ORG}"

cd $WORKSPACE

# Build required docker images
echo -e "Building OpenLDAP Proxy image ..."
cd ./openLDAP-proxy/
docker build -t sla-openldap-proxy ./
docker tag sla-openldap-proxy $DTR/sla-openldap-proxy:$BUILD_VERSION
cd $WORKSPACE

# Push to DTR
docker push $DTR/sla-openldap-proxy:$BUILD_VERSION
# ============= Build and push docker images (End) ============= #

# ============= Packaging deployment/upgrade files (Start) ============= #
cd $WORKSPACE
export ARTIFACT_DIR=$WORKSPACE/$BUILD_VERSION"/sla-openldap-proxy"
rm -rf $ARTIFACT_DIR
mkdir -p $ARTIFACT_DIR

echo -e "Packaging sla-openldap-proxy deployment/upgrade files..."
TARFILE_DEPLOY="$ARTIFACT_DIR/sla-openldap-proxy_deploy-${BUILD_VERSION}.tar.gz"
TARFILE_UPGRADE="$ARTIFACT_DIR/sla-openldap-proxy_upgrade-${BUILD_VERSION}.tar.gz"
rm -f "${TARFILE_DEPLOY}"
rm -f "${TARFILE_UPGRADE}"
cd ./openLDAP-proxy/

find . -name docker_deployment_files.list | while read FILE_LIST
do
     FILEPATH=${FILE_LIST%/*}  # remove shortest '/*' from back
     echo "Creating $TARFILE_DEPLOY"
     grep -vE '(^#|^\s*$|^\s*\t*#)' $FILE_LIST | tar -C $FILEPATH -hzcvf $TARFILE_DEPLOY -T -
done

find . -name docker_upgrade_files.list | while read FILE_LIST
do
     FILEPATH=${FILE_LIST%/*}  # remove shortest '/*' from back
     echo "Creating $TARFILE_UPGRADE"
     grep -vE '(^#|^\s*$|^\s*\t*#)' $FILE_LIST | tar -C $FILEPATH -hzcvf $TARFILE_UPGRADE -T -
done
# ============= Packaging deployment/upgrade files (End) ============= #
