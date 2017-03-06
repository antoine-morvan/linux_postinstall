#!/bin/bash
BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

echo ""
echo "** Setup Conky"
echo ""

upgrade
install_packs lvm2 conky

dl_and_execute ${SETUP_SCRIPT_LOCATION}/02_apps/conky/conky_config.sh
