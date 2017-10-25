# SLA OpenLDAP Proxy

Along with the SSO (Single Sign On) provided by SLA, there would be customer who wants to use their own authentication system apart from the one provided by SLA. This means there would be multiple LDAP servers from either customer or SLA which stores user and group information. This requires that there is a gateway for the access of different LDAP servers. This gateway will be the OpenLDAP Proxy in our context.

## Setup

### Docker image

1. Go to current directory containing Dockerfile
2. Update slapd.conf file if needed to set the correct values
3. Run below command to create the docker image
   <pre>docker build -t sla_openldap_proxy .</pre>
4. Run below command to start the container
   <pre>docker-compose up -d</pre>
   
## Contribution 
Please raise merge request for any change. Do not directly push to master branch.
