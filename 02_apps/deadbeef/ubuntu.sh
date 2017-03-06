#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh



add-apt-repository -y ppa:starws-box/deadbeef-player
upgrade
install_packs deadbeef

mkdir -p /etc/skel/.config/deadbeef/


wget ${SETUP_SCRIPT_LOCATION}/ddb_misc_filebrowser_GTK2.so -O /usr/lib/deadbeef/ddb_misc_filebrowser_GTK2.so



exit

