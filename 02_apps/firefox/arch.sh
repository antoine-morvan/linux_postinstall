#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS="firefox firefox-i18n-fr firefox-adblock-plus firefox-noscript flashplugin icedtea-web"
# failing : link obsolete ...
#AURPKGS="firefox-extension-useragentswitcher"
AURPKGS=""
# firefox-flashblock firefox-extension-video-downloadhelper
install_packs "$PKGS"
install_packs_aur "$AURPKGS"

exit

