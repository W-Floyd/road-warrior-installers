#!/bin/bash

# Only tested on a bone stock Brie Host $2/year VPS, running Ubuntu 15.04
# It *will* *not* *work* on many other providers at this point in time

# ask() copied from https://gist.github.com/davejamesmiller/1965569
# ask "Question?" Y|N
# Where Y|N is an optional default
ask() {
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

if [[ "$EUID" -ne 0 ]]; then
	echo "Sorry, you need to run this as root"
	exit 1
fi

clear
echo 'Welcome to this quick FreshRSS "road warrior" installer'
echo
echo 'This installer *will* destroy any existing config.'
if ! ask 'Are you sure you want to continue?' N; then
    exit
fi

echo

if ask 'Do you have IPv4 access?' Y; then
    alt_download=false
    address="$(wget -qO- https://canihazip.com/s)"
else
    alt_download=true
    address="$(wget -qO- http://v6.ipv6-test.com/api/myip.php)"
    echo 'Github does not support IPv6, so you will need to upload it yourself.'
    echo 'On an IPv4 enabled machine, please run:'
    echo "wget 'https://github.com/FreshRSS/FreshRSS/archive/master.zip'"
    echo "scp master.zip root@\[${address}\]:/usr/src/master.zip"
    echo
    until [[ -e '/usr/src/master.zip' ]]; do
        sleep 0.1s
    done
    read -n1 -r -p "Press any key to continue once the transfer is completed..."
fi

echo 'Okay, that was all I needed. We are ready to setup your FreshRSS instance now'
read -n1 -r -p "Press any key to continue..."
echo

apt-get update
apt-get install unzip nginx php5-fpm php5-curl php5-gmp php5-intl php5-json php5-sqlite -y

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

sed -e 's/^;cgi.fix_pathinfo=1$/cgi.fix_pathinfo=0/' -i /etc/php5/fpm/php.ini

if [[ "${alt_download}" = false ]]; then
    wget https://github.com/FreshRSS/FreshRSS/archive/master.zip -O /usr/src/master.zip
fi

unzip /usr/src/master.zip -d /usr/share/ &> /dev/null

mv /usr/share/FreshRSS-master/ /usr/share/FreshRSS/

ln -s /usr/share/FreshRSS/p/ /var/www/html/FreshRSS

chown -R :www-data /usr/share/FreshRSS/
chmod -R g+r /usr/share/FreshRSS/
chmod -R g+w /usr/share/FreshRSS/data/

systemctl enable php5-fpm
systemctl restart php5-fpm

systemctl enable nginx
systemctl restart nginx

if [[ "${alt_download}" = true ]]; then
    echo -n "Please visit http://[${address}]"
else
    echo -n "Please visit http://${address}"
fi

echo ' to complete the setup process.'

exit
