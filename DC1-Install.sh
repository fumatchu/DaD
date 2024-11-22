#!/bin/bash
#DC1-install.sh
#This script installs ANY ADDITIONAL INSTANCE of Samba AD (Secondary/Tertiary Server) with DC support using mock from Upstream Rocky REPO via src.rpm
clear
dnf -y install net-tools dmidecode
TEXTRESET=$(tput sgr0)
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
INTERFACE=$(nmcli | grep "connected to" | cut -d " " -f4)
DETECTIP=$(nmcli -f ipv4.method con show $INTERFACE)
FQDN=$(hostname)
IP=$(hostname -I)
DOMAIN=$(hostname | sed 's/^[^.:]*[.:]//' | sed -e 's/\(.*\)/\U\1/')
ADDOMAIN=$(hostname | sed 's/^[^.:]*[.:]//' | cut -d. -f1 | sed -e 's/\(.*\)/\U\1/')
REVERSE=$(echo "$IP" | {
  IFS=. read q1 q2 q3 q4
  echo "$q3.$q2.$q1"
})
MOCKSMBVER=$(dnf provides samba | grep samba | sed '2,4d' | cut -d: -f1 | cut -dx -f1)
MAJOROS=$(cat /etc/redhat-release | grep -Eo "[0-9]" | sed '$d')
MINOROS=$(cat /etc/redhat-release | grep -Eo "[0-9]" | sed '1d')
USER=$(whoami)
DHCPNSNAME=$(hostname | sed 's/^[^.:]*[.:]//')
SUBNETNETWORK=$(echo "$IP" | {
  IFS=. read q1 q2 q3 q4
  echo "$q1.$q2.$q3.0"
})
NMCLIIP=$(nmcli | grep inet4 | sed '$d'| cut -c7- |cut -d / -f1)
HWKVM=$(dmidecode | grep -i -e manufacturer -e product -e vendor | grep KVM | cut -c16-)
HWVMWARE=$(dmidecode | grep -i -e manufacturer -e product -e vendor | grep Manufacturer | grep "VMware, Inc." | cut -c16- | cut -d , -f1)
n='([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])'
m='([0-9]|[12][0-9]|3[012])'
#Bracketed pasting...yuck!
sed -i '8i set enable-bracketed-paste off' /etc/inputrc
#Checking for user permissions
if [ "$USER" = "root" ]; then
  echo " "
else
  echo ${RED}"This program must be run as root ${TEXTRESET}"
  echo "Exiting"
fi
#Checking for version Information
if [ "$MAJOROS" = "9" ]; then
  echo " "
else
  echo ${RED}"Sorry, but this installer only works on Rocky 9.X ${TEXTRESET}"
  echo "Please upgrade to ${GREEN}Rocky 9.x${TEXTRESET}"
  echo "Exiting the installer..."
  exit
fi
clear
#Detect Static or DHCP (IF not Static, change it)
cat <<EOF
Checking for static IP Address
EOF
sleep 1s

if [ -z "$INTERFACE" ]; then
  "Usage: $0 <interface>"
  exit 1
fi

if [ "$DETECTIP" = "ipv4.method:                            auto" ]; then
  echo ${RED}"Interface $INTERFACE is using DHCP${TEXTRESET}"
 read -p "Please provide a static IP address in CIDR format (i.e 192.168.24.2/24): " IPADDR
  while [ -z "$IPADDR" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide a static IP address in CIDR format (i.e 192.168.24.2/24): " IPADDR
  done
  while [[ ! $IPADDR =~ ^$n(\.$n){3}/$m$ ]]; do
    read -p ${RED}"The entry is not in valid CIDR notation. Please Try again:${TEXTRESET} " IPADDR
done
  read -p "Please Provide a Default Gateway Address: " GW
  while [ -z "$GW" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please Provide a Default Gateway Address: " GW
  done
  read -p "Please provide the FQDN for this machine: " HOSTNAME
  while [ -z "$HOSTNAME" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the FQDN for this machine: " HOSTNAME
  done
  read -p "Please provide the IP address of the primary AD server: " DNSSERVER
  while [ -z "$DNSSERVER" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the IP address of the primary AD server: " DNSSERVER
  done
  read -p "Please provide the domain search name: " DNSSEARCH
  while [ -z "$DNSSEARCH" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the domain search name: " DNSSEARCH
  done
  clear
  cat <<EOF
The following changes to the system will be configured:
IP address: ${GREEN}$IPADDR${TEXTRESET}
Gateway: ${GREEN}$GW${TEXTRESET}
DNS Search: ${GREEN}$DNSSEARCH${TEXTRESET}
DNS Server: ${GREEN}$DNSSERVER${TEXTRESET}
HOSTNAME: ${GREEN}$HOSTNAME${TEXTRESET}
EOF
  read -p "Press any Key to Continue"
  nmcli con mod $INTERFACE ipv4.address $IPADDR
  nmcli con mod $INTERFACE ipv4.gateway $GW
  nmcli con mod $INTERFACE ipv4.method manual
  nmcli con mod $INTERFACE ipv4.dns-search $DNSSEARCH
  nmcli con mod $INTERFACE ipv4.dns $DNSSERVER
  hostnamectl set-hostname $HOSTNAME
  cat <<EOF
The System must reboot for the changes to take effect. 
${RED}Please log back in as root.${TEXTRESET}
The installer will continue when you log back in.
If using SSH, please use the IP Address: $IPADDR

EOF
  read -p "Press Any Key to Continue"
  clear
  echo "/root/ADDCInstaller/DC1-Install.sh" >>/root/.bash_profile
  reboot
  exit
else
  echo ${GREEN}"Interface $INTERFACE is using a static IP address ${TEXTRESET}"
fi
if [ "$FQDN" = "localhost.localdomain" ]; then
  cat <<EOF
${RED}This system is still using the default hostname (localhost.localdomain)${TEXTRESET}

EOF
  read -p "Please provide a valid FQDN for this machine: " HOSTNAME
  while [ -z "$HOSTNAME" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide a valid FQDN for this machine: " HOSTNAME
  done
  hostnamectl set-hostname $HOSTNAME
  cat <<EOF
The System must reboot for the changes to take effect. 
${RED}Please log back in as root.${TEXTRESET}
The installer will continue when you log back in.
If using SSH, please use the IP Address: ${NMCLIIP}

EOF
  read -p "Press Any Key to Continue"
  clear
  echo "/root/ADDCInstaller/DC1-Install.sh" >>/root/.bash_profile
  reboot
  exit
fi

clear
cat <<EOF
*********************************************
${GREEN}This will Install another AD Server to a pre-existing Forest/Domain${TEXTRESET}

Checklist:
Before the Installer starts, please make sure you have the following information

    1. ${YELLOW}THE FQDN of the Pre-existing DC ${TEXTRESET}
    2. ${YELLOW}An Administrator password${TEXTRESET} that you will use to join the domain
    3. ${YELLOW}An NTP Subnet${TEXTRESET} for your clients. This server will provide syncronized time
    4. The ${YELLOW}beginning and ending lease range${TEXTRESET} for DHCP (optional)
    5. The ${YELLOW}client default gateway IP Address${TEXTRESET} for the DHCP Scope (optional)
    6. A ${YELLOW}Friendly name${TEXTRESET} as a description to the DHCP scope created (optional



*********************************************
EOF
read -p "Press Any Key to Continue or Ctrl-C to exit the Installer"
clear

cat <<EOF
${GREEN}Samba AD/DC Setup${TEXTRESET}
EOF
 read -p "Please provide the (pre-existing) AD Server FQDN that we will use to join the (pre-existing) domain: " ADDC
  while [ -z "$ADDC" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
     read -p "Please provide the (pre-existing) AD Server FQDN that we will use to join the (pre-existing) domain: " ADDC
  done

read -p "Please provide the appropriate network scope in CIDR format (i.e 192.168.0.0/16) to allow NTP for clients: " NTPCIDR
while [ -z "$NTPCIDR" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
     read -p "Please provide the appropriate network scope in CIDR format (i.e 192.168.0.0/16) to allow NTP for clients: " NTPCIDR
  done
  
clear
#OPTIONAL DHCP Installation
cat <<EOF
${GREEN}DHCP Server Setup${TEXTRESET}

This server can be a DHCP server to service clients.
The installer will prompt you to create a default declaration for its interface
If you want to add additional scopes, use Server Management after installation

EOF

read -r -p "Would you like to install/enable DHCP and create a default scope? [y/N]" -n 1
echo # (optional) move to a new line
if [[ "$REPLY" =~ ^[Yy]$ ]]; then
  echo ${GREEN}"Installing DHCP Server${TEXTRESET}"
  sleep 1
  dnf -y install dhcp-server
  firewall-cmd --zone=public --add-service dhcp --permanent
  clear

   read -p "Please provide the beginning IP address in the lease range (based on the network $SUBNETNETWORK): " DHCPBEGIP
  while [ -z "$DHCPBEGIP" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the beginning IP address in the lease range (based on the network $SUBNETNETWORK): " DHCPBEGIP
  done

  read -p "Please provide the ending IP address in the lease range (based on the network $SUBNETNETWORK): " DHCPENDIP
  while [ -z "$DHCPENDIP" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the ending IP address in the lease range (based on the network $SUBNETNETWORK): " DHCPENDIP
  done
   read -p "Please provide the netmask for clients: " DHCPNETMASK
  while [ -z "$DHCPNETMASK" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the default netmask for clients: " DHCPNETMASK
  done
  read -p "Please provide the default gateway for clients: " DHCPDEFGW
  while [ -z "$DHCPDEFGW" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
    read -p "Please provide the default gateway for clients: " DHCPDEFGW
  done

  read -p "Please provide a description for this subnet: " SUBNETDESC
  while [ -z "$SUBNETDESC" ]; do
    echo ${RED}"The response cannot be blank. Please Try again${TEXTRESET}"
     read -p "Please provide a description for this subnet: " SUBNETDESC
  done

  #Configure DHCP
  mv /etc/dhcp/dhcpd.conf /etc/dhcp/dhcpd.conf.orig

  cat <<EOF >/etc/dhcp/dhcpd.conf

authoritative;
allow unknown-clients;
option ntp-servers ${IP};
option time-servers ${IP};
option domain-name-servers ${IP};
option domain-name "${DHCPNSNAME}";
option domain-search "${DHCPNSNAME}";


#$SUBNETDESC
subnet ${SUBNETNETWORK} netmask ${DHCPNETMASK} {
        range ${DHCPBEGIP} ${DHCPENDIP};
        option subnet-mask ${DHCPNETMASK};
        option routers ${DHCPDEFGW};
}
EOF

  systemctl enable dhcpd
  systemctl start dhcpd

fi

clear
#Add option for cockpit install
cat <<EOF
${GREEN}Install Cockpit${TEXTRESET}
Cockpit is a server administration tool, focused on providing a modern-looking 
and user-friendly interface to manage and administer servers.
EOF

read -r -p "Would you like to install Cockpit for web based administration? [y/N]" -n 1
echo # (optional) move to a new line
if [[ "$REPLY" =~ ^[Yy]$ ]]; then

    echo ${YELLOW}"Your cockpit instance can be accessed at ${FQDN}:9090"${TEXTRESET}
    sleep 5
    dnf -y install cockpit cockpit-storaged
    systemctl enable cockpit.socket
    systemctl start cockpit.socket
fi
clear
cat <<EOF
${GREEN}Deploying the server with these settings${TEXTRESET}

The installer will deploy Samba AD with the following information:

DOMAIN to Join: ${GREEN}$DOMAIN${TEXTRESET}
NTP Client Scope: ${GREEN}$NTPCIDR${TEXTRESET}



EOF
read -p "Press any Key to continue or Ctrl-C to Exit"
clear

#Checking for VM platform-Install client
echo ${GREEN}"Installing VMGuest${TEXTRESET}"
if [ "$HWKVM" = "KVM" ]; then
  echo ${GREEN}"KVM Platform detected ${TEXTRESET}"
  echo "Installing qemu-guest-agent"
  sleep 1
  dnf -y install qemu-guest-agent
else
  echo "Not KVM Platform"
fi

#Checking for VM platform-Install client
if [ "$HWVMWARE" = "VMware" ]; then
  echo ${GREEN}"VMWARE Platform detected ${TEXTRESET}"
  echo "Installing open-vm-tools"
  sleep 1
  dnf -y install open-vm-tools
else
  echo "Not VMware Platform"
fi
clear
#If this server got DHCP, and there is an NTP server option, we must change it to a pool
sed -i "/pool /c\server ${ADDC} iburst" /etc/chrony.conf
sed -i "/server /c\server ${ADDC} iburst" /etc/chrony.conf
sed -i "/#allow /c\allow ${NTPCIDR}" /etc/chrony.conf
systemctl restart chronyd
clear
echo ${RED}"Syncronizing time, Please wait${TEXTRESET}"
sleep 10s
clear
chronyc tracking
cat <<EOF
${GREEN}We should be syncing time${TEXTRESET}

The Installer will continue in a moment or Press Ctrl-C to Exit
EOF
sleep 5s
clear
#Set selinux contexts
setsebool -P samba_create_home_dirs=on \
  samba_domain_controller=on \
  samba_enable_home_dirs=on \
  samba_portmapper=on \
  use_samba_home_dirs=on
#Apply Firewall Rules
cat <<EOF
Updating Firewall Rules
EOF
firewall-cmd --permanent --add-service samba-dc
firewall-cmd --permanent --add-service ntp
firewall-cmd --complete-reload
systemctl restart firewalld
clear
echo ${GREEN}"These are the services/ports now open on the server${TEXTRESET}"
firewall-cmd --list-all
echo "The Installer will continue in a moment or Press Ctrl-C to Exit"
sleep 8s
clear
cat <<EOF
${GREEN}Downloading and compiling the Samba source from Rocky --with dc${TEXTRESET}
${YELLOW}This may take approximately 20-30 minutes${TEXTRESET}
EOF
sleep 4s
dnf -y install ntsysv nano bind-utils
dnf -y update
# Initial build
dnf install epel-release createrepo -y
crb enable
dnf install mock -y
dnf download samba --source
mock -r rocky-"$MAJOROS"-x86_64 --enablerepo=devel --define 'dist .el'"$MAJOROS"'_'"$MINOROS"'.dc' --with dc "$MOCKSMBVER"src.rpm
mkdir /root/.samba
cp /var/lib/mock/rocky-"$MAJOROS"-x86_64/result/*.rpm /root/.samba
createrepo /root/.samba
dnf config-manager --add-repo /root/.samba
dnf -y install --nogpgcheck samba-dc samba-client krb5-workstation samba \
  --repofrompath=samba,/root/.samba \
  --enablerepo=samba
#Move smb.conf file
mv -f /etc/samba/smb.conf /etc/samba/smb.bak.orig

#Create KDC:
#sed -i '12i \       \ dns_lookup_kdc = true' /etc/krb5.conf
#sed -i "s/#    default_realm = EXAMPLE.COM/default_realm = ${DOMAIN}/" /etc/krb5.conf

#Provision Domain
cat <<EOF
Joining the Domain

EOF
read -p "Press Any Key when Ready"
samba-tool domain join ${DOMAIN} DC -U "${ADDOMAIN}\administrator"
read -p "Press Any Key"

#Set DNS resolver
nmcli con mod $INTERFACE ipv4.dns $IP
systemctl restart NetworkManager

#Copy KDC:
\cp -rf /var/lib/samba/private/krb5.conf /etc/krb5.conf

#Add support for FreeRADIUS
sed -i '7i \       \ #Added for FreeRADIUS Support' /etc/samba/smb.conf
sed -i '8i \       \ ntlm auth = mschapv2-and-ntlmv2-only' /etc/samba/smb.conf

#Allow plain LDAP binds
sed -i '9i \       \#ldap server require strong auth = no #UNCOMMENT THIS IF YOU NEED PLAIN LDAP BIND (non-TLS)' /etc/samba/smb.conf
sed -i '10i \       \dns forwarder = 208.67.222.222' /etc/samba/smb.conf

#ADD cron for monitoring of REPOS
touch /var/log/dnf-smb-mon.log
chmod 700 /root/ADDCInstaller/dnf-smb-mon
\cp /root/ADDCInstaller/dnf-smb-mon /usr/bin
(
  crontab -l
  echo "0 */6 * * * /usr/bin/dnf-smb-mon"
) | sort -u | crontab -
systemctl restart crond

#ADD samba-dnf-package update
chmod 700 /root/ADDCInstaller/samba-dnf-pkg-update
\cp /root/ADDCInstaller/samba-dnf-pkg-update /usr/bin
systemctl enable samba --now
clear

#Update /etc/issue so we can see the hostname and IP address Before logging in
rm -r -f /etc/issue
touch /etc/issue
cat <<EOF >/etc/issue
\S
Kernel \r on an \m
Hostname: \n
IP Address: \4
EOF

#Run tests to validate Samba Install
cat <<EOF
${GREEN}Validation${TEXTRESET}

The server will now test
  -Kerberos (Ticket)
  -DNS SRV Records
  -Anonymous Logins
  -Authenticated Logins


The Installer will continue in a moment or Press Ctrl-C to Exit
EOF
sleep 15s
clear

cat <<EOF
${GREEN}Kerberos${TEXTRESET}
Login with the Administrator password you created earlier for the domain
EOF
kinit Administrator
echo ${GREEN}
klist
echo ${TEXTRESET}
echo "The Installer will continue in a moment or Press Ctrl-C to Exit"
sleep 10s
clear

cat <<EOF
${GREEN}Checking DNS SRV Records${TEXTRESET}

Testing _ldap._tcp
Example Result:
${YELLOW}_ldap._tcp.samdom.example.com has SRV record 0 100 389 dc1.samdom.example.com.${TEXTRESET}

The actual result is:
EOF
echo ${GREEN}
host -t SRV _ldap._tcp.$DOMAIN.
echo ${TEXTRESET}

cat <<EOF
Testing _udp kerberos
Example Result:
${YELLOW}_kerberos._udp.samdom.example.com has SRV record 0 100 88 dc1.samdom.example.com.${TEXTRESET}

The actual result is:
EOF
echo ${GREEN}
host -t SRV _kerberos._udp.$DOMAIN.
echo ${TEXTRESET}

cat <<EOF

Testing A Record of Domain Controller
Example Result:
${YELLOW}dc1.samdom.example.com has address 10.99.0.1${TEXTRESET}

The actual result is:
EOF
echo ${GREEN}
host -t A $FQDN.
echo ${TEXTRESET}
cat <<EOF

The Installer will continue in a moment or Press Ctrl-C to Exit
EOF
sleep 20s
clear

cat <<EOF
${GREEN}Testing anonymous Logins to the server${TEXTRESET}
EOF
smbclient -L localhost -N
sleep 8s
clear

cat <<EOF
${GREEN}Verifying Authentication Login:${TEXTRESET}
EOF
smbclient //localhost/netlogon -UAdministrator -c 'ls'
sleep 8
clear
cat <<EOF
${GREEN}Providing replication Status${TEXTRESET}
EOF
sleep 2
samba-tool drs showrepl | more
sleep 1s
clear

echo "If all tests returned valid, installation is successful"
sleep 4
clear

cat <<EOF
${GREEN}********************************
  Server Installation Complete
********************************${TEXTRESET}

The Installer will continue in a moment

${YELLOW}Getting Ready to install Server Management${TEXTRESET}

EOF

sleep 5

#Cleanup RADS Install Files
sed -i '/DC1-Install.sh/d' /root/.bash_profile
rm -r -f /root/DC-Installer.sh
rm -r -f /root/ADDCInstaller
rm -f /root/samba*.src.rpm
rm -r -f /root/FR-Installer
rm -r -f /root/FR-Installer.sh

cat <<EOF
${GREEN}******************************
Installing Server Management
******************************${TEXTRESET}

EOF

cd /root/
dnf -y install wget
wget https://raw.githubusercontent.com/fumatchu/RADS-SM/main/RADS-FirstInstaller.sh
chmod 700 ./RADS-FirstInstaller.sh
/root/RADS-FirstInstaller.sh
