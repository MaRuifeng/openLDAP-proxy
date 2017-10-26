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
    ldap_port_key="LDAP_SERVER_PORT_$ix"
    ldap_port_value="${!ldap_port_key}"
    ldap_protocol_key="LDAP_PROTOCOL_$ix"
    ldap_protocol_value="${!ldap_protocol_key}"
    ldap_search_base_key="LDAP_SEARCH_BASE_$ix"
    ldap_search_base_value="${!ldap_search_base_key}"
    ldap_anonymous_bind_key="LDAP_ANONYMOUS_BIND_$ix"
    ldap_anonymous_bind_value="${!ldap_anonymous_bind_key}"
    ldap_idassert_bind_dn_key="LDAP_IDASSERT_BIND_DN_$ix"
    ldap_idassert_bind_dn_value="${!ldap_idassert_bind_dn_key}"
    ldap_idassert_bind_pw_key="LDAP_IDASSERT_BIND_PW_$ix"
    ldap_idassert_bind_pw_value="${!ldap_idassert_bind_pw_key}"
    ldap_rebind_as_user_key="LDAP_REBIND_AS_USER_$ix"
    ldap_rebind_as_user_value="${!ldap_rebind_as_user_key}"

    if [[ ! -z ${ldap_ip_value:+x} ]] && [[ ! -z ${ldap_protocol_value:+x} ]] && [[ ! -z ${ldap_search_base_value:+x} ]]; then
    	echo -e "\n${ldap_ip_value}    ${ldap_hostname_value}" >> /etc/hosts
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i uri \"${ldap_protocol_value}:\/\/${ldap_hostname_value}:${ldap_port_value}\/${LDAP_SUFFIX}\"" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i lastmod off" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i readonly yes" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i suffixmassage \"${LDAP_SUFFIX}\" \"${ldap_search_base_value}\"" slapd.conf
        if [[ ! -z ${ldap_anonymous_bind_value:+x} ]] && [[ "$ldap_anonymous_bind_value" = yes ]] &&\
            [[ ! -z ${ldap_idassert_bind_dn_value:+x} ]] && [[ ! -z ${ldap_idassert_bind_pw_value:+x} ]] &&\
            [[ ! -z ${ldap_rebind_as_user_value:+x} ]]; then
            ldap_idassert_bind_value="bindmethod=simple binddn=\"${ldap_idassert_bind_dn_value}\" credentials=\"${ldap_idassert_bind_pw_value}\" mode=none flags=non-prescriptive"
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-bind ${ldap_idassert_bind_value}" slapd.conf
            ldap_idassert_authzFrom_value="dn.exact:${ldap_idassert_bind_dn_value}"
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-authzFrom \"${ldap_idassert_authzFrom_value}\"" slapd.conf
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rebind-as-user ${ldap_rebind_as_user_value}" slapd.conf
        fi
        sed -i -r -e 's/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/\n&/g' slapd.conf  # new line
    fi
done

cp slapd.conf /etc/openldap/slapd.conf

echo -e "\nHOST bluepages.ibm.com\nPORT 636\nTLS_REQCERT ALLOW" >> /etc/openldap/ldap.conf
cd

# Run docker-compose command
exec "$@"

