#!/bin/bash
for domain in `grep 'Cpanel::NameServer::Conf::BIND::removezone' /usr/local/cpanel/logs/error_log  | cut -d'"' -f2 | sort -u`; 
	do 
		if $(egrep -q "^${domain}:" /etc/userdomains 2>/dev/null ) && [ ! -e /var/named/${domain}.db ]; then
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
		fi 
	done
