#!/bin/bash

usage()
{
    echo "usage: $0 -i <instance name> [-v] [-h]"
}

VERBOSE=0
INSTANCE_NAME=""

while [ "$1" != "" ]; do
    case $1 in
        -i | --instance )       shift
                                INSTANCE_NAME=$1
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

if [ "$VERBOSE" = "1" ]; then
    echo "INSTANCE NAME: $INSTANCE_NAME";
fi

if [ "$INSTANCE_NAME" = "" ]; then
    usage
    exit 1
fi

COMMAND="ansible-playbook -i 'localhost,' -c local --extra-vars 'instance_name=$INSTANCE_NAME' create-sandbox-instance.yml" 
if [ "$VERBOSE" = "1" ]; then
    echo $COMMAND
fi
#$COMMAND # This doesn't work for some reason
ansible-playbook -i 'localhost,' -c local --extra-vars "instance_name=$INSTANCE_NAME" create-sandbox-instance.yml
