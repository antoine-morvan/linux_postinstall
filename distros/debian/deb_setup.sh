#!/bin/bash
#TODO
#tester les drivers graphiques
#préconfigurer wine avec winetricks (cf vieux scripts arch?)

###############################
######	CONFIG DISTRIB	#######
###############################

#Proxy address for apt (comment to ignore)
PROXY="172.30.255.254:3128"
SETUP_SCRIPT_LOCATION=http://gw.diablan/files/linux/

#use wide screen background {WIDE_16_10 | WIDE_16_9 | NORMAL}
SCREEN=WIDE_16_10

#disable popups during aptitude installation script
export DEBIAN_FRONTEND=noninteractive
export ENABLE_PAUSE=YES

###############################
######	CONFIG SCRIPT	#######
###############################

[ $UID != 0 ] && echo "Error : must be run as root." && exit
VERSIONFILE=/etc/debian_version
[ ! -e $VERSIONFILE ] && echo "Error : could not find debian version file ($VERSIONFILE)." && exit
TESTVERSION=`cat $VERSIONFILE | colrm 2`
[ $TESTVERSION -lt 8 ] && echo "Error : requires debian 8." && exit

#utility functions
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh
TO_REMOVE+=" deb_func.sh"
TO_REMOVE+=" retry_mainlog_*.log"

if [ "$SCREEN" == "WIDE_16_9" ]; then
	BG=/usr/share/wallpapers/walldeb-wide_16_9.png
else
	if [ "$SCREEN" == "WIDE_16_10" ]; then
		BG=/usr/share/wallpapers/walldeb-wide_16_10.png
	else
		BG=/usr/share/wallpapers/walldeb.png
	fi
fi

echo "$BG" > setup.dat
echo "${SETUP_SCRIPT_LOCATION}" >> setup.dat
TO_REMOVE+=" setup.dat"

################################
#######	  CONFIG APT	########
################################
echo ""
echo "** Starting APT configuration **"
echo ""

if [ "$PROXY" != "" ]; then
	PROXY_SETUP=`cat /etc/apt/apt.conf 2> /dev/null | grep "Acquire::http::Proxy" | wc -l`
	if [ "$PROXY_SETUP" == "0" ]; then
		echo "   Use proxy : $PROXY"
		echo "Acquire::http::Proxy \"http://$PROXY\";" > /etc/apt/apt.conf.d/apt.conf
	else
		echo "   Proxy already setup."
	fi
fi

#{amd64 | i386}
ARCH=`dpkg --print-architecture`

#contrib non-free
if [ `grep contrib /etc/apt/sources.list | wc -l` == "0" ]; then
	echo "   adding contrib & non-free repos."
	sed -i 's/jessie main/jessie main contrib non-free/g' /etc/apt/sources.list
fi

dpkg --add-architecture i386


########################
######	 SETUP	########
########################
echo ""
echo "** Setup **"
echo ""

update
upgrade

echo "   Main Setup : downloading packages"
PACKS="sudo openssh-server perl nethogs smbclient samba iotop htop lzip unzip zip unrar curl hddtemp fakeroot alsa-utils alsa-base dirdiff linux-tools apt-file fuse vim emacs gcc build-essential linux-headers-`uname -r` cmake libtool pkg-config python git-core etherwake screen nmap bzip2 sharutils cifs-utils rsync subversion ttf-dejavu tsocks exfat-utils sshfs screen davfs2 iptraf openjdk-7-jre ntp ntpdate libcurl3-gnutls dvtm byobu dtach tmux ntfs-3g sdparm hdparm memtest86+ lvm2 cloc apt-transport-https"

install_packs $PACKS

##########################
#######	 CONFIG	 #########
##########################
echo ""
echo "** Configuration **"
echo ""

#find main user
USR=`more /etc/passwd | grep 1000 | cut -d":" -f 1`

#change time to local if specified
[ "$TIME" == "LOCAL" ] && echo "   Change time to LOCAL" && sed -i -e 's/UTC/LOCAL/g' /etc/adjtime

#add main user in sudo and fuse group
groupadd netdev
usermod -a -G netdev $USR
usermod -a -G sudo $USR

#apt-file
echo "   apt-file update"
apt-file update > /dev/null

#hddtemp
echo "   hddtemp (+sudoers)"
chmod u+s /usr/sbin/hddtemp
echo "ALL ALL = NOPASSWD: /usr/sbin/hddtemp" > /etc/sudoers.d/hddtemp

#alias
echo "   Aliases"
echo "alias ll='ls -ailh'" > /etc/skel/.bash_aliases
echo "alias l='ls'" >> /etc/skel/.bash_aliases
echo "alias la='ls -a'" >> /etc/skel/.bash_aliases
sed -i -e 's/#alias grep/alias grep/g' /etc/skel/.bashrc

#samba
echo "   Samba"
cat > /etc/samba/smb.conf << "EOF"
[global]
	workgroup = DIABLAN
	server string = %h server
	security = share
	log file = /var/log/samba/log.%m

#======================= Share Definitions =======================

#[share]
#	path= /mnt/data/share_vm
#	public = yes
#	writeable = yes
#	hosts allow = 192.168.56.

EOF

#vim
echo "   Vim"
cp /usr/share/vim/vimrc /etc/skel/.vimrc
cat >>  /etc/skel/.vimrc << "EOF"
syntax on
colorscheme desert
EOF

#firewall
echo "   Iptables"
retry "wget -q ${SETUP_SCRIPT_LOCATION}/deb/iptables.sh -O /etc/init.d/iptables"
chmod +x /etc/init.d/iptables
update-rc.d iptables defaults > /dev/null

#disable power button
echo "   Acpi"
cp /etc/acpi/powerbtn-acpi-support.sh /etc/acpi/powerbtn-acpi-support.sh.backup
cat > /etc/acpi/powerbtn-acpi-support.sh << "EOF"
#!/bin/sh
exit 0
EOF

#blacklist mods
echo "   Blacklist mods"
echo "blacklist pcspkr" >> /etc/modprobe.d/blacklist.conf # disable annoying PC speaker

#wallpaper/background
echo "   Background"
mkdir -p /usr/share/wallpapers
# { deb | walldeb }
WALL=walldeb
retry "wget -q -O /usr/share/wallpapers/walldeb.png ${SETUP_SCRIPT_LOCATION}/wallpapers/${WALL}.png"
retry "wget -q -O /usr/share/wallpapers/walldeb-wide_16_9.png ${SETUP_SCRIPT_LOCATION}/wallpapers/${WALL}_wide_16_9.png"
retry "wget -q -O /usr/share/wallpapers/walldeb-wide_16_10.png ${SETUP_SCRIPT_LOCATION}/wallpapers/${WALL}_wide_16_10.png"

#use full resolution in textmode
echo "   Grub"
sed -i -e 's/#GRUB_GFXMODE=640x480/GRUB_GFXMODE=auto\nGRUB_GFXPAYLOAD_LINUX=keep/g' /etc/default/grub
#set grub background
if [ "`grep walldeb /etc/default/grub | wc -l`" == "0" ]; then
	echo "GRUB_BACKGROUND=/usr/share/wallpapers/walldeb.png" >> /etc/default/grub
fi
update-grub2 2> /dev/null

#################################
#######	 SETUP HEAD 	#########
#################################

#dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/liquorix_kernel.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/dri.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/deb/head.sh

#####################################
#######	 FINALIZE CONFIG	#########
#####################################

echo "   Copy skel"
cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /root/
cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /home/$USR/
chown -R $USR:$USR /home/$USR

##### EXIT #####

echo ""
echo "** FINALIZE **"
echo ""

update
upgrade
dist_upgrade
apt-get -q -y autoremove > /dev/null 2> /dev/null
apt-get clean
rm -v $TO_REMOVE

echo ""
echo "** Reboot **"
echo ""

