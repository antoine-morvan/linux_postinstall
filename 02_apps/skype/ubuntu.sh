#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh


mkdir -p /etc/apt/sources.list.d/
echo "deb [arch=amd64] https://repo.skype.com/deb stable main" > /etc/apt/sources.list.d/skype.list
wget -q -O - https://repo.skype.com/data/SKYPE-GPG-KEY | sudo apt-key add -

upgrade
install_packs skypeforlinux

exit

