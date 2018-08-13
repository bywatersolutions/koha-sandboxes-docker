#!/bin/bash
ansible-playbook -i "localhost," -c local ansible/setup-sandbox-server.yml -v
