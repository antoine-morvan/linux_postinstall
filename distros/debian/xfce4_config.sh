#!/bin/bash
BG=`cat setup.dat | head -n 1`
SETUP_SCRIPT_LOCATION=`cat setup.dat | tail -n 1`
[ ! -e func.sh ] &&  wget -q ${SETUP_SCRIPT_LOCATION}/deb/deb_func.sh -O deb_func.sh
source deb_func.sh

echo ""
echo "** Config XFCE 4.10"
echo ""

#get theme
#originated from :
#http://xfce-look.org/CONTENT/content-files/121685-BSM%20Simple%2013.tar.gz
#http://xfce-look.org/CONTENT/content-files/145188-Lines_0.3.1.tar.gz
#http://xfce-look.org/CONTENT/content-files/148171-Adwaita-Fog.tar.gz
mkdir -p /usr/share/themes
(cd /usr/share/themes &&
	retry "wget -q -O 121685-BSM_Simple_13.tar.gz ${SETUP_SCRIPT_LOCATION}/xfce-4.10/121685-BSM_Simple_13.tar" &&	
	retry "wget -q -O 145188-Lines_0.3.1.tar.gz ${SETUP_SCRIPT_LOCATION}/xfce-4.10/145188-Lines_0.3.1.tar.gz" &&
	tar xf 145188-Lines_0.3.1.tar.gz &&
	tar xf 121685-BSM_Simple_13.tar.gz &&
	rm 145188-Lines_0.3.1.tar.gz 121685-BSM_Simple_13.tar.gz)
chmod -R 755 /usr/share/themes

#mkdir -p /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/
#bordures
retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfwm4.xml"
#icons
retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xsettings.xml"

retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-session.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-session.xml"

retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/pointers.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/pointers.xml"

#default icon view & show address bar (Thunar)
mkdir -p /etc/skel/.config/Thunar/
echo "[Configuration]" > /etc/skel/.config/Thunar/thunarrc
echo "LastView=ThunarDetailsView" >> /etc/skel/.config/Thunar/thunarrc
echo "LastLocationBar=ThunarLocationEntry" >> /etc/skel/.config/Thunar/thunarrc

#Thunar user custom actions
retry "wget -q -O /etc/skel/.config/Thunar/uca.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/uca.xml"

#disable thumbs in thunar
retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/thunar.xml"


#mkdir -p /etc/xdg/xfce4/panel/
#default taskbar
retry "wget -q -O /etc/xdg/xfce4/panel/default.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/default-panel.xml"
mkdir -p /etc/skel/.config/xfce4/panel/
retry "wget -q -O /etc/skel/.config/xfce4/panel/xfce4-cpufreq-plugin-6.rc ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/xfce4-cpufreq-plugin-6.rc"
retry "wget -q -O /etc/skel/.config/xfce4/panel/weather-11.rc ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/weather-11.rc"
retry "wget -q -O /etc/skel/.config/xfce4/panel/xfce4-orageclock-plugin-12.rc ${SETUP_SCRIPT_LOCATION}/xfce-4.10/panel/xfce4-orageclock-plugin-12.rc"

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
cat > /etc/skel/.config/xfce4/panel/launcher-14/iceweasel.desktop << "EOF"
[Desktop Entry]
Encoding=UTF-8
Name=Iceweasel
Name[fr]=Iceweasel
Comment=Browse the World Wide Web
Comment[fr]=Navigue sur Internet
GenericName=Web Browser
GenericName[fr]=Navigateur Web
X-GNOME-FullName=Iceweasel Web Browser
X-GNOME-FullName[fr]=Navigateur Web Iceweasel
Exec=iceweasel %u
Terminal=false
X-MultipleArgs=false
Type=Application
Icon=iceweasel
Categories=Network;WebBrowser;
MimeType=text/html;text/xml;application/xhtml+xml;application/xml;application/vnd.mozilla.xul+xml;application/rss+xml;application/rdf+xml;image/gif;image/jpeg;image/png;x-scheme-handler/http;x-scheme-handler/https;
StartupWMClass=Iceweasel
StartupNotify=true
X-XFCE-Source=file:///usr/share/applications/iceweasel.desktop
EOF

#background
retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-desktop.xml"
sed -i -e "s#%BG%#$BG#g" /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml

#shortcuts
retry "wget -q -O /etc/xdg/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xfce4-keyboard-shortcuts.xml"

#xscreensaver avoid using desktop pictures
retry "wget -q -O /etc/skel/.xscreensaver ${SETUP_SCRIPT_LOCATION}/xfce-4.10/xscreensaver"

#disable volumed (replaced by pasystray)
rm -f /etc/xdg/autostart/xfce4-volumed.desktop

############################################
#################  END  ####################
############################################
exit 0