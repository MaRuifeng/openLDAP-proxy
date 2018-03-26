#!/bin/bash -e

# This script verifies the functionality of the OpenLDAP Proxy container of SLA. 
#
# Pre-requisites
#   1) LDAP utility package has been installed on the test machine where this script is being run. 
#      The script will try to install them if not. Hence make sure the current user has sudo rights. 
#   2) The test machine needs to be able to access the openLDAP proxy server via port 636.
#   
# User will be prompted to enter below information from stdin
#   a. Account code (GCSC) - used to construct the search base
#   b. Sample group cn
#   c. Sample user Email
#   d. Hostname of the server where the openLDAP proxy container is deployed
# After that a series of ldapsearch calls will be made to verify whether the openLDAP proxy works as expected. 

# Author: ruifengm@sg.ibm.com
# Date: 2018-Mar-26

export LDAP_SUFFIX='dc=sla,dc=ibm,dc=com'

export RED_TXT_BEG='\033[0;31m'
export GREEN_TXT_BEG='\033[0;32m'
export BLUE_TXT_BEG='\033[0;36m'
export TXT_END='\033[0m'

# Check LDAP utility package installation (Fedora RHEL distribution assumed)
# sudo yum list installed | grep openldap-clients || sudo yum install -y openldap-clients 

# Obtain and validate user input
echo -e "${GREEN_TXT_BEG}#### Welcome to the openLDAP proxy verification process"'!'"####\nPlease enter below information.\nHit enter to leave empty if not applicable.${TXT_END}"
read -p 'Account code (GCSC): ' acct_code
read -p 'Sample group cn (e.g. sscm_requester): ' group_cn
read -p 'Sample user Email (e.g. tester@ibm.com): ' user_email
# while true; do
#     read -p "Does the user belong to the group?" yn
#     case $yn in
#         [Yy]* ) is_member=true; break;;
#         [Nn]* ) is_member=false; break;;
#         * ) echo "Please answer yes or no.";;
#     esac
# done
read -p 'Hostname of the openLDAP proxy server (e.g. sla-d-svm01-dal13.sdad.dst.sl.ibm.com): ' ldap_hostname

[[ -z "$acct_code" ]] && echo -e "${BLUE_TXT_BEG}No account code (GCSC) provided to format the serach base. Exiting now.${TXT_END}" && exit 0
[[ -z "$ldap_hostname" ]] && echo -e "${BLUE_TXT_BEG}No openLDAP proxy server hostname provided. Nothing to verify. Exiting now.${TXT_END}" && exit 0
[[ -z "$user_email" ]] && [[ -z "$group_cn" ]] && echo -e "${BLUE_TXT_BEG}Neither sample user email nor group cn provided. Nothing to search. Exiting now.${TXT_END}" && exit 0

# Check openLDAP proxy connection
sudo echo >/dev/tcp/"$ldap_hostname"/636 || (echo -e "${RED_TXT_BEG}No connection via port 636 to ${ldap_hostname} is available. Please check.${TXT_END}" && exit 1)

# Perform ldapsearch calls
search_base="dc=${acct_code},${LDAP_SUFFIX}"
#   Group search
group_search_failed=false
if [[ ! -z "$group_cn" ]]; then
    echo -e "${BLUE_TXT_BEG}Searching group ${group_cn}...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "cn=${group_cn}" | grep numEntries || group_search_failed=true
    
    echo -e "${BLUE_TXT_BEG}Searching group ${group_cn} with objectClass groupOfNames...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "(&(objectClass=groupOfNames)(cn=${group_cn}))" | grep numEntries || group_search_failed=true
    
    member=$(ldapsearch -h "$ldap_hostname" -x -b "$search_base" "cn=${group_cn}" | egrep '^member:.+' | awk '{print $2}' | head -n 1)
    echo -e "${BLUE_TXT_BEG}Searching group ${group_cn} with member ${member}...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "(&(objectClass=groupOfNames)(member=${member}))" | grep numEntries || group_search_failed=true
fi

#   User search
user_search_failed=false
if [[ ! -z "$user_email" ]]; then
    echo -e "${BLUE_TXT_BEG}Searching user ${user_email} with mail...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "mail=${user_email}" | grep numEntries || user_search_failed=true

    echo -e "${BLUE_TXT_BEG}Searching user ${user_email} with uid...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "uid=${user_email%%@*}" | grep numEntries || user_search_failed=true

    echo -e "${BLUE_TXT_BEG}Searching user ${user_email} with objectClass inetOrgPerson...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "$search_base" "(&(|(objectClass=inetOrgPerson))(|(uid=${user_email%%@*})(mail=${user_email})))" | grep numEntries || user_search_failed=true
    
    user_dn=$(ldapsearch -h "$ldap_hostname" -x -b "$search_base" "mail=${user_email}" | egrep '^dn:.+' | awk '{print $2}' | head -n 1 )
    echo -e "${BLUE_TXT_BEG}Searching user ${user_email} with user dn ${user_dn} as search base...${TXT_END}"
    ldapsearch -h "$ldap_hostname" -x -b "${user_dn}" "(objectClass=*)" | grep numEntries || user_search_failed=true
fi

if [[ "$group_search_failed" == true ]]; then
    echo -e "${RED_TXT_BEG}Failure(s) found for group search. Check if openLDAP proxy settings are correct.${TXT_END}"
elif [[ "$user_search_failed" == true ]]; then
    echo -e "${RED_TXT_BEG}Failure(s) found for user search. Check if openLDAP proxy settings are correct.${TXT_END}"
else
    echo -e "${BLUE_TXT_BEG}Verification completed successfully.${TXT_END}"
fi
