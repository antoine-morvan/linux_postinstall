#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh


mkdir -p /etc/apt/sources.list.d/
echo "deb http://download.virtualbox.org/virtualbox/debian $(lsb_release -sc) contrib" | tee /etc/apt/sources.list.d/virtualbox.list
wget -q -O- http://download.virtualbox.org/virtualbox/debian/oracle_vbox_2016.asc | sudo apt-key add -

upgrade

exit

