#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#setup application deps
apt-get -y install python python-gtk2 python-xlib python-dbus python-wnck python-setuptools git libpango1.0-0 python-pip

# used https://pkgs.org to find python-wnck
wget http://ftp.br.debian.org/debian/pool/main/g/gnome-python-desktop/python-wnck_2.32.0+dfsg-3_amd64.deb
sudo dpkg -i python-wnck_2.32.0+dfsg-3_amd64.deb 
sudo -H pip2 install https://github.com/ssokolow/quicktile/archive/master.zip

#add default config
mkdir -p /etc/skel/.config/
retry "wget -q -O /etc/skel/.config/quicktile.cfg ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/quicktile.cfg"
