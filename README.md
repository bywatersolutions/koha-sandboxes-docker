# This project has moved to the official [Koha Community GitLab](https://gitlab.com/koha-community/koha-sandboxes-docker)!

This GitHub repo is archived and will no longer be actively maintained. It will remove here for posterity and to preserve existing hyperlinks.

# Koha Sandbox Server

The Koha Sandbox Server is a system to allow easy testing of Koha patches and git branches.

It is powered by Docker, Ansible and Perl.
It uses [koha-testing-docker](https://gitlab.com/koha-community/koha-testing-docker) to create each Koha sandbox.

## Installation

Starting with a Debian 9 system:
* Install the latest release of Ansible
* Become root user
* Clone this repository
* cd to the git clone
* Copy ansible/vars/user.yml.example to ansible/vars/user.yml
* Update ansible/vars/user.yml for your domain and account
* Run ./setup-sandbox-server.sh
* Browse to the domain you entered as SANDBOX_HOST_DOMAIN in your user.yml

## Features
* Create and destroy Koha instances dyanmically
* Web-based viewing of logs
* Ability to sign off bugs from web
* Apply Koha bugs by community bug number
* Test Koha branches from arbitrary git repositories
* Restart Koha services ( koha-common, apache, memached ) from the web
* Re-index Zebra from the web
* Delete the database and start fresh without reprovisioning from the web

## Future Goals
* Add ability to run specific unit tests from web
* Add ability to select a pre-generated database list ( also we need to generate those databases )
* ~Allow ssh to koha containers, either through web or cli~
* Dockerize such that sandbox host needs only Docker. Ansible, the web app, and the daemon will run from a container and steer the host Docker daemon via Ansible.

## Guide

### Using a htpasswd

Using a password should be set before provisioning.
Otherwise you'll need to reprovision after following the instructions below.
* `sudo apt-get install apache2-utils`
* `sudo htpasswd -c /etc/apache2/.htpasswd <username>`
* Edit ansible/vars/user.yml, set USE_HTPASSWD to true
