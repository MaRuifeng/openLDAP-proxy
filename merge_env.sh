#!/bin/bash

# This script will merge the settings from existing COMPONENT.env and .env
# files into new ones

# mitchelb@us.ibm.com

TOPDIR=$(dirname $0)
cd $TOPDIR && TOPDIR=$PWD

DESTMP="$TOPDIR/tmp"

BKUP="_$(date '+%Y%m%d%H%M%S')"

ops='c:'
long_ops='component:'
declare COMPONENT='false'

USAGE="\n\033[0;36mUsage:\n$0 [-c xxxxx]\n$0 [--component xxxxx]\033[0m\n"
OPTIONS=$(getopt --options ${ops} --longoptions ${long_ops} --name "$0" -- "$@")
[[ $? != 0 ]] && exit 3

eval set -- "${OPTIONS}"
while true
do
    case "${1}" in
        -c|--component)
            COMPONENT="$2"
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

[[ "${COMPONENT}" == '' ]] && echo -e "\033[0;31mError: no component specified! Check script usage.\033[0m\n$USAGE" && exit 1

if [[ ! -f ./dot_env_template || ! -f ./${COMPONENT}.env_template ]]
then
	echo -e "\n\nTemplate files are missing!!"
	echo -e "You must have both ./dot_env_template and ./${COMPONENT}.env_template"
	echo -e "in order to merge the variables"
	exit
fi

# Handy way to "source" ${COMPONENT}.env
# set -a
# eval $(grep -v '^#\|^\s*$' ${COMPONENT}.env | awk -F= '{printf "%s=\"%s\"\n",$1, $2}')
# set +a

# Process any deletions first
grep '^DELETE:' ./${COMPONENT}.env_template |
while read LINE
do
	VARIABLE=${LINE#DELETE:}
	VARIABLE=${VARIABLE%%=*}
	echo "Deleting $VARIABLE from ${COMPONENT}.env"
	sed -i'' "/$VARIABLE/d" ./${COMPONENT}.env
done
# Now delete the directives from the template
sed -i'' '/^DELETE:'/d ./${COMPONENT}.env_template

# Merge variables from old ${COMPONENT}.env to new one
while read LINE
do
	case $LINE in
		''|\#*) continue ;;
	esac

	VARIABLE=${LINE%%=*}
	VALUE=${LINE#*=}

	if [[ ! -z $VALUE ]]
	then
		echo "Merging ${VARIABLE}=$VALUE"
		VALUE=$(perl -e "print quotemeta('$VALUE')")
		#echo "Quoted VALUE = $VALUE"
		# replace variables that are unset and commented out in the template
		# Adding regex to deal with poorly maintained ${COMPONENT}.env_template
		# where some editors have put spaces between # and the variable
		perl -p -i -e "s/#.*(${VARIABLE}=).*/\${1}${VALUE}/g;" ./${COMPONENT}.env_template
		# replace active defaults in the template that may have been changed in production
		# yes, this means we re-replace the ones we just did but who's counting ;^)
		perl -p -i -e "s/(${VARIABLE}=).*/\${1}${VALUE}/g;" ./${COMPONENT}.env_template
	fi

done < <(cat ${COMPONENT}.env)

# Merge variables from old .env to new one
while read LINE
do
	case $LINE in
		''|\#*) continue ;;
	esac

	VARIABLE=${LINE%%=*}
	VALUE=${LINE##*=}

	if [[ ! -z $VALUE ]]
	then
		echo "Merging ${VARIABLE}=$VALUE"
		VALUE=$(perl -e "print quotemeta('$VALUE')")
		perl -p -i -e "s/(${VARIABLE}=).*/\${1}${VALUE}/g;" ./dot_env_template
	fi

done < <(cat .env)

echo "Saving original environment files to $DESTMP"
mv ${COMPONENT}.env $DESTMP/${COMPONENT}.env${BKUP}
mv .env $DESTMP/.env${BKUP}

echo "Replacing environment files"
mv ${COMPONENT}.env_template ${COMPONENT}.env
mv dot_env_template .env
