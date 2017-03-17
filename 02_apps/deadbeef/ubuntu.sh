#!/bin/bash

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#add-apt-repository -y ppa:starws-box/deadbeef-player
#upgrade
#install_packs deadbeef

VERSION=0.7.2-2

ARCH=i386
[ `uname -m` == x86_64 ] && ARCH=amd64
wget https://downloads.sourceforge.net/project/deadbeef/debian/deadbeef-static_${VERSION}_${ARCH}.deb -O /tmp/deadbeef-static_${VERSION}_${ARCH}.deb
dkpg -i /tmp/deadbeef-static_${VERSION}_${ARCH}.deb
rm /tmp/deadbeef-static_${VERSION}_${ARCH}.deb


mkdir -p /etc/skel/.config/deadbeef/
retry "wget -q -O /etc/skel/.config/deadbeef/config ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/config"

#add file browser plugin
#wget ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/ddb_misc_filebrowser_GTK2.so -O /usr/lib/deadbeef/ddb_misc_filebrowser_GTK2.so


exit

