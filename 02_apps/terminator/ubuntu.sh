#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

upgrade
install_packs terminator


retry "wget -q -O /etc/skel/.config/terminator/config ${SETUP_SCRIPT_LOCATION}/02_apps/terminator/config"

exit 0
