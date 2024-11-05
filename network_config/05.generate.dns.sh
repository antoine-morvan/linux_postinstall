#!/usr/bin/env bash
set -eu -o pipefail

# Check that we can source config
source config.sh

SUDOUSER=${SUDOUSER:-admin}


set +e
cat /etc/passwd | grep ^${SUDOUSER}: &> /dev/null
RES=$?
set -e
if [ $RES != 0 ]; then
    useradd \
        -d /home/${SUDOUSER} \
        -m \
        ${SUDOUSER}

fi

case $ID_LIKE in
    *debian*|*ubuntu*)
        usermod -aG sudo ${SUDOUSER}
        ;;
    *fedora*|*rhel*)
        usermod -aG wheel ${SUDOUSER}
        ;;
esac

exit 0
