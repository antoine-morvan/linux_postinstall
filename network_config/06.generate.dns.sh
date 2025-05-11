#!/usr/bin/env bash
set -eu -o pipefail

############################################################################################
## Load config
############################################################################################

source config.sh

############################################################################################
## Generate DNS config
############################################################################################

echo "[NETCONF] INFO    :: Generate DNS"

## setup DNS

# case $GEN_CONFIG in
#   YES) BIND_FOLDER=.          ;;
#   *)   BIND_FOLDER=/etc/bind/ ;;
# esac

BIND_FOLDER=./gen.bind
mkdir -p $BIND_FOLDER

###########################
## named.conf.options
###########################

echo "[NETCONF] INFO    ::  - named.conf.options"
cat > ${BIND_FOLDER}/named.conf.options << EOF
options {
  directory "/var/cache/bind";

  recursion yes;
  allow-query { any; };
  allow-recursion { any; };
  allow-query-cache { any; };

  forwarders {
EOF

HOST_DNS_LIST=$(cat /etc/resolv.conf | grep nameserver| sed -r 's/nameserver\s+//g' | grep -v '^127.' | xargs)
case ${USE_HOST_DNS:-NO} in
  YES|APPEND) DNS_LIST="${DNS_LIST} ${HOST_DNS_LIST}" ;;
  PREPEND)    DNS_LIST="${HOST_DNS_LIST} ${DNS_LIST}" ;;
  ONLY)       DNS_LIST="${HOST_DNS_LIST}" ;;
  *) : ;; # use dns list from config
esac

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

# disabled until further testing
false && (
  cat >> ${BIND_FOLDER}/named.conf.options << EOF
logging {
    channel default_file {
        file "/var/log/named/default.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel general_file {
        file "/var/log/named/general.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel database_file {
        file "/var/log/named/database.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel security_file {
        file "/var/log/named/security.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel config_file {
        file "/var/log/named/config.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel resolver_file {
        file "/var/log/named/resolver.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel xfer-in_file {
        file "/var/log/named/xfer-in.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel xfer-out_file {
        file "/var/log/named/xfer-out.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel notify_file {
        file "/var/log/named/notify.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel client_file {
        file "/var/log/named/client.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel unmatched_file {
        file "/var/log/named/unmatched.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel queries_file {
        file "/var/log/named/queries.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel network_file {
        file "/var/log/named/network.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel update_file {
        file "/var/log/named/update.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel dispatch_file {
        file "/var/log/named/dispatch.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel dnssec_file {
        file "/var/log/named/dnssec.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };
    channel lame-servers_file {
        file "/var/log/named/lame-servers.log" versions 3 size 5m;
        severity dynamic;
        print-time yes;
        print-category yes;
        print-severity yes;
    };

    category client { client_file; };
    category config { config_file; };
    category default { default_file; };
    category general { general_file; };
    category database { database_file; };
    category security { security_file; };
    category resolver { resolver_file; };
    category xfer-in { xfer-in_file; };
    category xfer-out { xfer-out_file; };
    category notify { notify_file; };
    category unmatched { unmatched_file; };
    category queries { queries_file; };
    category network { network_file; };
    category update { update_file; };
    category dispatch { dispatch_file; };
    category dnssec { dnssec_file; };
    category lame-servers { lame-servers_file; };
    category rate-limit { general_file; };
    category rpz { general_file; };
    category update-security { update_file; };
};
EOF
  mkdir -p /var/log/named/
  chmod a+rwx /var/log/named/
)

###########################
## db.domain init
###########################

echo "[NETCONF] INFO    ::  - init db.${DOMAIN_NAME}"
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

echo "[NETCONF] INFO    ::  - init reverse zones"
ZONES="%"
for FixedIP in "NAME:$SERVERLANIP:MAC" $FIXED_IPS; do
  IP=$(echo $FixedIP | rev | cut -d':' -f2 | rev )
  IP_ZONE=$(echo $IP |cut -d'.' -f-3)
  case $ZONES in
    *%${IP_ZONE}%*) : ;; # zone alredy listed & initialized
    *)
      ZONE_FILE=${BIND_FOLDER}/db.$IP_ZONE
      echo "[NETCONF] INFO    ::    > db.$IP_ZONE"
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

echo "[NETCONF] INFO    ::  - Add names and reverse"

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

case ${ID_LIKE:-${ID}} in
    *fedora*|*rhel*)*
      echo "[NETCONF] ERROR   :: unsupported DNS server on rhel like systems"
      exit 1
      ;;
esac
SYSTEM_BIND_FOLDER=/etc/bind

echo "[NETCONF] INFO    ::  - named.conf.local"
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
echo "[NETCONF] INFO    :: Generate DNS Done."
exit 0
