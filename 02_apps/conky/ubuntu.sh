#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#setup application

echo ""
echo "** Setup Conky"
echo ""

upgrade
install_packs lvm2 conky-all

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/conky_config.sh
