#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate DNS config
############################################################################################

echo "[NETCONF] INFO: Generate DNS"

## setup DNS

# case $GEN_CONFIG in
#   YES) BIND_FOLDER=.          ;;
#   *)   BIND_FOLDER=/etc/bind/ ;;
# esac

BIND_FOLDER=./gen.bind/
mkdir -p $BIND_FOLDER

###########################
## named.conf.options
###########################

echo "[NETCONF] INFO:  - named.conf.options"
cat > ${BIND_FOLDER}/named.conf.options << EOF
options {
  directory "/var/cache/bind";

  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  allow-query-cache { any; };

  forwarders {
EOF

for dns in $DNS_LIST; do
cat >> ${BIND_FOLDER}/named.conf.options << EOF
    $dns;
EOF
done
cat >> ${BIND_FOLDER}/named.conf.options << EOF
  };

  dnssec-validation auto;

  auth-nxdomain no;
  listen-on-v6 { any; };
  listen-on { any; };
};
EOF

###########################
## db.domain init
###########################

echo "[NETCONF] INFO:  - init db.${DOMAIN_NAME}"
cat > ${BIND_FOLDER}/db.${DOMAIN_NAME} << EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME.$DOMAIN_NAME. root.$HOSTNAME.$DOMAIN_NAME. (
                              2         ; Serial
                         604800         ; Refresh
                          86400         ; Retry
                        2419200         ; Expire
                         604800 )       ; Negative Cache TTL
;
@       IN      NS      $HOSTNAME.$DOMAIN_NAME.
@       IN      A       127.0.0.1

localhost.$DOMAIN_NAME. IN A 127.0.0.1
$HOSTNAME.$DOMAIN_NAME. IN A ${SERVERLANIP}

EOF

###########################
## zone files init
###########################

echo "[NETCONF] INFO:  - init reverse zones"
ZONES="%"
for FixedIP in "NAME:$SERVERLANIP:MAC" $FIXED_IPS; do
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  IP_ZONE=$(echo $IP |cut -d'.' -f-3)
  case $ZONES in
    *%${IP_ZONE}%*) : ;; # zone alredy listed & initialized
    *)
      ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
      echo "[NETCONF] INFO:    > db.$IP_ZONE"
      cat > $ZONE_FILE << EOF
\$TTL    604800
@       IN      SOA     $HOSTNAME.$DOMAIN_NAME. root.$HOSTNAME.$DOMAIN_NAME. (
                            2         ; Serial
                        604800         ; Refresh
                        86400         ; Retry
                      2419200         ; Expire
                        604800 )       ; Negative Cache TTL
      NS      $HOSTNAME.$DOMAIN_NAME.
EOF
      ZONES+="${IP_ZONE}%"
      ;;
  esac
done
ZONES=${ZONES//%/ }

###########################
## gen db
###########################

echo "[NETCONF] INFO:  - Add names and reverse"

# Add reverse for router
IP_ZONE=$(echo $SERVERLANIP |cut -d'.' -f-3)
LAST_DIGIT=$(echo $SERVERLANIP |cut -d'.' -f4)
ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
echo "$LAST_DIGIT PTR $HOSTNAME.$DOMAIN_NAME." >> $ZONE_FILE

for FixedIP in $FIXED_IPS; do
  # Add name for fixed hosts
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  echo "$NAME.$DOMAIN_NAME. IN A $IP" >> ${BIND_FOLDER}/db.${DOMAIN_NAME}

  # Add reverse for fixed hosts
  IP_ZONE=$(echo $IP |cut -d'.' -f-3)
  LAST_DIGIT=$(echo $IP |cut -d'.' -f4)
  ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
  echo "$LAST_DIGIT PTR $NAME.$DOMAIN_NAME." >> $ZONE_FILE
done

###########################
## named.conf.local
###########################

SYSTEM_BIND_FOLDER=/etc/bind

echo "[NETCONF] INFO:  - named.conf.local"
cat > ${BIND_FOLDER}/named.conf.local  << EOF

zone "${DOMAIN_NAME}" {
    type master;
    file "${SYSTEM_BIND_FOLDER}/db.${DOMAIN_NAME}";
};

EOF

for ZONE in $ZONES; do
  ZONE_FILE=${SYSTEM_BIND_FOLDER}/db.$IP_ZONE
  REV_ZONE=$(echo $ZONE | cut -d'.' -f3).$(echo $ZONE | cut -d'.' -f2).$(echo $ZONE | cut -d'.' -f1)
  cat >> ${BIND_FOLDER}/named.conf.local  << EOF
zone "${REV_ZONE}.in-addr.arpa" {
    type master;
    file "${ZONE_FILE}";
};
EOF
done

############################################################################################
## Exit
############################################################################################
echo "[NETCONF] INFO: Generate DNS Done."
exit 0
