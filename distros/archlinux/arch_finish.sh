#!/bin/bash -eu
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
BOOTDRIVE=`cat /setup.dat | sed '5q;d'`
BOOTPARTITION=`cat /setup.dat | sed '6q;d'`
source /arch_func.sh

#TODO
#replacer tzdata par timedatectl

##########################
#######	  ARGS	 #########
##########################

BOOTDRIVE=$1
SETUP_MODE=$2
if [ -z ${UEFIPARTITION+x} ]; then
  UEFIPARTITION=""
else
  UEFIPARTITION=$3
fi
#{GRUB | SYSLINUX}
BOOTLOADER=GRUB


export IGNORE_CC_MISMATCH=1
echo "IGNORE_CC_MISMATCH=1" >> /etc/environment

##############################
#######	UNMOUNT TMP ##########
##############################
#unmount /tmp from ram fs
umount /tmp

##############################
#######	LOCALIZATION #########
##############################

ARCH=`uname -m`

# gen locals
sed -i 's/#fr_FR.UTF-8/fr_FR.UTF-8/g' /etc/locale.gen
locale-gen
export LANG=fr_FR.UTF-8
echo "LANG=\"fr_FR.UTF-8\"" >> /etc/locale.conf

pause "locale configured"

#################################
#######	AUR USER & SUDO #########
#################################

#sudoers
sed -i 's/# %sudo/%sudo/g' /etc/sudoers
echo "build ALL = NOPASSWD: /usr/bin/pacman" > /etc/sudoers.d/build

#prepare build user (cannot build AUR packages from root)
useradd build -M -N -r -d /tmp
passwd build -l

#make curl ignore ssl verification failures
su build -c "echo insecure >> ~/.curlrc"

pause "suoders & build user configured"

##############################
#######	UPDATE & KEYS ########
##############################

pacman -Syu
pacman -S archlinux-keyring --noconfirm

pause "keyring for boostraped system configured; about to install aurman..."

############################
#######	INSTALL YAY ########
############################

pause "YAY::dep"
pacman -S --noconfirm base-devel git expac pyalpm python python-dateutil python-feedparser python-regex python-requests go

pause "YAY::clone"
(cd /tmp/ && su build -c "git clone https://aur.archlinux.org/yay.git" )
pause "Aurman::makepkg"
(cd /tmp/yay && su build -c "makepkg -si --noconfirm" )

pause "aurman installed; about to install base packages..."
#################################
#######	INSTALL PACKAGES ########
#################################
PKGS="hddtemp dkms linux-headers linux-lts-headers openssh vim hddtemp lm_sensors vim-plugins lshw acpi acpid p7zip memtest86+ htop nethogs iotop linux-tools nmap bzip2 sharutils rsync tsocks exfat-utils ntp ntfs-3g dnsutils traceroute lzip tree sdparm hdparm dosfstools rarian libzip gnu-netcat cabextract btrfs-progs bwm-ng unrar docker docker-compose screen archey3"

AURPKGS="etherwake byobu bash-completion archey-plus"

case $SETUP_MODE in
  workstation)
    PKGS+=" samba cifs-utils base-devel libtool linux-zen-headers parted emacs zip unzip curl fakeroot alsa-utils fuse cmake pkg-config python git svn ttf-dejavu sshfs davfs2 tmux subversion libcups cups ghostscript nss-mdns mercurial dri2proto glproto xorg-util-macros resourceproto bigreqsproto xtrans xcmiscproto xf86driproto intltool cronie autofs jre8-openjdk"
    AURPKGS+=" chkboot stapler dtach"
    if [ "$TESTSYSTEM" != "YES" ]; then
      PKGS+=" pacgraph lynx perl-xml-parser alsi apache php php-apache markdown cloc arj unarj unace rpmextract tig lhasa openvpn ghc dvtm clang openmp"
      AURPKGS+=" hstr-git maven-bash-completion-git perl-bash-completion kingbash-gb-git ms-sys"
    fi
    ;;
esac

install_packs "$PKGS"

pause "base packages installed; aboute to install lib32 (x64 only), or aur packages (x86)."
if [ "$ARCH" == "x86_64" ]; then
	echo -e "\no\no\n" | pacman -S multilib-devel
	pause "multilib-devel installed"
fi

install_packs_aur "$AURPKGS"

pause "aur packages installed"

pause "about to setup drivers..."

dl_and_execute ${SETUP_SCRIPT_LOCATION}/distros/archlinux/arch_dri.sh

pause "drivers installed; about to install head..."

case $SETUP_MODE in
  workstation)
    if [ "$INSTALLHEAD" == "YES" ]; then
      dl_and_execute ${SETUP_SCRIPT_LOCATION}/distros/archlinux/arch_head.sh $SETUP_MODE
    fi
    ;;
  server)
    echo "skip head in server mode"
    ;;
esac

pause "head intalled. Start nbon head config..."

[ -e /etc/localtime ] && rm /etc/localtime
ln -s /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo "KEYMAP=fr-pc" > /etc/vconsole.conf
echo "FONT=lat1-12" >> /etc/vconsole.conf
echo "FONT_MAP=8859-2" >> /etc/vconsole.conf

pause "time & vcosole configured"

#generate initram
ORIG=`more /etc/mkinitcpio.conf | grep ^HOOKS`
NEW=`echo $ORIG | sed 's/filesystems/keymap encrypt lvm2 resume filesystems/g'`
sed -i "s/$ORIG/$NEW/g" /etc/mkinitcpio.conf
mkinitcpio -p linux

if [ "$TESTSYSTEM" != "YES" ]; then
	mkinitcpio -p linux-lts
  case $SETUP_MODE in
    workstation)
      mkinitcpio -p linux-zen
      ;;
  esac
fi
pause "initram configured"

#wallpaper/background
mkdir -p /usr/share/wallpapers
# { arch | deb | walldeb }
WALL=arch
retry "wget -q -O /usr/share/wallpapers/wallarch.png ${SETUP_SCRIPT_LOCATION}/99_shared/wallpapers/${WALL}.png"
retry "wget -q -O /usr/share/wallpapers/wallarch-wide_16_9.png ${SETUP_SCRIPT_LOCATION}/99_shared/wallpapers/${WALL}_wide_16_9.png"
retry "wget -q -O /usr/share/wallpapers/wallarch-wide_16_10.png ${SETUP_SCRIPT_LOCATION}/99_shared/wallpapers/${WALL}_wide_16_10.png"

pause "wallpaper installed"

#setup bootloader
if [ "$BOOTLOADER" == "SYSLINUX" ]; then
	syslinux-install_update -iam
fi
if [ "$BOOTLOADER" == "GRUB" ]; then
	mkdir -p /boot/grub/
	#set grub background
	if [ "`grep walldeb /etc/default/grub | wc -l`" == "0" ]; then
		echo "GRUB_BACKGROUND=/usr/share/wallpapers/wallarch.png" >> /etc/default/grub
	fi
	grub-mkconfig -o /boot/grub/grub.cfg
	if [ "$UEFIPARTITION" != "" ]; then
		echo "Setup UEFI grub"
		mkdir -p /boot/efi/EFI
		grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=arch_grub --recheck
	else
		echo "Setup normal grub"
		grub-install $BOOTDRIVE
	fi
fi

retry "wget -q -O /etc/iptables/iptables.rules ${SETUP_SCRIPT_LOCATION}/distros/archlinux/iptables.rules"
retry "wget -q -O /etc/systemd/system/firewall-tuning.service ${SETUP_SCRIPT_LOCATION}/distros/archlinux/firewall-tuning.service"
retry "wget -q -O /usr/local/sbin/firewall-tuning.sh ${SETUP_SCRIPT_LOCATION}/distros/archlinux/firewall-tuning.sh"
chmod +x /usr/local/sbin/firewall-tuning.sh

#read -p "press enter ... (before enabling services)"

echo dhcpcd
systemctl enable dhcpcd
echo iptables
systemctl enable iptables
echo fireall
systemctl enable firewall-tuning
echo systemdtimesyncd
systemctl enable systemd-timesyncd
echo sshd
systemctl enable sshd
echo docker
systemctl enable docker

case $SETUP_MODE in
  workstation)
    echo hddtemp
    systemctl enable hddtemp
    echo lmsensors
    systemctl enable lm_sensors
    echo cupsd
    systemctl enable org.cups.cupsd.service
    echo cupsbrowser
    systemctl enable cups-browsed.service
    echo ntpd
    systemctl enable ntpd
    echo ntpdate
    systemctl enable ntpdate
    echo samba
    systemctl enable samba
    echo smb
    systemctl enable smb
    echo nmb
    systemctl enable nmb
    echo chkboot
    systemctl enable chkboot
    echo cronie
    systemctl enable cronie
    ;;
esac

#read -p "press enter ..."
pause "all services configured & enabled"

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

pause "kernel configured"

#blacklist mods
echo "blacklist pcspkr" >> /etc/modprobe.d/blacklist.conf # disable annoying PC speaker

#disable tmpfs on /tmp
systemctl mask tmp.mount
cat > /etc/tmpfiles.d/tmp.conf << "EOF"
# see tmpfiles.d(5)
# always enable /tmp folder cleaning
D! /tmp 1777 root root 0

# remove files in /var/tmp older than 10 days
D /var/tmp 1777 root root 10d

# namespace mountpoints (PrivateTmp=yes) are excluded from removal
x /tmp/systemd-private-*
x /var/tmp/systemd-private-*
X /tmp/systemd-private-*/tmp
X /var/tmp/systemd-private-*/tmp
EOF

#alias
echo "alias vi='vim'" >> /etc/skel/.bashrc
echo "alias ll='ls -ailh'" >> /etc/skel/.bashrc
echo "alias l='ls'" >> /etc/skel/.bashrc
echo "alias la='ls -a'" >> /etc/skel/.bashrc
echo "alias grep='grep --color=auto'" >> /etc/skel/.bashrc
echo "alias fgrep='fgrep --color=auto'" >> /etc/skel/.bashrc
echo "alias egrep='egrep --color=auto'" >> /etc/skel/.bashrc
echo "alias autoremove='sudo pacman -Rcns \$(pacman -Qdtq)'" >> /etc/skel/.bashrc
echo "archey" >> /etc/skel/.bashrc

pause "mod blacklisted & alias configured"

#vim
cp /usr/share/vim/vimfiles/archlinux.vim /etc/skel/.vimrc
cat >> /etc/skel/.vimrc << "EOF"
syntax on
colorscheme elflord
set number
set mouse=a
filetype plugin indent on
EOF

cat >> /etc/skel/.profile << "EOF"
export EDITOR=vim
EOF
chmod +x /etc/skel/.profile

#acpi
cat /etc/systemd/logind.conf | sed -e 's/#HandleLidSwitch=suspend/HandleLidSwitch=lock/g' > tmp
mv tmp /etc/systemd/logind.conf


case $SETUP_MODE in
  workstation)
    #samba (create guset user)
    cat > /etc/samba/smb.conf << "EOF"
[global]
	workgroup = DIABLAN
	server string = %h server
	security = user
	encrypt passwords = true
	guest account = guest
	inherit owner = yes
	inherit permissions = yes
	log file = /var/log/samba/log.samba

#======================= Share Definitions =======================

[share]
	path= /srv/smb/
	public = yes
	writeable = no
	browseable = yes
	guest ok = yes
#	hosts allow = 192.168.56.

EOF
    useradd -r -M -s /bin/false -U guest
    echo  -e "guest\nguest\n" | passwd guest
    echo -e "guest\nguest\n" | smbpasswd -a guest -s
    mkdir -p /srv/smb/
    chmod 777 /srv/smb/

    #git tool
    cat > /usr/local/bin/gitstorecredential-10h << "EOF"
#!/bin/bash
git config --global credential.helper 'cache --timeout=36000'
EOF
    chmod +x /usr/local/bin/gitstorecredential-10h

    #config chkboot
    echo "config chkboot"
    echo "configuring chkboot"
    sed -i "s#BOOTDISK=/dev/sda#BOOTDISK=${BOOTDRIVE}#g" /etc/default/chkboot.conf
    sed -i "s#BOOTPART=/dev/sda1#BOOTPART=${BOOTPARTITION}#g" /etc/default/chkboot.conf
    /usr/bin/chkboot
    cat > /usr/local/bin/chkboot_custom_alerts << 'EOF'
#!/bin/bash

# small script to check if files under /boot changed
# Author: https://github.com/sercxanto
#
# License: GPLv2 or later

source /etc/default/chkboot.conf

chgfile=${CHKBOOT_DATA}/${CHANGES_ALERT}

XMESSAGE=/usr/bin/xmessage
ZENITY=/usr/bin/zenity
NOTIFICATION="This notification will continue to appear until you either run chkboot again as root or restart your computer"

if [ -s $chgfile ]; then
	TMPFILE=`mktemp`
	echo $NOTIFICATION > $TMPFILE
	echo "" >> $TMPFILE
	cat $chgfile >> $TMPFILE
	echo -e "\n\nPress validate to accept those changes and run chkboot" >> $TMPFILE
    if [ -x $ZENITY ]; then
        cat $TMPFILE | $ZENITY --title "ALERT: Boot changes" --text-info --width 600 --height 500
        RES=$?
        if [ "$RES" == "0" ]; then
			gksudo /usr/bin/chkboot &
		fi
    elif [ -x $XMESSAGE ]; then
        cat $TMPFILE | $XMESSAGE -buttons Cancel:1,Validate:0 -default Validate -file -
        if [ "$RES" == "0" ]; then
			gksudo /usr/bin/chkboot &
		fi
    fi
    exit 1
    rm $TMPFILE
fi
exit 0

EOF
    chmod +x /usr/local/bin/chkboot_custom_alerts
    ;;
esac


pause "arch_head.sh done. Last configurations..."

# read values when everything is fine above
echo " ###################"
echo " # Hostname        #"
echo " ###################"
echo ""
read -p "Hostname : " HOSTNAME
echo "$HOSTNAME" > /etc/hostname
#hostnamectl set-hostname $HOSTNAME
echo ""
echo " ###################"
echo " # Root Password   #"
echo " ###################"
echo ""
set +e
passwd
while [ "$?" != "0" ]; do
	passwd
done;
set -e
echo ""
echo " ###################"
echo " # Create new User #"
echo " ###################"
echo ""
read -p "User login : " USR
echo ""
useradd -d /home/$USR -G users -m $USR -s /bin/bash
set +e
passwd $USR
while [ "$?" != "0" ]; do
	passwd $USR
done;
set -e

grep -q "^docker:" /etc/group || groupadd docker
grep -q "^sudo:" /etc/group || groupadd sudo
grep -q "^video:" /etc/group || groupadd video

gpasswd -a $USR video
gpasswd -a $USR sudo
gpasswd -a $USR docker

cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /root/
cp -R `find /etc/skel -mindepth 1 -maxdepth 1` /home/$USR/
chown -R $USR:$USR /home/$USR

exit
