#!/bin/bash -eu

#https://launchpad.net/~unit193/+archive/ubuntu/encryption

add-apt-repository -y ppa:unit193/encryption
apt-get update
apt-get -y upgrade
apt-get -y install veracrypt

exit 0

