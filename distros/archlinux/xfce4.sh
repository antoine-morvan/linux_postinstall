#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

echo ""
echo "** Config XFCE 4.10"
echo ""

#get theme
#originated from :
#http://xfce-look.org/CONTENT/content-files/121685-BSM%20Simple%2013.tar.gz
#http://xfce-look.org/CONTENT/content-files/145188-Lines_0.3.1.tar.gz
mkdir -p /usr/share/themes
retry "wget -q -O /usr/share/themes/145188-Lines_0.3.1.tar.gz ${SETUP_SCRIPT_LOCATION}/xfce-4.10/145188-Lines_0.3.1.tar.gz"
(cd /usr/share/themes &&
	tar xf 145188-Lines_0.3.1.tar.gz &&
	rm 145188-Lines_0.3.1.tar.gz)

retry "wget -q -O /usr/share/themes/121685-BSM_Simple_13.tar.gz ${SETUP_SCRIPT_LOCATION}/xfce-4.10/121685-BSM_Simple_13.tar.gz"
(cd /usr/share/themes &&
        tar xf 121685-BSM_Simple_13.tar.gz &&
        rm 121685-BSM_Simple_13.tar.gz)

chmod -R 755 /usr/share/themes
# link broken
# install_packs_aur gtk-theme-bsm-simple

#get icons
mkdir -p /usr/share/icons
retry "wget -q -O /usr/share/icons/Fog.tar.bz2 ${SETUP_SCRIPT_LOCATION}/xfce-4.10/Fog.tar.bz2"
(cd /usr/share/icons &&
	tar xf Fog.tar.bz2 &&
	rm Fog.tar.bz2)
chmod -R 755 /usr/share/icons

mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/

#bordures
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfwm4.xml"
#icons
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xsettings.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-session.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-power-manager.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/pointers.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/pointers.xml"

FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/keyboard-layout.xml"

#default icon view & show address bar (Thunar)
mkdir -p /etc/skel/.config/Thunar/
echo "[Configuration]" > /etc/skel/.config/Thunar/thunarrc
echo "LastView=ThunarDetailsView" >> /etc/skel/.config/Thunar/thunarrc
echo "LastLocationBar=ThunarLocationEntry" >> /etc/skel/.config/Thunar/thunarrc

#Thunar user custom actions
retry "wget -q -O /etc/skel/.config/Thunar/uca.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/uca.xml"

#disable thumbs in thunar
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/thunar.xml"

mkdir -p /etc/xdg/xfce4/panel/
#default taskbar
FILE=/etc/xdg/xfce4/panel/default.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/default-panel.xml"

#change icon to debian
sed -i 's/debian-logo/archlinux-icon-crystal/g' $FILE
sed -i 's/iceweasel/firefox/g' $FILE
sed -i 's/icedove/thunderbird/g' $FILE
sed -i 's/PlayOnLinux/playonlinux/g' $FILE
rsvg-convert /usr/share/archlinux/icons/archlinux-icon-crystal-64.svg -o /usr/share/pixmaps/archlinux-icon-crystal.png
ln -s /usr/share/byobu/pixmaps/byobu.svg /usr/share/pixmaps/byobu.svg

mkdir -p /etc/skel/.config/xfce4/panel/
FILE=/etc/skel/.config/xfce4/panel/xfce4-cpufreq-plugin-6.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/xfce4-cpufreq-plugin-6.rc"
FILE=/etc/skel/.config/xfce4/panel/weather-11.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/weather-11.rc"

FILE=/etc/skel/.config/xfce4/panel/xfce4-orageclock-plugin-12.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/xfce4-orageclock-plugin-12.rc"

FILE=/etc/skel/.config/xfce4/panel/whiskermenu-91.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/whiskermenu-91.rc"

FILE=/etc/skel/.config/xfce4/panel/multiload-ng-xfce4-92.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/multiload-ng-xfce4-92.rc"

FILE=/etc/skel/.config/xfce4/panel/xfce4-sensors-plugin-93.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/xfce4-sensors-plugin-93.rc"

FILE=/etc/skel/.config/xfce4/panel/battery-94.rc
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/battery-94.rc"


mkdir -p /etc/skel/.config/xfce4/panel/launcher-7
cat > /etc/skel/.config/xfce4/panel/launcher-7/geany.desktop << "EOF"
[Desktop Entry]
Type=Application
Version=1.0
Name=Geany
Name[fr]=Geany
GenericName=Integrated Development Environment
GenericName[fr]=Environnement de Développement Intégré
Comment=A fast and lightweight IDE using GTK2
Comment[fr]=Un EDI rapide et léger utilisant GTK2
Exec=geany %F
Icon=geany
Terminal=false
Categories=GTK;Development;IDE;
MimeType=text/plain;text/x-chdr;text/x-csrc;text/x-c++hdr;text/x-c++src;text/x-java;text/x-dsrc;text/x-pascal;text/x-perl;text/x-python;application/x-php;application/x-httpd-php3;application/x-httpd-php4;application/x-httpd-php5;application/xml;text/html;text/css;text/x-sql;text/x-diff;
StartupNotify=true
X-XFCE-Source=file:///usr/share/applications/geany.desktop
EOF
mkdir -p /etc/skel/.config/xfce4/panel/launcher-8
cat > /etc/skel/.config/xfce4/panel/launcher-8/qalculate.desktop << "EOF"
[Desktop Entry]
Name=Qalculate!
Comment=Powerful and easy to use calculator
Exec=qalculate-gtk
Icon=qalculate.png
Terminal=false
Type=Application
StartupNotify=true
Categories=GNOME;Application;Utility;
X-XFCE-Source=file:///usr/share/applications/qalculate-gtk.desktop
EOF
mkdir -p /etc/skel/.config/xfce4/panel/launcher-9
cat > /etc/skel/.config/xfce4/panel/launcher-9/terminator.desktop << "EOF"
[Desktop Entry]
Name=Terminator
Name[fr]=Terminator
Comment=Multiple terminals in one window
Comment[fr]=Plusieurs terminaux dans une fenêtre
TryExec=terminator
Exec=terminator
Icon=terminator
Type=Application
Categories=GNOME;GTK;Utility;TerminalEmulator;
StartupNotify=true
X-Ubuntu-Gettext-Domain=terminator
X-XFCE-Source=file:///usr/share/applications/terminator.desktop
EOF


mkdir -p /etc/skel/.config/xfce4/panel/launcher-14
cat > /etc/skel/.config/xfce4/panel/launcher-14/firefox.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=Firefox
Name[fr]=Firefox
Comment=Browse the World Wide Web
Comment[fr]=Navigue sur Internet
GenericName=Web Browser
GenericName[fr]=Navigateur Web
X-GNOME-FullName=Firefox Web Browser
X-GNOME-FullName[fr]=Navigateur Web Firefox
Exec=firefox %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=firefox
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=Firefox
StartupNotify=true
X-XFCE-Source=file:///usr/share/applications/firefox.desktop
EOF

#background
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-desktop.xml"
sed -i -e "s#%BG%#$BG#g" /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

#shortcuts
FILE=/etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-keyboard-shortcuts.xml"

#xscreensaver avoid using desktop pictures
FILE=/etc/skel/.xscreensaver
[ -e $FILE ] && mv $FILE $FILE.bk
retry "wget -q -O ${FILE} ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xscreensaver"

#disable volumed (replaced by pasystray)
#rm -f /etc/xdg/autostart/xfce4-volumed.desktop
[ ! -e /etc/xdg/autostart/pasystray.desktop ] && ln -s /usr/share/applications/pasystray.desktop /etc/xdg/autostart/pasystray.desktop

############################################
#################  END  ####################
############################################

exit 0
