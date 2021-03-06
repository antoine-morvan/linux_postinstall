#!/bin/bash -eu

#configure script variables
[ `whoami` != root ] && echo "should run as root" && exit 1
#export SETUP_SCRIPT_LOCATION=http://koub.org/files/linux/
export SETUP_SCRIPT_LOCATION=https://raw.githubusercontent.com/antoine-morvan/linux_postinstall/master/
[ ! -e ubuntu_func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/01_func/ubuntu_func.sh -O ubuntu_func.sh
source ubuntu_func.sh

upgrade 
install_packs librsvg2-bin byobu xfce4 xfce4-goodies libgtk2.0-dev pasystray qalculate-gtk xscreensaver \
	murrine-themes gtk2-engines-murrine libxfce4ui-1-dev xfce4-panel-dev libxfce4util-dev \
	git checkinstall lightdm-gtk-greeter xubuntu-wallpapers xubuntu-icon-theme xubuntu-artwork orage
# missing in ubuntu 20.04: community-themes

apt autoremove -y --purge yaru-theme-icon yaru-theme-gtk yaru-theme-sound yaru-theme-gnome-shell
#install multiload ng for xfce
git clone https://github.com/udda/multiload-ng.git multiload
(cd multiload && \
	./autogen.sh && \
	./configure --prefix=/usr --with-xfce4 --with-gtk=2.0 --disable-autostart && \
	make
)
(cd multiload/extras/checkinstall && \
	make deb-package && \
	dpkg -i multiload-ng*.deb
)
rm -rf multiload

echo ""
echo "** Config XFCE 4.12"
echo ""

#get theme
#originated from :
#http://xfce-look.org/CONTENT/content-files/121685-BSM%20Simple%2013.tar.gz
#http://xfce-look.org/CONTENT/content-files/145188-Lines_0.3.1.tar.gz

mkdir -p /usr/share/themes
retry "wget -q -O /usr/share/themes/145188-Lines_0.3.1.tar.gz ${SETUP_SCRIPT_LOCATION}/99_shared/themes/145188-Lines_0.3.1.tar.gz"
(cd /usr/share/themes &&
	tar xf 145188-Lines_0.3.1.tar.gz &&
	rm 145188-Lines_0.3.1.tar.gz)

retry "wget -q -O /usr/share/themes/121685-BSM_Simple_13.tar.gz ${SETUP_SCRIPT_LOCATION}/99_shared/themes/121685-BSM_Simple_13.tar.gz"
(cd /usr/share/themes &&
        tar xf 121685-BSM_Simple_13.tar.gz &&
        rm 121685-BSM_Simple_13.tar.gz)
        
retry "wget -q -O /usr/share/themes/Numix-DarkBlue.tar.bz2 ${SETUP_SCRIPT_LOCATION}/99_shared/themes/Numix-DarkBlue.tar.bz2"
(cd /usr/share/themes &&
	tar xf Numix-DarkBlue.tar.bz2 &&
	rm Numix-DarkBlue.tar.bz2)

chmod -R 755 /usr/share/themes
# link broken
# install_packs_aur gtk-theme-bsm-simple

#get icons
mkdir -p /usr/share/icons
retry "wget -q -O /usr/share/icons/Fog.tar.bz2 ${SETUP_SCRIPT_LOCATION}/99_shared/themes/Fog.tar.bz2"
(cd /usr/share/icons &&
	tar xf Fog.tar.bz2 &&
	rm Fog.tar.bz2)

chmod -R 755 /usr/share/icons

mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/

#bordures
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xfwm4.xml"
#icons
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xsettings.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xfce4-session.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xfce4-power-manager.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/pointers.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/pointers.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/keyboard-layout.xml"

#default icon view & show address bar (Thunar)
mkdir -p /etc/skel/.config/Thunar/
echo "[Configuration]" > /etc/skel/.config/Thunar/thunarrc
echo "LastView=ThunarDetailsView" >> /etc/skel/.config/Thunar/thunarrc
echo "LastLocationBar=ThunarLocationEntry" >> /etc/skel/.config/Thunar/thunarrc

#Thunar user custom actions
retry "wget -q -O /etc/skel/.config/Thunar/uca.xml ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/uca.xml"

#disable thumbs in thunar
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/thunar.xml"

mkdir -p /etc/xdg/xfce4/panel/
#default taskbar
FILE=/etc/xdg/xfce4/panel/default.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/default-panel.xml"

#change icon to debian
#sed -i 's/debian-logo/archlinux-icon-crystal/g' $FILE
sed -i 's/iceweasel/firefox/g' $FILE
sed -i 's/icedove/thunderbird/g' $FILE
sed -i 's/PlayOnLinux/playonlinux/g' $FILE
#rsvg-convert /usr/share/archlinux/icons/archlinux-icon-crystal-64.svg -o /usr/share/pixmaps/archlinux-icon-crystal.png
#ln -s /usr/share/byobu/pixmaps/byobu.svg /usr/share/pixmaps/byobu.svg

mkdir -p /etc/skel/.config/xfce4/panel/
FILE=/etc/skel/.config/xfce4/panel/xfce4-cpufreq-plugin-6.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/xfce4-cpufreq-plugin-6.rc"
FILE=/etc/skel/.config/xfce4/panel/weather-11.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/weather-11.rc"

FILE=/etc/skel/.config/xfce4/panel/xfce4-orageclock-plugin-12.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/xfce4-orageclock-plugin-12.rc"

FILE=/etc/skel/.config/xfce4/panel/whiskermenu-91.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/whiskermenu-91.rc"

sed -i 's/button-icon=archlinux-icon-crystal/button-icon=ubuntu-logo-icon/g' $FILE


FILE=/etc/skel/.config/xfce4/panel/multiload-ng-xfce4-92.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/multiload-ng-xfce4-92.rc"

FILE=/etc/skel/.config/xfce4/panel/xfce4-sensors-plugin-93.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/xfce4-sensors-plugin-93.rc"

FILE=/etc/skel/.config/xfce4/panel/battery-94.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/panel/battery-94.rc"

mkdir -p /etc/skel/.config/xfce4/panel/launcher-7
ln -s /usr/share/applications/geany.desktop /etc/skel/.config/xfce4/panel/launcher-7/geany.desktop

mkdir -p /etc/skel/.config/xfce4/panel/launcher-8
ln -s /usr/share/applications/qalculate-gtk.desktop /etc/skel/.config/xfce4/panel/launcher-8/qalculate.desktop

mkdir -p /etc/skel/.config/xfce4/panel/launcher-9
ln -s /usr/share/applications/terminator.desktop /etc/skel/.config/xfce4/panel/launcher-9/terminator.desktop

mkdir -p /etc/skel/.config/xfce4/panel/launcher-14
ln -s /usr/share/applications/firefox.desktop /etc/skel/.config/xfce4/panel/launcher-14/firefox.desktop

mkdir -p /etc/skel/.config/xfce4/panel/launcher-19
ln -s /usr/share/applications/chromium-browser.desktop /etc/skel/.config/xfce4/panel/launcher-19/chromium.desktop

mkdir -p /etc/skel/.config/xfce4/panel/launcher-20
ln -s /usr/share/applications/steam.desktop /etc/skel/.config/xfce4/panel/launcher-19/steam.desktop


#background
mkdir -p /usr/share/backgrounds/xfce
retry "wget -q -O /usr/share/backgrounds/xfce/wallubuntu_wide_16_10.png ${SETUP_SCRIPT_LOCATION}/99_shared/wallpapers/wallubuntu_wide_16_10.png"
retry "wget -q -O /usr/share/backgrounds/xfce/wallubuntu_wide_16_9.jpg ${SETUP_SCRIPT_LOCATION}/99_shared/wallpapers/wallubuntu_wide_16_9.jpg"

BG=/usr/share/backgrounds/xfce/wallubuntu_wide_16_10.png

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xfce4-desktop.xml"
sed -i -e "s#%BG%#$BG#g" /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml


#shortcuts
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xfce4-keyboard-shortcuts.xml"

#xscreensaver avoid using desktop pictures
FILE=/etc/skel/.xscreensaver
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/02_apps/xfce-4.12/xscreensaver"

#disable volumed (replaced by pasystray)
#rm -f /etc/xdg/autostart/xfce4-volumed.desktop
[ ! -e /etc/xdg/autostart/pasystray.desktop ] && ln -s /usr/share/applications/pasystray.desktop /etc/xdg/autostart/pasystray.desktop


##########################
#######	 LIGHTDM #########
##########################

cat >> /etc/lightdm/lightdm-gtk-greeter.conf << EOF
background=$BG
theme-name=Numix-DarkBlue
xft-antialias=true
xft-dpi=80
xft-hintstyle=hintfull
xft-rgba=rgb
show-indicators=~language;~session;~power
indicators = ~host;~spacer;~clock;~spacer;~layout;~language;~session;~a11y;~power
EOF

###################################
#######	File association  #########
###################################

echo "   File association"
mkdir -p /etc/skel/.config/
cat > /etc/skel/.config/mimeapps.list << "EOF"
[Default Applications]
application/x-shellscript=geany.desktop;
text/plain=geany.desktop
text/x-tex=geany.desktop
text/x-bibtex=geany.desktop
application/pdf=evince.desktop
application/xml=geany.desktop
image/png=pinta.desktop
image/tiff=pinta.desktop
image/bmp=pinta.desktop
image/jpeg=pinta.desktop
image/gif=pinta.desktop

EOF

############################################
#################  END  ####################
############################################

exit 0
