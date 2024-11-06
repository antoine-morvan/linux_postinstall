
# the iface of the "outside"
WEBIFACE=eth0
# the iface of the LAN it will serve
LANIFACE=eth1

# network and mask of the LAN
DOMAIN_NAME=diablan

LANNET=172.29.0.0/24
SERVERLANIP=172.29.255.254
DHCP_RANGE=172.29.255.10:172.29.255.200

SUDOUSER=koubi

# overide hostname: if set, change hostname
# HOSTNAME_OVERRIDE="gwtest"