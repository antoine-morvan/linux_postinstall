#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#install dep
apt-get -y install libpango1.0-0 libpangox-1.0-0

VERSION=0.7.2-2

ARCH=i386
[ `uname -m` == x86_64 ] && ARCH=amd64
wget https://downloads.sourceforge.net/project/deadbeef/debian/deadbeef-static_${VERSION}_${ARCH}.deb -O /tmp/deadbeef-static_${VERSION}_${ARCH}.deb
dpkg -i /tmp/deadbeef-static_${VERSION}_${ARCH}.deb
rm /tmp/deadbeef-static_${VERSION}_${ARCH}.deb

#filebrowser plugin
wget https://downloads.sourceforge.net/project/deadbeef/plugins/`uname -m`/ddb_filebrowser-1562809-`uname -m`.zip -O /tmp/ddb_filebrowser-1562809-`uname -m`.zip
unzip -x /tmp/ddb_filebrowser-1562809-x86_64.zip -d /tmp/filebrowser/
mv /tmp/filebrowser/plugins/ddb_misc_filebrowser_GTK2.so /opt/deadbeef/lib/deadbeef/
rm -rf /tmp/ddb_filebrowser-1562809-x86_64.zip /tmp/filebrowser/


mkdir -p /etc/skel/.config/deadbeef/
retry "wget -q -O /etc/skel/.config/deadbeef/config ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/config"

#add file browser plugin
#wget ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/ddb_misc_filebrowser_GTK2.so -O /usr/lib/deadbeef/ddb_misc_filebrowser_GTK2.so


exit

