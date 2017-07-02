#!/bin/bash

usage(){
echo -e "Usage:
\tsh $0\t\t\t\t\t: To loop For The Deleted Zones From The cPanel Error Log
\tsh $0 --domain {DOMAIN}\t\t: To Process One Domain {DOMAIN}
\tsh $0 --all\t\t\t\t: To Loop For All Domains On The Server."
}
sendmail(){
	if [ -f "/root/dnscheck/log.$$" ]; then
		cat /root/dnscheck/log.$$ | mail -s "DNSCheck script Run On: `hostname` to restore unexpectedly deleted Zones" -r root@`hostname` servers@murabba.com
	fi
}
synczone(){
	domain="$1"
	result=`/scripts/dnscluster synczonelocal ${domain} | head -1`
	if [ "${result}" == "Syncing ${domain} to local machine...Domain “${domain}” could not be found." ]; then
		echo "Failed to Sync Domain: ${domain} from Cluster"
	fi
}
uninstallSPFandDKeyID(){
	user="$1"
	/usr/local/cpanel/bin/dkim_keys_uninstall ${user}
	/usr/local/cpanel/bin/spf_uninstaller ${user}
}

installSPFandDKeyIDandSetTTL(){
	user="$1"
	/usr/local/cpanel/bin/dkim_keys_install ${user} && echo "Adding/Updating DKim_Key Records"
	/usr/local/cpanel/bin/spf_installer ${user} && echo "Adding/Updating SPF Records"
	/usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300 >/dev/null && echo "Setting the TTL for the domain to 300"
}

restoreZoneFromBackup(){
	domain="$1"
	user="$2"
	echo "Trying To Restore the Zone File From The Most Recent Backup"
	if [ -f "/backup/cpbackup/daily/dirs/_var_named/${domain}.db" ]; then
		cp -pv /backup/cpbackup/daily/dirs/_var_named/${domain}.db /var/named/${domain}.db
	elif [ -f "/backup/cpbackup/weekly/dirs/_var_named/${domain}.db" ]; then
		cp -pv /backup/cpbackup/weekly/dirs/_var_named/${domain}.db /var/named/${domain}.db
	elif [ -f "/backup/cpbackup/monthly/dirs/_var_named/${domain}.db" ]; then
		cp -pv /backup/cpbackup/monthly/dirs/_var_named/${domain}.db /var/named/${domain}.db
	fi
	if [ -f /var/named/${domain}.db ]; then
		uninstallSPFandDKeyID ${user}
		installSPFandDKeyIDandSetTTL ${user}
	fi
}
recreateFreshZone(){
	domain="$1"
	user="$2"
	echo "Trying To reCreate New Zone File for the Domain: ${domain}"
	ip=`egrep '^ip:' /var/cpanel/userdata/${user}/${domain} | cut -d' ' -f2 2>/dev/null`
	/scripts/adddns --domain ${domain} --owner ${user} --ip ${ip}
	if [ -f /var/named/${domain}.db ]; then
		installSPFandDKeyIDandSetTTL ${user}
	else
		rm -f /root/dnscheck/log.$$
	fi
}
doTheRestoreWork(){
	domain="$1"
	user="$2"
	echo "Domain: ${domain} Is Owned by ${user}, You need to add zone file for it manually" | tee -a /root/dnscheck/log.$$
	synczone ${domain} | tee -a /root/dnscheck/log.$$
	if [ ! -f /var/named/${domain}.db ]; then
		restoreZoneFromBackup ${domain} ${user} | tee -a /root/dnscheck/log.$$
	fi
	if [ ! -f /var/named/${domain}.db ]; then
		echo "Failed To Restore the Zone File From Available Backups" | tee -a /root/dnscheck/log.$$
		recreateFreshZone ${domain} ${user} | tee -a /root/dnscheck/log.$$
	fi
}
processDomain(){
	domain="$1"
	if $(egrep -q "^${domain}:" /etc/userdomains 2>/dev/null ) && [ ! -e /var/named/${domain}.db ]; then
		echo "#################################################################################" | tee -a /root/dnscheck/log.$$
		echo -e "#\t\t\t\tProcessing ${domain}\t\t\t\t#" | tee -a /root/dnscheck/log.$$
		echo "#################################################################################" | tee -a /root/dnscheck/log.$$
		user=`grep -E "^${domain}:" /etc/userdomains | cut -d: -f2` 2>/dev/null
		if [ "${user}" == ' nobody' ]; then
			user=''
			user=`grep -rl "${domain}" /var/cpanel/userdata/ | awk -F'/' '{print $(NF-1)}' | sort -u`
			if [ "${user}" == '' ]; then
				echo "No user exist On The System For This Domain" | tee -a /root/dnscheck/log.$$
			else
			doTheRestoreWork ${domain} ${user}
		fi
	else
		doTheRestoreWork ${domain} ${user}
	fi
	echo "#################################################################################" | tee -a /root/dnscheck/log.$$
	echo -e "#\t\t\t\t\tDone\t\t\t\t\t#" | tee -a /root/dnscheck/log.$$
	echo "#################################################################################" | tee -a /root/dnscheck/log.$$
	if [ ! -f /var/named/${domain}.db ]; then
		rm -f /root/dnscheck/log.$$
	fi
	fi
}
loopDeletedZones(){
	for domain in `grep 'Cpanel::NameServer::Conf::BIND::removezone' /usr/local/cpanel/logs/error_log  | cut -d'"' -f2 | sort -u`; 
		do 
			processDomain ${domain}
		done
}
mainFunction(){
	if [ "$#" -eq 0 ]; then
		loopDeletedZones
		sendmail
	elif  [ "$#" -eq 1 ] && [ "$1" == '--all' ]; then
		for domain in `cat /etc/userdomains | cut -d: -f1`
		do
			processDomain ${domain}
			sendmail
		done
	elif [ "$#" -eq 2 ] && [ "$1" == '--domain' ]; then
		domain="$2"
		processDomain ${domain}
		sendmail
	else
		usage
	fi
}
mainFunction "$@"
