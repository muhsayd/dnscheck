#!/bin/bash

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
	/usr/local/cpanel/bin/dkim_keys_install ${user}
	/usr/local/cpanel/bin/spf_installer ${user}
	/usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300
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
	ip=`egrep '^ip:' /var/cpanel/userdata/${user}/${domain} 2>/dev/null`
	/scripts/adddns --domain ${domain} --owner ${user} --ip ${ip}
	installSPFandDKeyIDandSetTTL ${user}
}
for domain in `grep 'Cpanel::NameServer::Conf::BIND::removezone' /usr/local/cpanel/logs/error_log  | cut -d'"' -f2 | sort -u`; 
	do 
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
					exit 127
				fi
			fi
				echo "Domain: ${domain} Is Owned by ${user}, You need to add zone file for it manually" | tee -a /root/dnscheck/log.$$
				synczone ${domain} | tee -a /root/dnscheck/log.$$
				if [ ! -f /var/named/${domain}.db ]; then
					restoreZoneFromBackup ${domain} ${user} | tee -a /root/dnscheck/log.$$
				fi
                        	if [ ! -f /var/named/${domain}.db ]; then
					echo "Failed To Restore the Zone File From Available Backups" | tee -a /root/dnscheck/log.$$
                                	recreateFreshZone ${domain} ${user} | tee -a /root/dnscheck/log.$$
                        	fi
		echo "#################################################################################" | tee -a /root/dnscheck/log.$$
                echo -e "#\t\t\t\t\tDone\t\t\t\t\t#" | tee -a /root/dnscheck/log.$$
                echo "#################################################################################" | tee -a /root/dnscheck/log.$$
		fi 
	done
