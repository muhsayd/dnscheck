#!/bin/bash


for domain in `grep 'Cpanel::NameServer::Conf::BIND::removezone' /usr/local/cpanel/logs/error_log  | cut -d'"' -f2 | sort -u`; 
	do 
		if $(egrep -q "^${domain}:" /etc/userdomains 2>/dev/null ) && [ ! -e /var/named/${domain}.db ]; then
                echo "#########################################################################"
                echo -e "#\t\t\t\tProcessing ${domain}\t\t\t\t#"
                echo "#################################################################################"
			user=`grep -E "^${domain}:" /etc/userdomains | cut -d: -f2` 2>/dev/null
			if [ "${user}" == ' nobody' ]; then
				user=`grep -rl "${domain}" /var/cpanel/userdata/ | awk -F'/' '{print $(NF-1)}' | sort -u`
				if [ "${user}" != '' ]; then
					echo "Domain: ${domain} Is Owned by ${user}, You need to add zone file for it manually";
				else
					echo "user Doesn't exist"
				fi
			else
                                        echo "Domain: ${domain} Is Owned by ${user}, You need to add zone file for it manually";
			fi
			result=`/scripts/dnscluster synczonelocal ${domain} | head -1`
			if [ "${result}" == "Syncing ${domain} to local machine...Domain “${domain}” could not be found." ]; then
				echo "Failed to Sync Domain: ${domain} from Cluster"
			fi
			if [ ! -f /var/named/${domain}.db ]; then
				echo "Trying to restore Zone File from the Backup"
				if [ -f "/backup/cpbackup/daily/dirs/_var_named/${domain}.db" ]; then
					cp -p /backup/cpbackup/daily/dirs/_var_named/${domain}.db /var/named/${domain}.db
                                        /usr/local/cpanel/bin/dkim_keys_uninstall ${user}
                                        /usr/local/cpanel/bin/dkim_keys_install ${user}
                                        /usr/local/cpanel/bin/spf_uninstaller ${user}
                                        /usr/local/cpanel/bin/spf_installer ${user}
                                        /usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300
				elif [ -f "/backup/cpbackup/weekly/dirs/_var_named/${domain}.db" ]; then
                                        cp -p /backup/cpbackup/weekly/dirs/_var_named/${domain}.db /var/named/${domain}.db
                                        /usr/local/cpanel/bin/dkim_keys_uninstall ${user}
                                        /usr/local/cpanel/bin/dkim_keys_install ${user}
                                        /usr/local/cpanel/bin/spf_uninstaller ${user}
                                        /usr/local/cpanel/bin/spf_installer ${user}
                                        /usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300
                                elif [ -f "/backup/cpbackup/monthly/dirs/_var_named/${domain}.db" ]; then
                                        cp -p /backup/cpbackup/monthly/dirs/_var_named/${domain}.db /var/named/${domain}.db
                                        /usr/local/cpanel/bin/dkim_keys_uninstall ${user}
                                        /usr/local/cpanel/bin/dkim_keys_install ${user}
                                        /usr/local/cpanel/bin/spf_uninstaller ${user}
                                        /usr/local/cpanel/bin/spf_installer ${user}
                                        /usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300
				else
					echo "Trying To reCreate New Zone File for the Domain: ${domain}"
					ip=`egrep '^ip:' /var/cpanel/userdata/${user}/${domain} 2>/dev/null`
					/scripts/adddns --domain ${domain} --owner ${user} --ip ${ip}
					/usr/local/cpanel/bin/dkim_keys_install ${user}
                                        /usr/local/cpanel/bin/spf_installer ${user}
					/usr/local/cpanel/bin/set_zone_ttl --user ${user} --force --newttl 300
				fi
			fi
		echo "#################################################################################"
                echo -e "#\t\t\t\t\tDone\t\t\t\t\t#"
                echo "#################################################################################"
		fi 
	done
