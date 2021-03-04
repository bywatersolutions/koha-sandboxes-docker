#!/bin/bash
ansible-playbook -i "localhost," -c local ansible/setup-sandbox-server.yml -v -e 'ansible_python_interpreter=/usr/bin/python3.7'
