#!/bin/bash -e

# Secret value encryption/decryption via openssl. 

# Author: ruifengm@sg.ibm.com
# Date: 2017-Oct-25


CUR_DIR=$(dirname $0)
cd "${CUR_DIR}" && CUR_DIR=$PWD

ops='e,d,v:'
long_ops='encrypt,decrypt,value:'
declare DECRYPT='false'
declare ENCRYPT='false'
declare VALUE=''

USAGE="\n\033[0;36mUsage: \n$0 [-d/-e] [-v input_value]\nor\n$0 [--decrypt/--encrypt] [--value input_value]\033[0m\n"
OPTIONS=$(getopt --options ${ops} --longoptions ${long_ops} --name "$0" -- "$@")
[[ $? != 0 ]] && exit 3
[[ "$#" -ne 3 ]] && echo -e "\nWrong number of arguments!" && echo -e "${USAGE}" && exit 3

eval set -- "${OPTIONS}"
while true
do
    case "${1}" in
        -d|--decrypt)
            DECRYPT='true'
            shift
            ;;
        -e|--encrypt)
            ENCRYPT='true'
            shift
            ;;
        -v|--value)
            VALUE="$2"
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

[[ "${VALUE}" == '' ]] && (echo -e "\033[0;31mError: no value given! Check script usage.\033[0m\n${USAGE}" && exit 1)

KEY="${DOCKER_HOST_FQDN}${DOCKER_HOST_MAC}"

if [[ "${ENCRYPT}" == 'true' ]]; then
    # use a named pipe that is immediately closed after the value is read
    # try to decrypt the value first in case it has been encrypted by this service script before
    VALUE_TO_ENCRYPT=$(openssl aes-128-ecb -base64 -A -nosalt -k "${KEY}" -d -in <(echo -n "$VALUE") 2>&1) || VALUE_TO_ENCRYPT="${VALUE}"
    openssl aes-128-ecb -base64 -A -nosalt -k "${KEY}" -e -in <(echo -n "${VALUE_TO_ENCRYPT}")
fi

if [[ "${DECRYPT}" == 'true' ]]; then
    openssl aes-128-ecb -base64 -A -nosalt -k "${KEY}" -d -in <(echo -n "${VALUE}") || echo -n "${VALUE}"
fi


