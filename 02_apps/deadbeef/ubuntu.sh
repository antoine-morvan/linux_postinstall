#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh





add-apt-repository ppa:alex-p/deadbeef

upgrade


#install dep
apt-get -y deadbeef

mkdir -p /etc/skel/.config/deadbeef/
retry "wget -q -O /etc/skel/.config/deadbeef/config ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/config"



exit

#filebrowser plugin -> broken
wget https://downloads.sourceforge.net/project/deadbeef/plugins/x86_64/ddb_filebrowser-355e614-linux-x86_64.zip -O /tmp/ddb_filebrowser.zip
unzip -x /tmp/ddb_filebrowser.zip -d /tmp/filebrowser/
mv /tmp/filebrowser/plugins/*.so /usr/lib/x86_64-linux-gnu/deadbeef/
rm -rf /tmp/ddb_filebrowser.zip /tmp/filebrowser/


#add file browser plugin
#wget ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/ddb_misc_filebrowser_GTK2.so -O /usr/lib/deadbeef/ddb_misc_filebrowser_GTK2.so


exit

