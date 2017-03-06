#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

echo "   Geany"

PKGS="geany geany-plugins git geany-plugin*"

install_packs "$PKGS"

mkdir -p /etc/skel/.config/geany/
retry "wget -q -O /etc/skel/.config/geany/geany.conf ${SETUP_SCRIPT_LOCATION}/02_apps/geany/geany.conf"


git clone https://github.com/codebrainz/geany-themes.git geany-themes
cp -R geany-themes/colorschemes /usr/share/geany/
rm -rf geany-themes

exit 0

