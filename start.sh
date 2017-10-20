#!/bin/bash

TOPDIR=$(dirname $0)
cd $TOPDIR && TOPDIR=$PWD

# Generate certificates if not existing
DESTDIR="$TOPDIR/data/certs"
APP_FQDN=$(hostname -f)

[[ -d $DESTDIR ]] || mkdir -p $DESTDIR

APP_GEN_CERT='openssl req -x509 -nodes -days 365 -newkey rsa:2048'
APP_GEN_CERT="$APP_GEN_CERT -keyout $DESTDIR/ldap.key -out $DESTDIR/ldap.crt"
APP_GEN_CERT="$APP_GEN_CERT -subj '/CN=$APP_FQDN/OU=SDAD/O=IBM/L=Austin/ST=TX/C=US'"
APP_GEN_CERT="[[ -f $DESTDIR/ldap.crt ]] || $APP_GEN_CERT"

eval $APP_GEN_CERT

# Update the slapd.conf file
cd /root/openldap_proxy/tmp

sed -i -r -e "s/^[^#]*suffix\s+\".*\"/suffix \"${LDAP_SUFFIX}\"/g" slapd.conf
sed -i -r -e "s/^[^#]*rootdn\s+\".*\"/rootdn \"${LDAP_ROOT_DN}\"/g" slapd.conf
sed -i -r -e "s/^[^#]*rootpw\s+\".*\"/rootpw \"${LDAP_ROOT_PW}\"/g" slapd.conf

for ix in {1..10}
do
	ldap_hostname_key="LDAP_SERVER_HOSTNAME_$ix"
    ldap_hostname_value="${!ldap_hostname_key}"
    ldap_ip_key="LDAP_SERVER_IP_$ix"
    ldap_ip_value="${!ldap_ip_key}"
    ldap_protocol_key="LDAP_PROTOCOL_$ix"
    ldap_protocol_value="${!ldap_protocol_key}"
    ldap_search_base_key="LDAP_SEARCH_BASE_$ix"
    ldap_search_base_value="${!ldap_search_base_key}"
    # sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i uri ${ldap_hostname_value} /" slapd.conf
    if [[ ! -z ${ldap_ip_value:+x} ]] && [[ ! -z ${ldap_protocol_value:+x} ]] && [[ ! -z ${ldap_search_base_value:+x} ]]; then
    	sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i uri \"${ldap_protocol_value}:\/\/${ldap_ip_value}\/${LDAP_SUFFIX}\"" slapd.conf
	    sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i lastmod off" slapd.conf
	    sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i suffixmassage \"${LDAP_SUFFIX}\" \"${ldap_search_base_value}\"" slapd.conf
	    sed -i -r -e 's/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/\n&/g' slapd.conf  # new line
    fi
done

cp slapd.conf /etc/openldap/slapd.conf
cd

# Run docker-compose command
exec "$@"

