#!/bin/bash
# Title: DynFi Manager Installer
# Description: Instalação automatizada do DynFi Manager
# Supported: VM, LXC
# Interactive: yes
# Reboot: no
# Network: safe
# Author: DynFi / Custom Scripts Team

# 
# Copyright (c)  2022 Kevin HUART for DynFi
# Copyright (c) 2023 Gregory BERNARD for DynFi 
# 
# Permission is granted to copy, distribute and/or modify this document
# under the terms of the GNU GPL v.3 
# https://www.gnu.org/licenses/gpl-3.0.fr.html


# MacOS variables
openjdk_url="https://github.com/adoptium/temurin11-binaries/releases/download/jdk-11.0.14%2B9/OpenJDK11U-jre_x64_mac_hotspot_11.0.14_9.pkg"
openjdk_file="OpenJDK11U-jre_x64_mac_hotspot_11.0.14_9.pkg"
RED='\033[1;91m' # Red
BLUE='\033[1;94m' # Blue
NC='\033[0m' # No Color


function hello()
{
	clear
	echo "        /\\==========================/\\"
	echo "       /\\/                         /\\/ "
	echo "      /\\/     DynFi® Manager      /\\/  "
	echo "     /\\/        installer        /\\/   "
	echo "    /\\/                         /\\/    "
	echo -e "    \\/===| info @ DynFi.com |===\\/     \n\n\n"
}

function parseNginxConf() # $1: server name| $2: ipAndPort
{
	echo "server {
	    listen 80 DynFi_Manager_Server;
	    listen [::]:80 DynFi_Manager_Server;
	    server_name $1;
	    return 301 https://\$server_name\$request_uri;
	}

	server {
	    listen 443 ssl http2 DynFi_Manager_Server;
	    listen [::]:443 ssl http2 DynFi_Manager_Server;
	    server_name $1;

	    location /config.js {
	            proxy_pass http://$2;
	            sub_filter 'http://$2' 'https://\$host';
	            sub_filter_types \"*\";
	    }

	    location / {
	            proxy_pass http://$2;
	    }

	    ssl_dhparam /etc/ssl/certs/dhparam.pem;

	    ssl_certificate /etc/ssl/dynfi/bundle.crt;
	    ssl_certificate_key /etc/ssl/dynfi/DynFi_Manager_Server.com.key;

	}"
}

function concent()
{
	echo -e "\nThis ${BLUE}DynFi Manager installation script${NC} is offered by DynFi® with NO WARRANTY.\n"
	echo -e "But don't worry: our team has tested it and it should be harmless.\n"
	echo -e "If you have identified some potential enhancement, please feel free" 
	echo -e "to update this script and commit your updates at ${BLUE}bugtrack@dynfi.com${NC}\n"
	echo -e "Should you have other questions, please check the Dynfi Manager's"
	echo -e "documentation located at: ${BLUE}https://dynfi.com/documentation/${NC}\n"
	echo -e "Last but not least, if you are happy with DynFi Manager, you can"
	echo -e "buy your licenses at ${BLUE}https://shop.dynfi.com/${NC}\n"
	echo -e -n "Proceed with the installation? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l) -ne 1 || $(echo $input | grep -i 'yes' | wc -c) -ne 4 ]]; then
		echo -e "Exiting without modification.\n"
		exit
	fi
	echo -e "Proceeding with the installation...\n"
}

function install_ubuntu()
{
	echo -e "Launching installation for ${BLUE}UBUNTU${NC} distro...\n"
	concent

	# Openjdk
	echo -e "Verify or install ${BLUE}OpenJDK-11-JRE${NC}...\n"

	if [[ $(lsb_release -r | grep -c -E "16.[0-9]{2}") -gt 0 ]]; then
		add-apt-repository -y ppa:openjdk-r/ppa >> DFM_installer.log
	fi
	apt-get update >> DFM_installer.log
	apt-get install -y openjdk-11-jre-headless >> DFM_installer.log
	if [[ $(java -version | grep -i -c "not found") -gt 0 ]]; then
		echo -e "${RED}OpenJDK${NC} installation failed. Please check DFM_installer.log"
		exit
	fi
	echo "Done"

	# MongoDB
	echo -e -n "Do you want to install ${BLUE}MongoDB${NC} locally (recommended)? <yes|no>: "
	read input
	if [[ $(echo "$input" | grep -i -c 'yes' | tr -d ' ') -eq 1 && $(echo "$input" | grep -i 'yes' | wc -c | tr -d ' ') -eq 4 ]]; then
		# MongoDB - key
		mongoVersion="8.0"
		if [[ $(lsb_release -r | grep -c -E "16.[0-9]{2}") -gt 0 ]]; then
			mongoVersion="4.4"
		elif [[ $(lsb_release -r | grep -c -E "(18|20|22).[0-9]{2}") -gt 0 ]]; then
			mongoVersion="6.0"
		fi

		echo -e -n "Retrieving MongoDB's $mongoVersion key... "
		rm -f "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"
		if ! curl -fsSL "https://pgp.mongodb.com/server-$mongoVersion.asc" | gpg --dearmor -o "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"; then
			apt-get install -y gnupg >> DFM_installer.log
			if ! curl -fsSL "https://pgp.mongodb.com/server-$mongoVersion.asc" | gpg --dearmor -o "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"; then
				echo -e "Unable to retrieve MongoDB's key. Please check ${RED}DFM_installer.log${NC}"
				exit 1
			fi
		fi
		chmod a+r "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"
		echo "Done"

		# MongoDB - install
		if [[ $(lsb_release -r | grep -c -E "16.[0-9]{2}") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/$mongoVersion multiverse" | tee "/etc/apt/sources.list.d/mongodb-org-$mongoVersion.list" >> DFM_installer.log
		elif [[ $(lsb_release -r | grep -c -E "18.[0-9]{2}") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/$mongoVersion multiverse" | tee "/etc/apt/sources.list.d/mongodb-org-$mongoVersion.list" >> DFM_installer.log
		elif [[ $(lsb_release -r | grep -c -E "20.[0-9]{2}") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/$mongoVersion multiverse" | tee "/etc/apt/sources.list.d/mongodb-org-$mongoVersion.list" >> DFM_installer.log
		elif [[ $(lsb_release -r | grep -c -E "22.[0-9]{2}") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/ubuntu jammy/mongodb-org/$mongoVersion multiverse" | tee "/etc/apt/sources.list.d/mongodb-org-$mongoVersion.list" >> DFM_installer.log
		else
    	echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/ubuntu noble/mongodb-org/$mongoVersion multiverse" | tee "/etc/apt/sources.list.d/mongodb-org-$mongoVersion.list" >> DFM_installer.log
		fi
		echo -e -n "Fetching ${BLUE}MongoDB's${NC} repo... "
		apt-get update >> DFM_installer.log
		echo "Done"
		echo -n "Installing MongoDB... "
		apt-get install -y mongodb-org >> DFM_installer.log
		echo "mongodb-org hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-database hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-server hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-shell hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-mongos hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-tools hold" | dpkg --set-selections >> DFM_installer.log
		echo "Done"

		# MongoDB - run
		echo -n "Run MongoDB... "
		if [[ $(ulimit -n) -lt 64000 ]]; then
			ulimit -n 64000 >> DFM_installer.log
		fi
		if [[ $(ps --no-headers -o comm 1 | grep -i -c "systemd") -gt 0 ]]; then
			if [[ $(systemctl start mongod | grep -i -c "Failed") -gt 0 ]]; then
				systemctl daemon-reload >> DFM_installer.log
				if [[ $(systemctl start mongod | grep -i -c "Failed") -gt 0 ]]; then
					echo -e "Installer has encountered an issue starting ${RED}MongoDB${NC}. Please check DFM_installer.log"
					tail -n 50 /var/log/mongodb/mongod.log >> DFM_installer.log
					exit
				fi
			fi
		else
			service mongod start >> DFM_installer.log
		fi
		if [[ $(ps --no-headers -o comm 1 | grep -i -c "systemd") -gt 0 ]]; then
			if [[ $(systemctl status mongod | grep -i -c "active (running)") -eq 0 ]]; then
				echo -e "${RED}MongoDB${NC} didn't start properly. Please check /var/log/mongodb/mongod.log and DFM_installer.log"
				systemctl status mongod >> DFM_installer.log
				exit
			fi
		else
			if [[ $(service mongod status | grep -i -c "active (running)") -eq 0 ]]; then
				echo -e "${RED}MongoDB${NC} didn't start properly. Please check /var/log/mongodb/mongod.log and DFM_installer.log"
				service mongod status >> DFM_installer.log
				exit
			fi
		fi

		systemctl enable mongod.service >> DFM_installer.log
		echo "Done"
	fi

	# DynFi Manager - Install
	echo -e -n "Retrieving ${BLUE}DynFi Manager's${NC} key... "
	rm -f /usr/share/keyrings/dynfi.gpg
	if ! curl -fsSL https://archive.dynfi.com/dynfi.gpg | gpg --dearmor -o /usr/share/keyrings/dynfi.gpg; then
		echo -e "Unable to retrieve ${RED}DynFi's${NC} key. Please check DFM_installer.log"
		exit 1
	fi
	chmod a+r /usr/share/keyrings/dynfi.gpg
	echo "Done"

	if [[ $(lsb_release -r | grep -c -E "16.[0-9]{2}") -gt 0 ]]; then
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/ubuntu xenial main" > /etc/apt/sources.list.d/dynfi.list
	elif [[ $(lsb_release -r | grep -c -E "18.[0-9]{2}") -gt 0 ]]; then
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/ubuntu bionic main" > /etc/apt/sources.list.d/dynfi.list
	elif [[ $(lsb_release -r | grep -c -E "20.[0-9]{2}") -gt 0 ]]; then
  	echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/ubuntu focal main" > /etc/apt/sources.list.d/dynfi.list
  elif [[ $(lsb_release -r | grep -c -E "22.[0-9]{2}") -gt 0 ]]; then
  	echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/ubuntu jammy main" > /etc/apt/sources.list.d/dynfi.list
  else
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/ubuntu noble main" > /etc/apt/sources.list.d/dynfi.list
	fi

	echo -e -n "Fetching ${BLUE}DynFi${NC} Repo... "
	apt update >> DFM_installer.log
	echo "Done"
	echo -e -n "Installing ${BLUE}DynFi Manager${NC}... "
	apt install -y dynfi

	if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
		if [[ $(systemctl status dynfi | grep -i "active (running)" | wc -l) -eq 0 ]]; then
			echo -e "${RED}DynFi Manager${NC} has encountered some issues running. Please check DFM_installer.log"
			systemctl status dynfi >> DFM_installer.log
			exit
		fi
	else
		if [[ $(service dynfi status | grep -i "active (running)" | wc -l) -eq 0 ]]; then
			echo -e "${RED}DynFi Manager${NC} encountered some issues running. Please check DFM_installer.log"
			service dynfi status >> DFM_installer.log
			exit
		fi
	fi
	systemctl enable dynfi >> DFM_installer.log
	echo "Done"

	# DynFi Manager - Configurations
	ipAndPort=$(cat /etc/dynfi.conf | grep ipAndPort | cut -d '=' -f 2)

	# # Nginx
	# echo -n "Would you like to use Nginx to handle connections to DynFi Manager ? <yes|no>: "
	# read input
	# if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
	# 	if [[ $(systemctl status nginx | grep -i "not be found" | wc -l) -gt 0 ]]; then
	# 		echo -n "It seems that Nginx is not installed yet. Do you want to install it now ? (type 'yes' if you agreed): "
	# 		read input
	# 		if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
	# 			apt-get install -y nginx
	# 		fi
	# 	fi
	# fi

	proto="http"
	if [[ $(cat /etc/dynfi.conf | grep -i "useHttps=true" | wc -l) -gt 0 ]]; then
		proto="https"
	fi
	echo -e "You can now go to  ${BLUE}DynFi Manager Webserver${NC}. Simply go to $proto://$ipAndPort"
}

function uninstall_ubuntu()
{
	echo "uninstall_ubuntu" >> DFM_installer.log

	# DynFi Manager
	echo -e -n "${BLUE}Uninstall DynFi Manager${NC}... "
	if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
		systemctl stop dynfi >> DFM_installer.log
	else
		service dynfi stop >> DFM_installer.log
	fi
	apt-get -y remove dynfi >> DFM_installer.log
	echo "Done"

	echo -e -n "Do you want to remove your ${BLUE}DynFi Manager configuration${NC}? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
		echo -n "Removing configuration... "
		rm -f /etc/dynfi.conf >> DFM_installer.log
		echo "Done"
	fi

	# MongoDB
	echo -e -n "Do you want to remove ${BLUE}MongoDB${NC}? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
		echo -e -n "Removing ${BLUE}MongoDB${NC}... "
		if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
			systemctl stop mongod >> DFM_installer.log
		else
			service mongod stop >> DFM_installer.log
		fi
		apt-get -y purge --allow-change-held-packages mongodb-org* >> DFM_installer.log
		rm -rf /var/log/mongodb >> DFM_installer.log 2>&1 || true
		rm -rf /var/lib/mongodb >> DFM_installer.log 2>&1 || true
		echo "Done"
	fi
}

function install_debian()
{
	echo "Launching installation for ${BLUE}DEBIAN${NC} distro..."
	concent

	# Openjdk
	if [[ $(echo "$distro" | grep -c "stretch") -gt 0 ]]; then
		echo "deb http://ftp.debian.org/debian stretch-backports main" | tee /etc/apt/sources.list.d/stretch-backports.list >> DFM_installer.log
	fi

	apt-get update >> DFM_installer.log

	if [[ $(echo "$distro" | grep -c -E "stretch|buster|bullseye") -gt 0 ]]; then
		apt-get install -y openjdk-11-jre-headless >> DFM_installer.log
	else
		apt-get install -y default-jre-headless >> DFM_installer.log
	fi
	if [[ $(java -version | grep -i -c "not found") -gt 0 ]]; then
		echo -e "${RED}OpenJDK${NC} installation failed. Please check DFM_installer.log"
		exit
	fi

	# MongoDB
	echo -e -n "Do you want to install ${BLUE}MongoDB${NC} locally (recommended)? <yes|no>: "
	read input
	if [[ $(echo "$input" | grep -i -c 'yes' | tr -d ' ') -eq 1 && $(echo "$input" | grep -i 'yes' | wc -c | tr -d ' ') -eq 4 ]]; then
		mongoVersion="7.0"
		if [[ $(echo "$distro" | grep -c "stretch") -gt 0 ]]; then
			mongoVersion="5.0"
		elif [[ $(echo "$distro" | grep -c -E "buster|bullseye") -gt 0 ]]; then
			mongoVersion="6.0"
		fi

		# MongoDB - key
		echo -n "Retrieving MongoDB's $mongoVersion key... "
		rm -f "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"
		if ! curl -fsSL "https://pgp.mongodb.com/server-$mongoVersion.asc" | gpg --dearmor -o "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"; then
			apt-get install -y gnupg >> DFM_installer.log
			if ! curl -fsSL "https://pgp.mongodb.com/server-$mongoVersion.asc" | gpg --dearmor -o "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"; then
				echo -e "Unable to retrieve ${RED}MongoDB's key${NC}. Please check DFM_installer.log"
				exit 1
			fi
		fi
		chmod a+r "/usr/share/keyrings/mongodb-server-$mongoVersion.gpg"
		echo "Done"

		# MongoDB - install
		if [[ $(echo "$distro" | grep -c "stretch") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/debian stretch/mongodb-org/$mongoVersion main" | tee /etc/apt/sources.list.d/mongodb-org-$mongoVersion.list >> DFM_installer.log
		elif [[ $(echo "$distro" | grep -c "buster") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/debian buster/mongodb-org/$mongoVersion main" | tee /etc/apt/sources.list.d/mongodb-org-$mongoVersion.list  >> DFM_installer.log
		elif [[ $(echo "$distro" | grep -c "bullseye") -gt 0 ]]; then
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/debian bullseye/mongodb-org/$mongoVersion main" | tee /etc/apt/sources.list.d/mongodb-org-$mongoVersion.list >> DFM_installer.log
		else
			echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-$mongoVersion.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/$mongoVersion main" | tee /etc/apt/sources.list.d/mongodb-org-$mongoVersion.list  >> DFM_installer.log
		fi

		echo -n "Fetching MongoDB's repo... "
		apt-get update >> DFM_installer.log
		echo "Done"
		echo -e -n "Installing ${BLUE}MongoDB${NC}..."
		apt-get install -y mongodb-org >> DFM_installer.log
		echo "mongodb-org hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-database hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-server hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-shell hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-mongos hold" | dpkg --set-selections >> DFM_installer.log
		echo "mongodb-org-tools hold" | dpkg --set-selections >> DFM_installer.log
		echo "Done"

		# MongoDB - run
		echo -e -n "Run ${BLUE}MongoDB${NC}... "
		if [[ $(ulimit -n) -lt 64000 ]]; then
			ulimit -n 64000 >> DFM_installer.log
		fi
		if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
			if [[ $(systemctl start mongod | grep -i "Failed" | wc -l) -gt 0 ]]; then
				systemctl daemon-reload >> DFM_installer.log
				if [[ $(systemctl start mongod | grep -i "Failed" | wc -l) -gt 0 ]]; then
					echo -e "Installer has encountered an issue starting ${RED}MongoDB${NC}. Please check DFM_installer.log"
					tail -n 50 /var/log/mongodb/mongod.log >> DFM_installer.log
					exit
				fi
			fi
		else
			service mongod start >> DFM_installer.log
		fi
		if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
			if [[ $(systemctl status mongod | grep -i "active (running)" | wc -l) -eq 0 ]]; then
				echo -e "${RED}MongoDB${NC} didn't start properly. Please check /var/log/mongodb/mongod.log and DFM_installer.log"
				systemctl status mongod >> DFM_installer.log
				exit
			fi
		else
			if [[ $(service mongod status | grep -i "active (running)" | wc -l) -eq 0 ]]; then
				echo -e "${RED}MongoDB${NC} didn't start properly. Please check /var/log/mongodb/mongod.log and DFM_installer.log"
				service mongod status >> DFM_installer.log
				exit
			fi
		fi

		systemctl enable mongod.service >> DFM_installer.log
		echo "Done"
	fi

	# DynFi Manager - Install
	echo -n "Retrieving ${BLUE}DynFi Manager's${NC} key... "
	rm -f /usr/share/keyrings/dynfi.gpg
	if ! curl -fsSL https://archive.dynfi.com/dynfi.gpg | gpg --dearmor -o /usr/share/keyrings/dynfi.gpg; then
		echo -e "Unable to retrieve ${RED}DynFi Manager's key${NC}. Please check DFM_installer.log"
		exit 1
	fi
	chmod a+r /usr/share/keyrings/dynfi.gpg
	echo "Done"

	if [[ $(echo "$distro" | grep -c "stretch") -gt 0 ]]; then
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/debian stretch main" > /etc/apt/sources.list.d/dynfi.list
	elif [[ $(echo "$distro" | grep -c "buster") -gt 0 ]]; then
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/debian buster main" > /etc/apt/sources.list.d/dynfi.list
	elif [[ $(echo "$distro" | grep -c "bullseye") -gt 0 ]]; then
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/debian bullseye main" > /etc/apt/sources.list.d/dynfi.list
	else
		echo "deb [ signed-by=/usr/share/keyrings/dynfi.gpg ] https://archive.dynfi.com/debian bookworm main" > /etc/apt/sources.list.d/dynfi.list
	fi

	echo -e -n "Fetching ${BLUE}DynFi Repo${NC}... "
	apt update >> DFM_installer.log
	echo "Done"
	echo -e -n "Installing ${BLUE}DynFi Manager${NC}... "
	apt install -y dynfi

	if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
		if [[ $(systemctl status dynfi | grep -i "active (running)" | wc -l) -eq 0 ]]; then
			echo -e "${RED}Dynfi Manager${NC} has encountered some issues running. Please check DFM_installer.log"
			systemctl status dynfi >> DFM_installer.log
			exit
		fi
	else
		if [[ $(service dynfi status | grep -i "active (running)" | wc -l) -eq 0 ]]; then
			echo -e "${RED}Dynfi Manager${NC} has encountered some issues running. Please check DFM_installer.log"
			service dynfi status >> DFM_installer.log
			exit
		fi
	fi
	systemctl enable dynfi >> DFM_installer.log
	echo "Done"

	# DynFi Manager - Configurations
	ipAndPort=$(cat /etc/dynfi.conf | grep ipAndPort | cut -d '=' -f 2)

	proto="http"
	if [[ $(cat /etc/dynfi.conf | grep -i "useHttps=true" | wc -l) -gt 0 ]]; then
		proto="https"
	fi
	echo -e "You can now go to ${BLUE}DynFi Manager Webserver${NC}. Simply go to $proto://$ipAndPort"
}

function uninstall_debian()
{
	echo "uninstall_debian" >> DFM_installer.log

	# DynFi Manager
	echo -e -n "Uninstalling ${BLUE}DynFi Manager${NC}... "
	if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
		systemctl stop dynfi >> DFM_installer.log
	else
		service dynfi stop >> DFM_installer.log
	fi
	apt-get -y remove dynfi >> DFM_installer.log
	echo "Done"

	echo -e -n "Do you want to remove your ${BLUE}DynFi Manager configuration${NC}? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
		echo -n "Removing configuration... "
		rm -f /etc/dynfi.conf >> DFM_installer.log
		echo "Done"
	fi

	# MongoDB
	echo -e -n "Do you want to remove ${BLUE}MongoDB${NC}? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l) -eq 1 && $(echo $input | grep -i 'yes' | wc -c) -eq 4 ]]; then
		echo -n "Removing MongoDB... "
		if [[ $(ps --no-headers -o comm 1 | grep -i "systemd" | wc -l) -gt 0 ]]; then
			systemctl stop mongod >> DFM_installer.log
		else
			service mongod stop >> DFM_installer.log
		fi
		apt-get -y purge --allow-change-held-packages mongodb-org* >> DFM_installer.log
		rm -rf /var/log/mongodb >> DFM_installer.log 2>&1 || true
		rm -rf /var/lib/mongodb >> DFM_installer.log 2>&1 || true
		echo "Done"
	fi
}

function install_macos()
{
	echo -e "Launching installation for ${BLUE}Mac OS distribution${NC}..."
	concent

	# MongoDB
	echo -e -n "Do you want to install ${BLUE}MongoDB${NC} locally (recommended)? <yes|no>: "
	read input
	if [[ $(echo $input | grep -i 'yes' | wc -l | tr -d ' ') -eq 1 && $(echo $input | grep -i 'yes' | wc -c | tr -d ' ') -eq 4 ]]; then
		# Brew
		if [[ $(which brew | grep -i 'not found' | wc -l | tr -d ' ') -gt 0 ]]; then
			echo "It seems that Homebrew is not installed yet."
			echo -e -n "Do you want to install ${BLUE}homebrew${NC} (recommended)? <yes|no>: "
			read input
			if [[ $(echo $input | grep -i 'yes' | wc -l | tr -d ' ') -eq 1 && $(echo $input | grep -i 'yes' | wc -c | tr -d ' ') -eq 4 ]]; then
				/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
				if [[ $(which brew | grep -i 'not found' | wc -l | tr -d ' ') -gt 0 ]]; then
					echo -e "${RED}Homebrew${NC} installation has encountered an issue. Please read the comments above."
					exit
				fi
				echo -e "In order to install ${BLUE}MongoDB${NC}, you have to open another terminal with a non root user and run:"
				echo -e "brew install mongodb\nAnd\nbrew service start mongodb"
			else
				echo -e "You need to manually install ${BLUE}MongoDB${NC}. You can do it right now, on another terminal. Then, come back here."
			fi
		else
			echo -e "In order to install ${BLUE}MongoDB${NC}, you have to open another terminal with a non root user and run:"
			echo -e "brew tap mongodb/brew ; brew update ; brew install mongodb-community@6.0\n"	
			echo -e "If this formula is not working, please check Mongo's latest infos here:"
			echo -e "${BLUE}https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-os-x/${NC}\n"
		fi
		echo -e -n "MongoDB is now installed, do you want to proceed with the installation of ${BLUE}DynFi Manager${NC}? <yes|no>: "
		read input
		if [[ $(echo $input | grep -i 'yes' | wc -l | tr -d ' ') -ne 1 || $(echo $input | grep -i 'yes' | wc -c | tr -d ' ') -ne 4 ]]; then
			echo "Now exiting installation script..."
			exit
		fi
	fi

	# Openjdk
	echo -e -n "Verify or install ${BLUE}OpenJDK-11-JRE${NC}... "
	if [[ $(java -version | grep -i "not found" | wc -l | tr -d ' ') -gt 0 ]]; then
		wget $openjdk_url >> DFM_installer.log
		installer -pkg "./$openjdk_file" -target / >> DFM_installer.log
		rm -f $openjdk_file >> DFM_installer.log
		if [[ $(java -version | grep -i "not found" | wc -l | tr -d ' ') -gt 0 ]]; then
			echo -e "Can not install ${RED}OpenJDK-JRE${NC}. Please check DFM_installer.log\n"
			exit
		fi
	fi
	echo "Done"

	# DynFi Manager
	echo -e "Installing and launching ${BLUE}DynFi Manager${NC}..."
	DFMver=$(curl "https://dynfi.com/latest-version")
	#DFMver=$(wget "https://dynfi.com/latest-version")
	wget "https://dynfi.com/files/dynfi/dynfi-$DFMver-all.jar" >> DFM_installer.log
	java -jar "dynfi-$DFMver-all.jar"

}

function uninstall_macos()
{
	echo "uninstall_macos" >> DFM_installer.log
}

hello

if [[ $EUID != 0 ]]; then
	echo -e "The installer must be executed as root in order to work properly, please run it as ${BLUE}Super User (root)${NC}."
	exit
fi

distro=$(hostnamectl)

if [[ $(echo $distro | wc -c) -lt 3 ]]; then
	distro=$OSTYPE
fi

uninstall=0
while getopts 'd:u' option; do
	case $option in
		d )
			distro=$OPTARG
			if [[ $(echo $distro | grep -i "ubuntu" | wc -l) -gt 0 ]]; then
				echo -e "For which version of ${BLUE}Ubuntu${NC} you want to run this script?"
				echo "<1> 22.04 (Jammy) "
				echo "<2> 20.04 (Focal) "
				echo "<3> 18.04 (Bionic)"
				echo "<4> 16.04 (Xenial)"
				res=0
				while [[ $res -eq 0 ]]; do
					echo -n "Your answer <1-4>: "
					read input
					case $input in
						1)
							distro="$distro 22.04"
							res=1
							;;
						2)
							distro="$distro 20.04"
							res=1
							;;
						3)
							distro="$distro 18.04"
							res=1
							;;
						4)
							distro="$distro 16.04"
							res=1
							;;
						* )
							echo -n "Wrong input. "
							;;
					esac
				done
			elif [[ $(echo $distro | grep -i "debian" | wc -l) -gt 0 ]]; then
				echo -e "For which version of ${BLUE}Debian${NC} you want to run this script?"
				echo "<1> 11 (Bullseye)"
				echo "<2> 10 (Buster)     "
				echo "<3>  9 (Stretch)"
				res=0
				while [[ $res -eq 0 ]]; do
					echo -n "Your answer <1-3>: "
					read input
					case $input in
						1)
							distro="$distro bullseye"
							res=1
							;;
						2)
							distro="$distro buster"
							res=1
							;;
						3) 
							distro="$distro stretch"
							res=1
							;;
						* )
							echo -n "Wrong input. "
							;;
					esac
				done
			elif [[ $(echo $distro | grep -i "darwin" | wc -l) -gt 0 || $(echo $distro | grep -i "macos" | wc -l) -gt 0 ]]; then
				echo ""
			else
				echo "Your system hasn't been identified as supported by this installer."
				echo -e "Supported distros are ${BLUE}Ubuntu 16|18|20|22, Debian 9|10|11, and MacOS${NC}."
			fi
			;;
		u )
			uninstall=1
			echo -e -n "Do you want to uninstall ${BLUE}DynFi Manager${NC}? <yes|no>: "
			read input
			if [[ $(echo $input | grep -i 'yes' | wc -l) -ne 1 || $(echo $input | grep -i 'yes' | wc -c) -ne 4 ]]; then
				echo "No modification has been made."
				exit
			fi
			;;
	esac
done

hello

echo -e "----------------------------------- $(date) -----------------------------------\n" >> DFM_installer.log
if [[ $(echo $distro | grep -i "ubuntu" | wc -l) -gt 0 ]]; then
	if [[ $uninstall -eq 1 ]]; then
		uninstall_ubuntu
		exit
	fi
	echo "install_ubuntu" >> DFM_installer.log
	install_ubuntu
elif [[ $(echo $distro | grep -i "debian" | wc -l) -gt 0 ]]; then
	if [[ $uninstall -eq 1 ]]; then
		uninstall_debian
		exit
	fi
	echo "install_debian" >> DFM_installer.log
	install_debian
elif [[ $(echo $distro | grep -i "darwin" | wc -l) -gt 0 || $(echo $distro | grep -i "macos" | wc -l) -gt 0 ]]; then
	if [[ $uninstall -eq 1 ]]; then
		uninstall_macos
		exit
	fi
	echo "install_macos" >> DFM_installer.log
	install_macos
else
	echo -e "Your system ${RED}does not seem to be supported by this installer${NC}. To force installation for a specified distro, run:"
	echo "./DynFi_Manager_installer.sh -d <distro>"
	echo -e "Supported distros are ${BLUE}ubuntu${NC} 16|18|20|22, ${BLUE}debian${NC} 9|10|11, and ${BLUE}macos${NC} using brew."
fi
