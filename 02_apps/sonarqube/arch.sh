#!/bin/bash -eu

BG=`cat /setup.dat | sed '1q;d'`
SETUP_SCRIPT_LOCATION=`cat /setup.dat | sed '2q;d'`
TESTSYSTEM=`cat /setup.dat | sed '3q;d'`
INSTALLHEAD=`cat /setup.dat | sed '4q;d'`
source /arch_func.sh

PKGS=""
AURPKGS="sonarqube"

install_packs "$PKGS"
install_packs_aur "$AURPKGS"

CONFFILE=/etc/sonarqube/sonar.properties
SONAR_PORT=9081


cat ${CONFFILE} | sed -e "s/#\(sonar\.web\.port=\).*/\1${SONAR_PORT}/g" > tmp
mv tmp ${CONFFILE}

#systemctl enable sonarqube.service

exit
