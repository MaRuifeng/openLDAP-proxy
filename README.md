# OpenLDAP Proxy

LDAP stands for Lightweight Directory Access Protocol, which is a lightweight protocol for accessing and maintaining directory information services over an Internet Protocol (IP) network. The information that can be shared via LDAP includes users, groups, systems and networks etc. The LDAP information model is based on `entries`. An `entry` is a collection of attributes that has a globally-unique *Distringuished Name (DN)*, which can be used to refer to the entry itself unambiguously. LDAP is being largely used in context like user/group query and management, user authentication and organization representation etc. The OpenLDAP software is an open source implementation of LDAP services. See its [introduction page](https://www.openldap.org/doc/admin24/intro.html). 

Often there are applications whose user base consists of multiple LDAP sources, and some of them might even be of different nature (e.g. Linux LDAP vs. Windows AD). To ease the complexity of integrating multiple LDAP sources, it's better to provide a single unified interface with proper abstraction. That is where the idea of LDAP proxying comes into play. 

Particularly in our use case in IBM, a bunch of enterprise customers have their own LDAP servers that render user/group management. After federating them with our own identify provider (IBMid) to enable Single-Sign-On via the OAuth2 framework, we also need to query their LDAP servers for more detailed user/group information. This openLDAP proxy was created for that purpose.  

The [slapd-meta](http://www.openldap.org/software/man.cgi?query=slapd-meta&apropos=0&sektion=0&manpath=OpenLDAP+2.4-Release&format=html) backend in the OpenLDAP software suite performs basic LDAP proxying with respect to a set of remote LDAP servers. This project is built upon it to provide a unified LDAP querying interface for multiple backend LDAP servers. 

## Development Setup

It's handy to set up a local development environment to try out different config settings. Below sample commands are for an Ubuntu environment. 
1. Install OpenLDAP: `sudo apt-get install slapd`
2. Locate the [slpad.conf](https://www.openldap.org/doc/admin24/slapdconf2.html) file and edit it based on needs: `vim /etc/ldap/slapd.conf`. A sample file with `database meta` section configured is found in the source code. 
3. Start the openLDAP proxy service: `/usr/sbin/slapd -h 'ldap:/// ldapi:/// ldaps:///' -g openldap -u openldap -f /etc/ldap/slapd.conf -d 256`
4. After OpenLDAP installation, there will be a default `openldap` process running if it's configured as start on system boot. It needs to be killed to start the new process. 
5. Install ldap-utils for client operations like LDAP query: `sudo apt-get install ldap-utils`
6. Test the proxy (sample command only): `ldapsearch -h localhost -x -b "dc=sla,dc=ibm,dc=com" "mail=ruifengm@sg.ibm.com"`

## Development Setup with Docker

Alternatively, development can be done via docker. Details are covered in below build and deployment sections. 

## Build

* Local build - Navigate to the source code directory where the `Dockerfile` is located and run `docker build -t sla_openldap_proxy .`
* CI - The `openldap_proxy_jenkins_build.sh` is a script that can be used to configure a Jenkins build job. 
    
## Deployment

To deploy the openLDAP proxy container, information of the backend LDAP servers needs to be gathered and arranged into the `sla_openldap_proxy.env` environment variable file prior to starting the container. 

### Proxy Config
Set the `suffix`, `rootdn` and `rootpw` attributes in this section. The values will be populated into the `slapd.conf` file in the container. 

### LDAP Server List
In this section, up to 10 LDAP server entries can be added. All variables for each LDAP entry need to be tagged with an incrementing number postfix for denote their uniqueness across different server entries. Each customer account needs to be assigned with a short alphanumeric code that can be used to identify the account. 

Below is the proxy setting for a customer account `cobalt` that has 3 LDAP servers as its user base, one of which is a Windows AD server. 

```
LDAP_ACCOUNT_CODE_1=cobalt
LDAP_SERVER_HOSTNAME_1=tstbluepages.mkm.can.ibm.com
LDAP_SERVER_IP_1=9.23.210.79
LDAP_SERVER_PORT_1=636
LDAP_PROTOCOL_1=ldaps
LDAP_ANONYMOUS_BIND_1=yes
LDAP_USER_SEARCH_BASE_1=ou=bluepages,o=ibm.com
LDAP_USER_ATTRIBUTE_MAPPING_1_lastName=sn
LDAP_USER_ATTRIBUTE_MAPPING_1_firstName=givenName
LDAP_USER_ATTRIBUTE_MAPPING_1_email=emailAddress
LDAP_USER_ATTRIBUTE_MAPPING_1_mobileNumber=mobile
LDAP_USER_OBJECTCLASS_MAPPING_1_inetOrgPerson=person
LDAP_GROUP_SEARCH_BASE_1=ou=memberlist,ou=ibmgroups,o=ibm.com
LDAP_GROUP_ATTRIBUTE_MAPPING_1_member=uniquemember
LDAP_GROUP_OBJECTCLASS_MAPPING_1_groupOfNames=groupOfUniqueNames

LDAP_ACCOUNT_CODE_2=cobalt
LDAP_SERVER_HOSTNAME_2=bluepages.ibm.com
LDAP_SERVER_IP_2=9.57.182.78
LDAP_SERVER_PORT_2=636
LDAP_PROTOCOL_2=ldaps
LDAP_ANONYMOUS_BIND_2=no
LDAP_IDASSERT_BIND_DN_2=cn=fake_admin,ou=bluepages,o=ibm.com
LDAP_IDASSERT_BIND_PW_2=fake_admin_passwd
LDAP_REBIND_AS_USER_2=no
LDAP_USER_SEARCH_BASE_2=ou=bluepages,o=ibm.com
LDAP_USER_ATTRIBUTE_MAPPING_2_familyName=sn
LDAP_USER_OBJECTCLASS_MAPPING_2_inetOrgPerson=person
LDAP_GROUP_SEARCH_BASE_2=ou=memberlist,ou=ibmgroups,o=ibm.com
LDAP_GROUP_ATTRIBUTE_MAPPING_2_member=uniquemember
LDAP_GROUP_OBJECTCLASS_MAPPING_2_groupOfNames=groupOfUniqueNames

LDAP_ACCOUNT_CODE_3=cobalt
LDAP_SERVER_HOSTNAME_3=sla-bvt-ep-win1.sdad.sl.dst.ibm.com
LDAP_SERVER_IP_3=10.186.30.164
LDAP_SERVER_PORT_3=3268
LDAP_PROTOCOL_3=ldap
LDAP_ANONYMOUS_BIND_3=no
LDAP_IDASSERT_BIND_DN_3=CN=Administrator,CN=Users,DC=ad,DC=sla,DC=ibm,DC=com
LDAP_IDASSERT_BIND_PW_3=fake_admin_passwd
LDAP_REBIND_AS_USER_3=yes
LDAP_USER_SEARCH_BASE_3=dc=ad,dc=sla,dc=ibm,dc=com
LDAP_USER_ATTRIBUTE_MAPPING_3_lastName=sn
LDAP_USER_ATTRIBUTE_MAPPING_3_firstName=givenName
LDAP_USER_ATTRIBUTE_MAPPING_3_mail=userPrincipalName
LDAP_USER_ATTRIBUTE_MAPPING_3_uid=sAMAccountName
LDAP_USER_ATTRIBUTE_MAPPING_3_ibm-entryuuid=OBJECTGUID
LDAP_USER_OBJECTCLASS_MAPPING_3_inetOrgPerson=person
LDAP_GROUP_SEARCH_BASE_3=dc=ad,dc=sla,dc=ibm,dc=com
LDAP_GROUP_OBJECTCLASS_MAPPING_3_groupOfNames=group
```

* The port number of the Windows Active Directory needs to be set to 3268 (instead of 389) if the server is of LDAP nature, and 3269 (instead of 636) for LDAPS. This is to avoid referral chasing that might result in exceptions in some Java applications (e.g. IBM Websphere). 
* A globally unique attribute that can be used to universally identify an LDAP entry like OBJECTGUID needs to be mapped to ibm-entryuuid, so as to support integration with IBM Websphere. 

Below is an additional customer account named `rabbit`. 

```
LDAP_ACCOUNT_CODE_4=rabbit
LDAP_SERVER_HOSTNAME_4=sla-bvt-ep-win2.sdad.sl.dst.ibm.com
LDAP_SERVER_IP_4=9.51.160.204
LDAP_SERVER_PORT_4=3269
LDAP_PROTOCOL_4=ldaps
LDAP_ANONYMOUS_BIND_4=no
LDAP_IDASSERT_BIND_DN_4=CN=Administrator,CN=Users,DC=ad,DC=sla,DC=ibm,DC=com
LDAP_IDASSERT_BIND_PW_4=fake_admin_passwd
LDAP_REBIND_AS_USER_4=yes
LDAP_USER_SEARCH_BASE_4=dc=ad,dc=sla,dc=ibm,dc=com
LDAP_USER_ATTRIBUTE_MAPPING_4_lastName=sn
LDAP_USER_ATTRIBUTE_MAPPING_4_firstName=givenName
LDAP_USER_ATTRIBUTE_MAPPING_4_mail=userPrincipalName
LDAP_USER_ATTRIBUTE_MAPPING_4_uid=sAMAccountName
LDAP_USER_ATTRIBUTE_MAPPING_4_ibm-entryuuid=OBJECTGUID
LDAP_USER_OBJECTCLASS_MAPPING_4_inetOrgPerson=person
LDAP_GROUP_SEARCH_BASE_4=dc=ad,dc=sla,dc=ibm,dc=com
LDAP_GROUP_OBJECTCLASS_MAPPING_4_groupOfNames=group
```

Once the environment viriable file is properly configured, run `docker-compose up -d` to start the container. 
All secret value entries contained in the environment variable file are encrypted by running the `encrypt_env_vars.sh` script. The service container should be up to support the execution of this script. 

Automated deployment scripts like `init_openldap_proxy.sh` etc. are also included. They are used in CI/CD pipelines where a Docker Trusted Registry is available to host the images. 

## Test and Usage

The `ldapsearch` command line tool can be used to test the functionality of this openLDAP proxy. The search base needs to be constructed from the LDAP_SUFFIX value and the LDAP_ACCOUNT_CODE_<index> value if the search is going to be performed for a known customer account. Or else the LDAP_SUFFIX value is enough. 
For example, with below settings, 

LDAP_SUFFIX=dc=sla,dc=ibm,dc=com
LDAP_ACCOUNT_CODE_1=cobalt

valid LDAP search calls include `ldapsearch -h localhost -x -b "dc=cobalt,dc=sla,dc=ibm,dc=com" mail=-057mo897@tst.ibm.com` and `ldapsearch -h localhost -x -b "dc=sla,dc=ibm,dc=com" mail=-057mo897@tst.ibm.com`. 

The search base construction rule can be generalized as `dc=<value of LDAP_ACCOUNT_CODE_idx>,<value of LDAP_SUFFIX>`. 

The `verify_openldap_proxy.sh` script can be invoked for automated test and verification.

The openLDAP proxy is an openLDAP server in nature hence it can be integrated into applications in the same way for LDAP servers. There are readily avaialbe LDAP connector libraries for most of the common languages. 

## Contribution 
Fork the respository and raise pull requests for new changes. Report issues via Git. 

## Authors
* Ruifeng Ma (mrfflyer@gmail.com)
