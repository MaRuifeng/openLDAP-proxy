#!/bin/bash

# Entrypoint script of the openLDAP proxy container

# Author:
#  Ke Pi <kepi@sg.ibm.com>  Ruifeng Ma <ruifengm@sg.ibm.com>
# Date:
#  2017-Oct-26

function escape_for_sed() {
    local value=${1//\\/\\\\} # escape all backslashes (ALWAYS FIRST)
    local value=${value//\//\\\/} # escape all slashes
    local value=${value//\*/\\*} # escape all asterisks
    local value=${value//\./\\.} # escape all full stops
    local value=${value//\[/\\[} # escape all left square brackets
    local value=${value//\]/\\]} # escape all right square brackets
    local value=${value//\^/\\^} # escape all ^
    local value=${value//\$/\\\$} # escape all $
    local value=${value//\&/\\\&} # escape all &

    echo $value
}

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
rm -rf slapd.conf
cp slapd.conf_template slapd.conf

sed -i -r -e "s/^[^#]*suffix\s+\".*\"/suffix \"${LDAP_SUFFIX}\"/g" slapd.conf
sed -i -r -e "s/^[^#]*rootdn\s+\".*\"/rootdn \"${LDAP_ROOT_DN}\"/g" slapd.conf
ldap_root_pw_decrypted=$(/root/secret.sh -d -v "${LDAP_ROOT_PW}")
ldap_root_pw_decrypted_escaped=$(escape_for_sed "${ldap_root_pw_decrypted}")
sed -i -r -e "s/^[^#]*rootpw\s+\".*\"/rootpw \"${ldap_root_pw_decrypted_escaped}\"/g" slapd.conf

# Add overall re-write overlay for DN and DN-syntax attribute values
# sed -i -r -e "/#+\s+LDAP_REWRITE_OVERLAY\s+END\s+#+/ i overlay rwm" slapd.conf
# sed -i -r -e "/#+\s+LDAP_REWRITE_OVERLAY\s+END\s+#+/ i rwm-rewriteEngine on" slapd.conf 
# sed -i -r -e "/#+\s+LDAP_REWRITE_OVERLAY\s+END\s+#+/ i rwm-rewriteContext searchAttrDN" slapd.conf 

# Add access control
sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+START\s+#+/ i access to dn.regex=".*,${LDAP_SUFFIX}" attrs=entry,children,uid,mail,sn,givenName,cn,member by * read" slapd.conf

# LDAP server list
for ix in {1..50}
do
	ldap_account_code_key="LDAP_ACCOUNT_CODE_$ix"
	ldap_account_code_value="${!ldap_account_code_key}"
	ldap_suffix_massaged="dc=${ldap_account_code_value},${LDAP_SUFFIX}"
    ldap_hostname_key="LDAP_SERVER_HOSTNAME_$ix"
    ldap_hostname_value="${!ldap_hostname_key}"
    ldap_ip_key="LDAP_SERVER_IP_$ix"
    ldap_ip_value="${!ldap_ip_key}"
    ldap_port_key="LDAP_SERVER_PORT_$ix"
    ldap_port_value="${!ldap_port_key}"
    ldap_protocol_key="LDAP_PROTOCOL_$ix"
    ldap_protocol_value="${!ldap_protocol_key}"
    ldap_user_search_base_key="LDAP_USER_SEARCH_BASE_$ix"
    ldap_user_search_base_value="${!ldap_user_search_base_key}"
    ldap_group_search_base_key="LDAP_GROUP_SEARCH_BASE_$ix"
    ldap_group_search_base_value="${!ldap_group_search_base_key}"
    ldap_anonymous_bind_key="LDAP_ANONYMOUS_BIND_$ix"
    ldap_anonymous_bind_value="${!ldap_anonymous_bind_key}"
    ldap_idassert_bind_dn_key="LDAP_IDASSERT_BIND_DN_$ix"
    ldap_idassert_bind_dn_value="${!ldap_idassert_bind_dn_key}"
    ldap_idassert_bind_pw_key="LDAP_IDASSERT_BIND_PW_$ix"
    ldap_idassert_bind_pw_value="${!ldap_idassert_bind_pw_key}"
    ldap_idassert_bind_pw_value_decrypted=$(/root/secret.sh -d -v "${ldap_idassert_bind_pw_value}")
    ldap_idassert_bind_pw_value_decrypted_escaped=$(escape_for_sed "${ldap_idassert_bind_pw_value_decrypted}")
    ldap_rebind_as_user_key="LDAP_REBIND_AS_USER_$ix"
    ldap_rebind_as_user_value="${!ldap_rebind_as_user_key}"

    if [[ ! -z ${ldap_ip_value:+x} ]] && [[ ! -z ${ldap_protocol_value:+x} ]] && [[ ! -z ${ldap_user_search_base_value:+x} ]]; then
    	echo -e "\n${ldap_ip_value}    ${ldap_hostname_value}" >> /etc/hosts
        ## ----- USER Config (Start) ----- ##
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i uri \"${ldap_protocol_value}:\/\/${ldap_hostname_value}:${ldap_port_value}\/${ldap_suffix_massaged}\"" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i lastmod off" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i readonly yes" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i suffixmassage \"${ldap_suffix_massaged}\" \"${ldap_user_search_base_value}\"" slapd.conf
        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i chase-referrals YES" slapd.conf
        if [[ ! -z ${ldap_anonymous_bind_value:+x} ]] && [[ "$ldap_anonymous_bind_value" = no ]] &&\
            [[ ! -z ${ldap_idassert_bind_dn_value:+x} ]] && [[ ! -z ${ldap_idassert_bind_pw_value_decrypted_escaped:+x} ]] &&\
            [[ ! -z ${ldap_rebind_as_user_value:+x} ]]; then
            # ldap_idassert_bind_value="bindmethod=simple binddn=\"${ldap_idassert_bind_dn_value}\" credentials=\"${ldap_idassert_bind_pw_value_decrypted_escaped}\" mode=none flags=non-prescriptive"
            ldap_idassert_bind_value="bindmethod=simple binddn=\"${ldap_idassert_bind_dn_value}\" credentials=\"${ldap_idassert_bind_pw_value_decrypted_escaped}\" mode=none"
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-bind ${ldap_idassert_bind_value}" slapd.conf
            # ldap_idassert_authzFrom_value="dn.exact:${ldap_idassert_bind_dn_value}"
            ldap_idassert_authzFrom_value="dn.regex:.*"
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-authzFrom \"${ldap_idassert_authzFrom_value}\"" slapd.conf
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rebind-as-user ${ldap_rebind_as_user_value}" slapd.conf
        fi
        # LDAP user attribute mapping
        while IFS='' read -r line || [[ -n "$line" ]]; do
            var_key=${line%%=*}
            ldap_attr_name=${var_key#LDAP_USER_ATTRIBUTE_MAPPING_${ix}_}
            ldap_attr_value=${line#*=}
            ldap_attr_value_escaped=$(escape_for_sed "${ldap_attr_value}")
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i map attribute ${ldap_attr_name} ${ldap_attr_value_escaped}" slapd.conf
        done < <(env | grep LDAP_USER_ATTRIBUTE_MAPPING_${ix}_)
        # LDAP user objectClass mapping
        while IFS='' read -r line || [[ -n "$line" ]]; do
            var_key=${line%%=*}
            ldap_objclass_name=${var_key#LDAP_USER_OBJECTCLASS_MAPPING_${ix}_}
            ldap_objclass_value=${line#*=}
            ldap_objclass_value_escaped=$(escape_for_sed "${ldap_objclass_value}")
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i map objectClass ${ldap_objclass_name} ${ldap_objclass_value_escaped}" slapd.conf
        done < <(env | grep LDAP_USER_OBJECTCLASS_MAPPING_${ix}_)
        ## ----- USER Config (End) ----- ##

        ## ----- GROUP Config (Start) ----- ##
        if [[ ! -z ${ldap_group_search_base_value:+x} ]]; then
        	if [[ "${ldap_group_search_base_value}" != "${ldap_user_search_base_value}" ]]; then
        		sed -i -r -e 's/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/\n&/g' slapd.conf  # new line
	        	sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i uri \"${ldap_protocol_value}:\/\/${ldap_hostname_value}:${ldap_port_value}\/${ldap_suffix_massaged}\"" slapd.conf
	            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i lastmod off" slapd.conf
	            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i readonly yes" slapd.conf
	            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i suffixmassage \"${ldap_suffix_massaged}\" \"${ldap_group_search_base_value}\"" slapd.conf
		        sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i chase-referrals YES" slapd.conf
                if [[ ! -z ${ldap_anonymous_bind_value:+x} ]] && [[ "$ldap_anonymous_bind_value" = no ]] &&\
		            [[ ! -z ${ldap_idassert_bind_dn_value:+x} ]] && [[ ! -z ${ldap_idassert_bind_pw_value_decrypted_escaped:+x} ]] &&\
		            [[ ! -z ${ldap_rebind_as_user_value:+x} ]]; then
		            # ldap_idassert_bind_value="bindmethod=simple binddn=\"${ldap_idassert_bind_dn_value}\" credentials=\"${ldap_idassert_bind_pw_value_decrypted_escaped}\" mode=none flags=non-prescriptive"
		            ldap_idassert_bind_value="bindmethod=simple binddn=\"${ldap_idassert_bind_dn_value}\" credentials=\"${ldap_idassert_bind_pw_value_decrypted_escaped}\" mode=none"
		            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-bind ${ldap_idassert_bind_value}" slapd.conf
		            # ldap_idassert_authzFrom_value="dn.exact:${ldap_idassert_bind_dn_value}"
		            ldap_idassert_authzFrom_value="dn.regex:.*"
		            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i idassert-authzFrom \"${ldap_idassert_authzFrom_value}\"" slapd.conf
		            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rebind-as-user ${ldap_rebind_as_user_value}" slapd.conf
		        fi
        	fi
            # LDAP group attribute mapping
            while IFS='' read -r line || [[ -n "$line" ]]; do
                var_key=${line%%=*}
                ldap_attr_name=${var_key#LDAP_GROUP_ATTRIBUTE_MAPPING_${ix}_}
                ldap_attr_value=${line#*=}
                ldap_attr_value_escaped=$(escape_for_sed "${ldap_attr_value}")
                sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i map attribute ${ldap_attr_name} ${ldap_attr_value_escaped}" slapd.conf
            done < <(env | grep LDAP_GROUP_ATTRIBUTE_MAPPING_${ix}_)
            # LDAP group objectClass mapping
            while IFS='' read -r line || [[ -n "$line" ]]; do
                var_key=${line%%=*}
                ldap_objclass_name=${var_key#LDAP_GROUP_OBJECTCLASS_MAPPING_${ix}_}
                ldap_objclass_value=${line#*=}
                ldap_objclass_value_escaped=$(escape_for_sed "${ldap_objclass_value}")
                sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i map objectClass ${ldap_objclass_name} ${ldap_objclass_value_escaped}" slapd.conf
            done < <(env | grep LDAP_GROUP_OBJECTCLASS_MAPPING_${ix}_)
            # LDAP group re-write rules
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rewriteEngine on" slapd.conf
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rewriteContext searchFilterAttrDN" slapd.conf
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rewriteRule \"(.*)${ldap_suffix_massaged}(.*)\" \"%1${ldap_user_search_base_value}%2\" \":\"" slapd.conf # Enables group search via customized user dn 
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rewriteContext searchResult" slapd.conf
            sed -i -r -e "/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/ i rewriteRule \"(.*)${ldap_user_search_base_value}(.*)\" \"%1${ldap_suffix_massaged}%2\" \":\"" slapd.conf
            sed -i -r -e 's/#+\s+LDAP_SERVER_ENTRY\s+END\s+#+/\n&/g' slapd.conf  # new line
            # Overall re-write rules for LDAP group
            # sed -i -r -e "/#+\s+LDAP_REWRITE_OVERLAY\s+END\s+#+/ i rwm-rewriteRule \"(.*)${ldap_group_search_base_value}(.*)\" \"\$1${LDAP_SUFFIX}\$2\" \":\"" slapd.conf
        fi
        ## ----- GROUP Config (End) ----- ##
    fi
done


# sed -i -r -e "/#+\s+LDAP_ATTRIBUTE_OBJECTCLASS_MAPPING\s+END\s+#+/ i overlay rwm" slapd.conf
# while IFS='' read -r line || [[ -n "$line" ]]; do
#     var_key=${line%%=*}
#     ldap_objclass_name=${var_key#LDAP_OBJECTCLASS_MAPPING_}
#     ldap_objclass_value=${line#*=}
#     if [[ ${ldap_objclass_value} =~ .*,.* ]]; then
#         IFS=',' read -ra objclass_value_array <<< "${ldap_objclass_value}" # change IFS for single command only
#         i=1
#         for val in ${objclass_value_array[@]}
#         do
#             if [[ val != '' ]]; then
#                 val_escaped=$(escape_for_sed "${val}")
#                 [[ $i -gt 1 ]] && sed -i -r -e "/#+\s+LDAP_ATTRIBUTE_OBJECTCLASS_MAPPING\s+END\s+#+/ i overlay rwm" slapd.conf
#                 sed -i -r -e "/#+\s+LDAP_ATTRIBUTE_OBJECTCLASS_MAPPING\s+END\s+#+/ i rwm-map objectClass ${ldap_objclass_name} ${val_escaped}" slapd.conf
#                 i=$(( i+1 ))
#             fi
#         done
#     else
#         ldap_objclass_value_escaped=$(escape_for_sed "${ldap_objclass_value}")
#         sed -i -r -e "/#+\s+LDAP_ATTRIBUTE_OBJECTCLASS_MAPPING\s+END\s+#+/ i rwm-map objectClass ${ldap_objclass_name} ${ldap_objclass_value_escaped}" slapd.conf
#     fi
# done < <(env | grep LDAP_OBJECTCLASS_MAPPING)
# sed -i -r -e 's/#+\s+LDAP_ATTRIBUTE_OBJECTCLASS_MAPPING\s+END\s+#+/\n&/g' slapd.conf  # new line

cp slapd.conf /etc/openldap/slapd.conf

# echo -e "\nHOST bluepages.ibm.com\nPORT 636\nTLS_REQCERT ALLOW" >> /etc/openldap/ldap.conf
cd

# Run docker-compose command
exec "$@"

