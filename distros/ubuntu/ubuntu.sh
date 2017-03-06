#!/bin/bash
# from ubuntu 16.04.2 amd64 desktop 
# run as sudo

###
### instantané 1
###

[ `whoami` != root ] && echo "should run as root" && exit 1


#configure proxy for installation...
#test if local server is present
ping -c 1 -i 0.2 gw.diablan 2> /dev/null
PINGRESULT=$?
if [ "$PINGRESULT" == "0" ]; then
	#use local url
	export SETUP_SCRIPT_LOCATION=http://gw.diablan/files/linux/
else
	#use remote url
	export SETUP_SCRIPT_LOCATION=http://home.koub.org/files/linux/
fi

#utility functions
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#update source.list

echo "deb http://archive.canonical.com/ubuntu xenial partner" >> /etc/source.list
echo "deb-src http://archive.canonical.com/ubuntu xenial partner" >> /etc/source.list


#do a full upgrade
upgrade

FOUND_VBOX=`lspci | grep -i vga | grep -i virtualbox | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	#explicit replacement of wayland with xorg beforehand
	apt-get -y install xserver-xorg xserver-xorg-video-all
	apt-get -y install virtualbox-guest-dkms virtualbox-guest-utils virtualbox-guest-x11
else
	echo "VirtualBox not found"
fi

#remove amazon app. FFS
apt-get -y remove unity-webapps-common

#install various tools
apt-get -y install htop geany bwm-ng qalculate-gtk filezilla vlc apt-file
apt-get -y install autotools-dev m4 libtool automake autoconf intltool
apt-file update

###
### instantané 2
###

##########################
#######	 LIGHTDM #########
##########################

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/terminator/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/truecrypt/ubuntu.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/gen-eclipse/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/ubuntu.sh


echo ""
echo ""
echo ""
echo " Installed users :"
echo ""
ls -ilh /home/
echo ""

RESUSR=1
while [ $RESUSR != 0 ]; do read -p "user to config : " USR; bash -c "id $USR > /dev/null"; RESUSR=$?; done

cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /home/$USR/
chown -R $USR:$USR /home/$USR



#clean
rm -f retry_* ubuntu_func.sh

exit
