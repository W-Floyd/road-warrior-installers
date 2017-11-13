#!/bin/bash

shopt -s extglob

################################################################################
#
# Tested on a Brie Host $2/year VPS, running;
#   Ubuntu 15.04
#   Ubuntu 14.04
#   Ubuntu 12.04
#   Debian 7
#   CentOS 6
#
# It *will* *not* *work* on many other providers at this point in time
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
# TODO - Test and fill out more information
    # Older SuSE/etc.
    OS=SuSE
elif [ -f /etc/redhat-release ]; then
    if grep -qE '^CentOS*' /etc/redhat-release; then
        OS=CentOS
        VER="$(cat /etc/redhat-release | sed 's/.* release \([^ ]*\).*/\1/')"
    else
# TODO - Fill out more information
        OS=Redhat
    fi
else
    # Fall back to uname, e.g. "Linux <version>", also works for BSD, etc.
    OS=$(uname -s)
    VER=$(uname -r)
fi

################################################################################
# Functions
################################################################################

################################################################################
# vercomp <VER_1> <VER_2>
#
# Version Compare
# Compare two version strings:
# VER_1 = VER_2 : Returns 0
# VER_1 > VER_2 : Returns 1
# VER_1 < VER_2 : Returns 2
#
# Copied from https://stackoverflow.com/a/4025065
################################################################################


vercomp () {
    if [[ $1 == $2 ]]
    then
        return 0
    fi
    local IFS=.
    local i ver1=($1) ver2=($2)
    # fill empty fields in ver1 with zeros
    for ((i=${#ver1[@]}; i<${#ver2[@]}; i++))
    do
        ver1[i]=0
    done
    for ((i=0; i<${#ver1[@]}; i++))
    do
        if [[ -z ${ver2[i]} ]]
        then
            # fill empty fields in ver2 with zeros
            ver2[i]=0
        fi
        if ((10#${ver1[i]} > 10#${ver2[i]}))
        then
            return 1
        fi
        if ((10#${ver1[i]} < 10#${ver2[i]}))
        then
            return 2
        fi
    done
    return 0
}

################################################################################
# testvercomp <VER_1> =|<|> <VER_2>
#
# Test Version Compare
# Test version numbers, return 0 if true, 1 if false
# Remember to quote the operator!
#
# Copied from https://stackoverflow.com/a/4025065, with some modification
################################################################################

testvercomp () {
    vercomp $1 $3
    case $? in
        0) op='=';;
        1) op='>';;
        2) op='<';;
    esac
    if [[ $op != $2 ]]; then
        return 1
    else
        return 0
    fi
}

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
# fail_ask
################################################################################

fail_ask () {

if ! ask "${1}" N; then
    exit
else
    echo 'Be it on your own head...'
fi

}

################################################################################
# debian_install
################################################################################

debian_install () {

apt-get update || fail_ask 'Checking servers seems to have failed, do you want to continue?'

if testvercomp "${VER}" '<' 8; then

    apt-get install unzip nginx php5-fpm php5-curl php5-gmp php5-intl php5-json php5-sqlite -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

else

    apt-get install unzip nginx php php-curl php-gmp php-intl php-mbstring php-sqlite3 php-xml php-zip -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

fi

}

################################################################################
# ubuntu_install
################################################################################

ubuntu_install () {

apt-get update || fail_ask 'Checking servers seems to have failed, do you want to continue?'

if testvercomp "${VER}" '<' 16.04; then

    apt-get install unzip nginx php5-fpm php5-curl php5-gmp php5-intl php5-json php5-sqlite -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

else

    apt-get install unzip nginx php php-curl php-gmp php-intl php-mbstring php-sqlite3 php-xml php-zip -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

fi

}

################################################################################
# redhat_install
################################################################################

redhat_install () {

# I would ask if it fails, but it complains no matter what...
yum check-update -y

yum install epel-release -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

# TODO -  Won't work on CentOS 6, need to test on newer!
yum install unzip nginx php-fpm php-intl php-mbstring php-sqlite3 php-xml -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

}

################################################################################
# centos_6_install
################################################################################

centos_6_install () {

# I would ask if it fails, but it complains no matter what...
yum check-update -y

yum install epel-release -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

yum install http://rpms.remirepo.net/enterprise/remi-release-6.rpm -y || fail_ask 'Installing a repo for a newer (required) PHP version seems to have failed, do you want to continue?'

yum install yum-utils -y

yum-config-manager --enable remi-php56

yum update -y

yum install unzip nginx php-fpm php-intl php-mbstring php-sqlite3 php-xml -y || fail_ask 'Installing software seems to have failed, do you want to continue?'

}

################################################################################
# generic_nginx
################################################################################

generic_nginx () {

export html_dir='/var/www/html'

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80 default_server;
    listen [::]:80 default_server;

    root ${html_dir}/FreshRSS;
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

export html_dir='/var/www/html'

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80 ipv6only=on;

    root ${html_dir}/FreshRSS;
    index index.php index.html index.htm;

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
# ubuntu_12_04_nginx
################################################################################

ubuntu_12_04_nginx () {

export html_dir='/var/www/html'

cat << EOF > /etc/nginx/sites-available/default
server {
    listen 80;
    listen [::]:80 ipv6only=on;

    root ${html_dir}/FreshRSS;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

}

################################################################################
# centos_6_nginx
################################################################################

centos_6_nginx () {

export html_dir='/usr/share/nginx/html'

cat << EOF > /etc/nginx/conf.d/default.conf
server {
    listen 80;
    listen [::]:80 ipv6only=on;

    root ${html_dir}/FreshRSS;
    index index.php index.html index.htm;

    server_name _;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        try_files \$uri =404;
        include /etc/nginx/fastcgi_params;
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
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
# centos_6_php_setup
################################################################################

centos_6_php_setup () {

sed -e 's/^;cgi.fix_pathinfo=1$/cgi.fix_pathinfo=0/' -i /etc/php.ini

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

ln -s /usr/share/FreshRSS/p/ "${html_dir}/FreshRSS"

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
# centos_6_permissions
################################################################################

centos_6_permissions () {

chown -R :apache /usr/share/FreshRSS/
chmod -R g+r /usr/share/FreshRSS/
chmod -R g+w /usr/share/FreshRSS/data/

}

################################################################################
# generic_services_systemd
################################################################################

generic_services_systemd () {

systemctl restart php5-fpm
systemctl restart nginx

}

################################################################################
# generic_services_sysvinit
################################################################################

generic_services_sysvinit () {

service php5-fpm restart
service nginx restart

}

################################################################################
# generic_services_upstart
################################################################################

generic_services_upstart () {

service php5-fpm restart
service nginx restart

}

################################################################################
# centos_6_services_upstart
################################################################################

centos_6_services_upstart () {

chkconfig nginx on
chkconfig php-fpm on

service php-fpm restart
service nginx restart
    
}

################################################################################
# make_html_dir
################################################################################

make_html_dir () {

if ! [ -d "${html_dir}" ]; then
    mkdir -p "${html_dir}"
fi

}

################################################################################
# debian_remove_apache
################################################################################

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
echo 'Welcome to this FreshRSS "road warrior" installer'
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
# Check for incompatible OS versions
################################################################################

# TODO!

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

echo 'Okay, that was all we need. We are ready to setup your FreshRSS instance now.'
echo 'Keep an eye on me though, if i think things are going wrong, I will wait for your input.'
read -n1 -r -p "Press any key to continue..."
echo

case $OS in
    Debian*)

        debian_install

        if testvercomp "${VER}" '<' 8; then
            debian_7_nginx
        else
            generic_nginx
        fi

        generic_php_setup
        generic_download
        generic_unzip
        generic_permissions

        make_html_dir

        generic_link

        if testvercomp "${VER}" '<' 8; then
            generic_services_sysvinit
        else
            generic_services_systemd
        fi

        ;;

    Ubuntu)
        ubuntu_install

# Seeing as no one will be using anything other than a LTS when it's this old, < 14.04 is safe enough'
        if testvercomp "${VER}" '<' 14.04; then
            ubuntu_12_04_nginx
        elif testvercomp "${VER}" '<' 16.04; then
            debian_7_nginx
        else
            generic_nginx
        fi

        generic_php_setup
        generic_download
        generic_unzip
        generic_permissions

        make_html_dir

        generic_link

        if testvercomp "${VER}" '<' 15.04; then
            generic_services_upstart
        else
            generic_services_systemd
        fi
        ;;
    CentOS)
        if testvercomp "${VER}" '<' 7; then
            centos_6_install
        else
            redhat_install
        fi

# TODO - Test on newer and narrow versions!
        centos_6_nginx

        centos_6_php_setup
        generic_download
        generic_unzip

        centos_6_permissions

        make_html_dir

        generic_link

# TODO - Test on newer and narrow versions!
        centos_6_services_upstart
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
