#!bash
# Количество символов в паролях
PWD_LENGTH=8

TIMEZONE="Asia/Yekaterinburg"

FTP_ROOT_USER="root_ftp"
FTP_ROOT_PASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c ${PWD_LENGTH};)
MYSQL_ROOT_PASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c ${PWD_LENGTH};)

apt-get --yes install chrony mc nano htop nginx php php-fpm mariadb-server php-mysql php-mysqli memcached php-memcached proftpd apache2 libapache2-mod-php certbot
timedatectl set-timezone ${TIMEZONE}
iptables -A INPUT -p tcp --match multiport --dports 20,21,25,80,443,465,587,8080,60000:65535 -j ACCEPT

cp -f -R etc /
cp -f -R var /

rm -r etc
rm -r var

nginx -t && apachectl configtest

mysqladmin -u root password ${MYSQL_ROOT_PASSWD}
echo ${FTP_ROOT_PASSWD} | ftpasswd --stdin --passwd --file=/etc/proftpd/ftpd.passwd --name=${FTP_ROOT_USER} --uid=33 --gid=33 --home=/var/www --shell=/usr/sbin/nologin

a2dismod mpm_event
a2enmod mpm_prefork
a2enmod php7.2
a2enmod setenvif

systemctl enable apache2
systemctl start apache2
systemctl restart apache2
systemctl enable nginx
systemctl restart nginx
systemctl enable php7.2-fpm
systemctl restart php7.2-fpm
systemctl enable memcached
systemctl enable mariadb
systemctl enable proftpd
systemctl restart proftpd

echo "------------------------------------------------------------"
echo "Доступ к базе данных MySQL:"
echo "Логин - root Пароль - ${MYSQL_ROOT_PASSWD}"
echo "--------"
echo "Доступ к FTP:"
echo "Логин - ${FTP_ROOT_USER} Пароль - ${FTP_ROOT_PASSWD}"
echo "------------------------------------------------------------"
