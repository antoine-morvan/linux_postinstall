#!/bin/bash -eu
# from ubuntu 16.04.2 amd64 desktop 
# run as sudo

FASTSETUP=NO

###
### instantané 1
###

[ `whoami` != root ] && echo "should run as sudo" && exit 1


USR=${SUDO_USER}


#configure proxy for installation...
#test if local server is present
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
export ENABLE_PAUSE=NO
export LOGCNT=0

apt-get update
apt-get -y install wget

#utility functions
[ ! -e ubuntu_func.sh ] &&  wget --no-cache -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

#update source.list
[ `grep "^deb-src http://fr.archive.ubuntu.com/ubuntu/ $(lsb_release -sc) multiverse" /etc/apt/sources.list | wc -l` == 0 ] && \
	echo "deb http://archive.canonical.com/ubuntu $(lsb_release -sc) partner" >> /etc/apt/sources.list

#disable auto updates/upgrades
if [ -e /etc/apt/apt.conf.d/10periodic ]; then
	sed -i -e 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#g' /etc/apt/apt.conf.d/10periodic
fi
if [ -e /etc/apt/apt.conf.d/20auto-upgrades ]; then
  sed -i -e 's#APT::Periodic::Update-Package-Lists "1";#APT::Periodic::Update-Package-Lists "0";#g' /etc/apt/apt.conf.d/20auto-upgrades
  cat >> /etc/apt/apt.conf.d/20auto-upgrades << EOF
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::AutocleanInterval "0";
EOF
fi

#do a full upgrade
upgrade

FOUND_VBOX=`lspci | grep -i vga | grep -i virtualbox | wc -l`
if [ "$FOUND_VBOX" != "0" ]; then
	echo "Found VirtualBox"
	#explicit replacement of wayland with xorg beforehand
	#apt-get -y install xserver-xorg xserver-xorg-video-all
	#apt-get -y install virtualbox-guest-dkms virtualbox-guest-x11
	echo "Skipped VirtualBox Guest"
else
	echo "VirtualBox not found"
fi

#configure kernel for not stalling when moving big files on slow devices
cat > /etc/sysctl.d/99-vm_dirty.conf << EOF
vm.dirty_background_bytes = 16777216
vm.dirty_bytes = 16777216
EOF
#	following parameters does not have write access from sysctl (as of
#	late January 2017)
cat > /etc/tmpfiles.d/transparent_hugepages.conf << EOF
w /sys/kernel/mm/transparent_hugepage/enabled - - - - madvise
w /sys/kernel/mm/transparent_hugepage/defrag - - - - always
w /sys/kernel/mm/transparent_hugepage/khugepaged/defrag - - - - 0
EOF


[ `grep "alias ll='ls -ailhF'" /etc/skel/.bashrc | wc -l` == 0 ] && \
	sed -i -e "s#alias ll='ls -alF'##g" /etc/skel/.bashrc && \
	echo "alias ll='ls -ailhF'" >> /etc/skel/.bashrc && \
	echo "alias vi='vim'" >> /etc/skel/.bashrc

[ `grep "export EDITOR=vim" /etc/skel/.profile | wc -l` == 0 ] && \
	echo "export EDITOR=vim" >> /etc/skel/.profile
chmod +x /etc/skel/.profile

#git tool
cat > /usr/local/bin/gitstorecredential-10h << "EOF"
#!/bin/bash
git config --global credential.helper 'cache --timeout=36000'
EOF
chmod +x /usr/local/bin/gitstorecredential-10h


#remove amazon app. FFS
apt -y remove unity-webapps-common gdm3

#ttf-mscorefonts
PACKS="htop geany bwm-ng qalculate-gtk filezilla vlc apt-file autotools-dev m4 libtool automake autoconf intltool wget bash net-tools zsh samba cifs-utils lshw libtool p7zip htop nethogs iotop parted emacs zip unzip curl fakeroot alsa-utils linux-tools-generic fuse cmake pkg-config python git screen nmap bzip2 sharutils rsync subversion ttf-dejavu tsocks exfat-utils sshfs ntp dtach tmux ntfs-3g subversion sdparm hdparm dnsutils traceroute lzip tree cups ghostscript dosfstools intltool netcat cabextract bwm-ng markdown cloc arj unar unace tig lhasa openvpn dvtm libomp5 byobu rar vim iptables pidgin xterm rxvt-unicode lightdm lightdm-gtk-greeter terminator pulseaudio pavucontrol paprefs mate-themes xfce4 xfce4-goodies xfce4-session xfce4-settings xfwm4 xfwm4-themes xfconf thunar numlockx pinta ruby imagemagick iptraf-ng arandr elementary-icon-theme gnome-keyring seahorse python-setuptools tlp bash-completion lsb-release smartmontools graphviz gparted filezilla faac libboost-all-dev dbus icoutils zenity hexchat gitg xdot  filelight gdmap qt5-default youtube-dl pasystray pavumeter xprintidle firefox update-manager system-config-printer-common nscd "


#install various tools
apt install -y --no-install-recommends $PACKS

if [ "$FASTSETUP" != "YES" ]; then
  EXTRAPACKS=" mercurial lynx audacity keepassx thunderbird ghc clang playonlinux xfburn deluge libreoffice gimp inkscape calibre acetoneiso latex2rtf lyx texmaker pstotext texlive-full pandoc texstudio golang maven gradle openjfx openjfx-source jabref handbrake owncloud-client"
  apt install -y --no-install-recommends $EXTRAPACKS
fi

apt-file update

#install packages that require user action (i.e. license) at the end
if [ "$FASTSETUP" != "YES" ]; then
  apt install -y --no-install-recommends wireshark-gtk steam davfs2 wine-stable
fi


###

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/terminator/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/geany/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/truecrypt/ubuntu.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/gen-eclipse/ubuntu.sh
#dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/purple-plugins/ubuntu.sh

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/deadbeef/ubuntu.sh
dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/skype/ubuntu.sh


if [ "$FASTSETUP" != "YES" ]; then
  dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/virtualbox/ubuntu.sh
fi


echo ""
echo ""

cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /home/$USR/
chown -R $USR:$USR /home/$USR



#clean
rm -f retry_* ubuntu_func.sh

exit
