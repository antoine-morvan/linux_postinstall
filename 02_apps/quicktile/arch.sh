#!/bin/bash

#configure script variables
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh


#setup application
PKGS="python2-six"
AURPKGS="quicktile-git"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"


# add special script to link XDG config dir to /etc/quicktile
cat > /usr/local/bin/quicktile_startup.sh << EOF
#!/bin/bash
export XDG_CONFIG_HOME=/etc/quicktile/
/usr/bin/quicktile --daemonize
EOF
chmod +x /usr/local/bin/quicktile_startup.sh

mkdir -p /etc/xdg/autostart/
mkdir -p /etc/quicktile/

retry "wget -q -O /etc/quicktile/quicktile.cfg ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/quicktile.cfg"
retry "wget -q -O /etc/xdg/autostart/quicktile.desktop ${SETUP_SCRIPT_LOCATION}/02_apps/quicktile/quicktile.desktop"
chmod +x /etc/xdg/autostart/quicktile.desktop

exit

