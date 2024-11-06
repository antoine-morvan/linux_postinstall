#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## TODO
############################################################################################


echo "[INFO] Setup DNS"
## setup DNS

case $GEN_CONFIG in
  YES) BIND_FOLDER=.          ;;
  *)   BIND_FOLDER=/etc/bind/ ;;
esac

cat > ${BIND_FOLDER}/named.conf.options << EOF
options {
  directory "/var/cache/bind";

  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  allow-query-cache { any; };

  forwarders {
EOF

for dns in $EXTERNALDNSLIST; do
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

cat >> ${BIND_FOLDER}/named.conf.local  << EOF

zone "${DOMAIN_NAME}" {
    type master;
    file "${BIND_FOLDER}/db.${DOMAIN_NAME}";
};

EOF
cat >> ${BIND_FOLDER}/db.${DOMAIN_NAME} << EOF
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
;your sites
EOF

ZONES=""
# Add reverse for router
IP_ZONE=$(echo $SERVERLANIP |cut -d'.' -f-3)
LAST_DIGIT=$(echo $SERVERLANIP |cut -d'.' -f4)
ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
if [ ! -f $ZONE_FILE ]; then
  ZONES+=" $IP_ZONE"
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
fi
echo "$LAST_DIGIT PTR $HOSTNAME.$DOMAIN_NAME." >> $ZONE_FILE

# Add reverse for fixed hosts
for FixedIP in $FIXED_IPS; do
  MAC=$(echo $FixedIP | rev | cut -d':' -f3- | rev )
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  NAME=$(echo $FixedIP | rev | cut -d':' -f1 | rev )
  echo "$NAME.$DOMAIN_NAME. IN A $IP" >> ${BIND_FOLDER}/db.${DOMAIN_NAME}

  IP_ZONE=$(echo $IP |cut -d'.' -f-3)
  LAST_DIGIT=$(echo $IP |cut -d'.' -f4)
  ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
  if [ ! -f $ZONE_FILE ]; then
    ZONES+=" $IP_ZONE"
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
  fi
  echo "$LAST_DIGIT PTR $NAME.$DOMAIN_NAME." >> $ZONE_FILE
done

for ZONE in $ZONES; do
  ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
  REV_ZONE=$(echo $ZONE | cut -d'.' -f3).$(echo $ZONE | cut -d'.' -f2).$(echo $ZONE | cut -d'.' -f1)
  cat >> ${BIND_FOLDER}/named.conf.local  << EOF
zone "${REV_ZONE}.in-addr.arpa" {
    type master;
    file "${ZONE_FILE}";
};
EOF
done
