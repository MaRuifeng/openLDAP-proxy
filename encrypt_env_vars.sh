#!/bin/bash -e

# Encrypt secret values stored in the environment variable file

# Author:
#  Ruifeng Ma <ruifengm@sg.ibm.com>
# Date:
#  2017-Oct-26

CUR_DIR=$(dirname $0)
cd $CUR_DIR && CUR_DIR=$PWD

# echo "Encrypting variable LDAP_ROOT_PW..."
# ldap_root_pw_encrypted=$(docker exec sla_openldap_proxy bash -l -c "/root/secret.sh -e -v \$LDAP_ROOT_PW")
# sed -i -e "s/.*LDAP_ROOT_PW=.*/LDAP_ROOT_PW=${ldap_root_pw_encrypted}/g" sla_openldap_proxy.env

while IFS='' read -r line || [[ -n "$line" ]]; do
    key_value_pair="${line}"
    var_key=${key_value_pair%%=*}
    var_value=${key_value_pair#*=}
    echo "Encrypting variable $var_key ..."
    var_value_transformed=${var_value//\'/\'\"\'\"\'} # replace ' with '"'"'
    var_value_encrypted=$(docker exec sla_openldap_proxy bash -l -c "/root/secret.sh -e -v '$var_value_transformed'")

    # sanitizing the variable value for sed
    var_value_encrypted_escaped=${var_value_encrypted//\\/\\\\} # escape all backslashes (ALWAYS FIRST)
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\//\\\/} # escape all slashes
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\*/\\*} # escape all asterisks
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\./\\.} # escape all full stops
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\[/\\[} # escape all left square brackets
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\]/\\]} # escape all right square brackets
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\^/\\^} # escape all ^
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\$/\\\$} # escape all $
    var_value_encrypted_escaped=${var_value_encrypted_escaped//\&/\\\&} # escape all &

    sed -i -e "s/.*${var_key}=.*/${var_key}=${var_value_encrypted_escaped}/g" sla_openldap_proxy.env
done < <(grep -Po '^[[:space:]]*(LDAP_IDASSERT_BIND_PW.*|LDAP_ROOT_PW)=.+' ${CUR_DIR}"/sla_openldap_proxy.env")

echo -e "Completed encrypting secret values in the environment variable file."

