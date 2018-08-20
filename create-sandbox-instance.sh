#!/bin/bash

usage()
{
    echo "usage: $0 -f /path/to/env/file.yml [-v] [-h]"
}

VERBOSE=0
ENV_FILE=""

while [ "$1" != "" ]; do
    case $1 in
        -f | --file )           shift
                                ENV_FILE=$1
                                ;;
        -v | --verbose )        VERBOSE=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

ENV_FILE=`realpath $ENV_FILE`

if [ "$VERBOSE" = "1" ]; then
    echo "ENV FILE: $ENV_FILE";
fi

if [ "$ENV_FILE" = "" ]; then
    usage
    exit 1
fi

COMMAND="ansible-playbook -i 'localhost,' -c local --extra-vars 'env_file=$ENV_FILE' ansible/create-sandbox-instance.yml" 
if [ "$VERBOSE" = "1" ]; then
    echo $COMMAND
fi
#$COMMAND # This doesn't work for some reason
ansible-playbook -i 'localhost,' -c local --extra-vars "env_file=$ENV_FILE" ansible/create-sandbox-instance.yml
