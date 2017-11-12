#!/bin/bash

# Only tested on a bone stock Brie Host $2/year VPS, running Ubuntu 15.04
# It *will* *not* *work* on many other providers at this point in time

################################################################################
# Functions
################################################################################

################################################################################
# ask "Question?" Y|N
#
# Where Y|N is an optional default
# Copied from https://gist.github.com/davejamesmiller/1965569
################################################################################

ask () {
    # https://djm.me/ask
    local prompt default reply

    while true; do

        if [ "${2:-}" = "Y" ]; then
            prompt="Y/n"
            default=Y
        elif [ "${2:-}" = "N" ]; then
            prompt="y/N"
            default=N
        else
            prompt="y/n"
            default=
        fi

        # Ask the question (not using "read -p" as it uses stderr not stdout)
        echo -n "$1 [$prompt] "

        # Read the answer (use /dev/tty in case stdin is redirected from somewhere else)
        read reply </dev/tty

        # Default?
        if [ -z "$reply" ]; then
            reply=$default
        fi

        # Check if the reply is valid
        case "$reply" in
            Y*|y*) return 0 ;;
            N*|n*) return 1 ;;
        esac

    done
}

################################################################################
# check_ipv4
#
# Checks for IPv4, will ask if need be, returns 1 if unavailable, 0 if available
################################################################################

check_ipv4 () {

if which nc &> /dev/null; then

    if nc -zw1 google.com 443; then
        return 0
    else
        return 1
    fi

elif which ping &> /dev/null; then

    if ping -q -c 1 -W 1 8.8.8.8 >/dev/null; then
        return 0
    else
        return 1
    fi

else

    if ask "I couldn't check for it, but do you have IPv4 access?" Y; then
        return 0
    else
        return 1
    fi

fi

}

################################################################################
# debian_install
################################################################################

debian_install () {

apt-get update

if [ "${VER}" -lt 8 ]; then

    apt-get install unzip nginx php5-fpm php5-curl php5-gmp php5-intl php5-json php5-sqlite -y

fi

}

################################################################################
# ubuntu_install
################################################################################

ubuntu_install () {

apt-get update

if [ "${VER}" -lt 16.04 ]; then

    apt-get install unzip nginx php5-fpm php5-curl php5-gmp php5-intl php5-json php5-sqlite -y

fi

}

################################################################################
# generic_nginx
################################################################################

generic_nginx () {

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root /var/www/html/FreshRSS;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

}

################################################################################
# debian_7_nginx
################################################################################

debian_7_nginx () {

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80 ipv6only=on;

    root /var/www/html/FreshRSS;
    index index.php index.html index.htm index.nginx-debian.html;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        fastcgi_pass unix:/var/run/php5-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;

    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

}

################################################################################
# generic_php_setup
################################################################################

generic_php_setup () {

sed -e 's/^;cgi.fix_pathinfo=1$/cgi.fix_pathinfo=0/' -i /etc/php5/fpm/php.ini

}

################################################################################
# generic_download
################################################################################

generic_download () {

if [[ "${alt_download}" = false ]]; then
    wget https://github.com/FreshRSS/FreshRSS/archive/master.zip -O /usr/src/master.zip
fi

}

################################################################################
# generic_unzip
################################################################################

generic_unzip () {

unzip /usr/src/master.zip -d /usr/share/ &> /dev/null
mv /usr/share/FreshRSS-master/ /usr/share/FreshRSS/

}

################################################################################
# generic_link
################################################################################

generic_link () {

ln -s /usr/share/FreshRSS/p/ /var/www/html/FreshRSS

}

################################################################################
# generic_permissions
################################################################################

generic_permissions () {

chown -R :www-data /usr/share/FreshRSS/
chmod -R g+r /usr/share/FreshRSS/
chmod -R g+w /usr/share/FreshRSS/data/

}

################################################################################
# generic_services_systemd
################################################################################

generic_services_systemd () {

systemctl enable php5-fpm
systemctl restart php5-fpm

systemctl enable nginx
systemctl restart nginx

}

################################################################################
# generic_services_sysvinit
################################################################################

generic_services_sysvinit () {

update-rc.d php5-fpm enable
service php5-fpm restart

update-rc.d nginx enable
service nginx restart

}

################################################################################
# debian_remove_apache
################################################################################



################################################################################
# Determine OS and VERsion
#
# lifted from https://unix.stackexchange.com/a/6348
################################################################################

if [ -f /etc/os-release ]; then
    # freedesktop.org and systemd
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
elif type lsb_release >/dev/null 2>&1; then
    # linuxbase.org
    OS=$(lsb_release -si)
    VER=$(lsb_release -sr)
elif [ -f /etc/lsb-release ]; then
    # For some versions of Debian/Ubuntu without lsb_release command
    . /etc/lsb-release
    OS=$DISTRIB_ID
    VER=$DISTRIB_RELEASE
elif [ -f /etc/debian_version ]; then
    # Older Debian/Ubuntu/etc.
    OS=Debian
    VER=$(cat /etc/debian_version)
elif [ -f /etc/SuSe-release ]; then
    # Older SuSE/etc.
    OS=SuSE
elif [ -f /etc/redhat-release ]; then
    # Older Red Hat, CentOS, etc.
    OS=Redhat
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

################################################################################
# Check root access
################################################################################

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

################################################################################
# Start our prompt and warn the user
################################################################################

clear
echo 'Welcome to this quick FreshRSS "road warrior" installer'
echo
echo 'This installer *will* destroy any existing config.'

################################################################################
# Ask user if we can continue
################################################################################

if ! ask 'Are you sure you want to continue?' N; then
    exit
fi
echo

################################################################################
# Check for ipv4 and prompt user to upload if on ipv6
################################################################################

if check_ipv4; then
    alt_download=false
    address="$(wget -qO- https://canihazip.com/s)"
else
    alt_download=true
    address="$(wget -qO- http://v6.ipv6-test.com/api/myip.php)"
    echo 'Github does not support IPv6, so you will need to upload FreshRSS yourself.'
    echo 'On an IPv4 and IPv6 enabled machine, please run:'
    echo "wget 'https://github.com/FreshRSS/FreshRSS/archive/master.zip' && scp master.zip root@\[${address}\]:/usr/src/master.zip"
    echo
    until [[ -e '/usr/src/master.zip' ]]; do
        sleep 0.1s
    done
    until ask "Is the transfer done?" Y; do
        echo "Okay, I'll wait..."
    done
fi

################################################################################
# Actually do the job
################################################################################

echo 'Okay, that was all we need. We are ready to setup your FreshRSS instance now'
read -n1 -r -p "Press any key to continue..."
echo

case $OS in
    Debian*|Ubuntu)

        debian_install


        if [ "${VER}" -lt '8' ]; then
            debian_7_nginx
        else
            generic_nginx
        fi

        generic_php_setup
        generic_download
        generic_unzip
        generic_permissions

        if ! [ -d /var/www/html/ ]; then
            mkdir -p /var/www/html/
        fi

        generic_link

        if [ "${VER}" -lt '8' ]; then
            generic_services_sysvinit
        else
            generic_services_systemd
        fi

        ;;

    Ubuntu)
        ubuntu_install

        generic_nginx

        generic_php_setup
        generic_download
        generic_unzip
        generic_permissions
        generic_link

        if [ "${VER}" -lt '15.04' ]; then
            generic_services_sysvinit
        else
            generic_services_systemd
        fi
        ;;
    *)
        echo " OS: ${OS}"
        echo "VER: ${VER}"
        echo 'Not supported.'
        ;;
esac

if [[ "${alt_download}" = true ]]; then
    echo -n "Please visit http://[${address}]"
else
    echo -n "Please visit http://${address}"
fi

echo ' to complete the setup process.'

exit
