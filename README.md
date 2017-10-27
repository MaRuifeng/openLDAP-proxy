# SLA OpenLDAP Proxy

Along with the SSO (Single Sign On) provided by SLA, there would be customer who wants to use their own authentication system apart from the one provided by SLA. This means there would be multiple LDAP servers from either customer or SLA that store user and group information. This requires that there is a gateway for the access of different LDAP servers. This gateway will be the OpenLDAP Proxy in our context.

## Setup locally

An openLDAP server can be installed locally to test the configurations. 

## Setup with docker

1. Go to current directory containing the Dockerfile
2. Update slapd.conf file if needed to set the correct values
3. Run below command to create the docker image
   <pre>docker build -t sla_openldap_proxy .</pre>
4. Run below command to start the container
   <pre>docker-compose up -d</pre>

## Build

For local build, use the docker build command in the source code directory. 
    
For Jenkins build, trigger the job <https://itaas-build.sby.ibm.com:9443/view/SLA-Builds/job/CCSSD-OpenLDAP_Proxy/>

## Deployment

This service container should be deployed to the docker host where the Chef container resides, for balance of loading.

All secret value entries contained in the environment variable file are encrypted by running the `encrypt_env_vars.sh` script. The service container should be up to support the execution of this script. 
   
## Contribution 
Please raise merge request for any change. Do not directly push to master branch.
