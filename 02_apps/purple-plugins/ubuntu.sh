#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh


mkdir -o /etc/apt/sources.list.d/
echo "deb http://download.opensuse.org/repositories/home:/jgeboski/xUbuntu_16.04 ./" > /etc/apt/sources.list.d/jgeboski.list
wget -O- https://jgeboski.github.io/obs.key | apt-key add -

upgrade
install_packs purple-facebook

exit

