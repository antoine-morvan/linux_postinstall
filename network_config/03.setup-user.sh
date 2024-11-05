#!/usr/bin/env bash
set -eu -o pipefail

# Check that we can source config
source config.sh

case $ID_LIKE in
    *debian*|*ubuntu*)
        usermod -aG sudo ${SUDOUSER}
        ;;
    *fedora*|*rhel*)
        usermod -aG wheel ${SUDOUSER}
        ;;
esac

exit 0
