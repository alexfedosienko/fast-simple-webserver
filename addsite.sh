#!bash
DOMAIN_NAME=$1
IS_SSL=$2
PWD_LENGTH=8
FTP_PASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c ${PWD_LENGTH};)
MYSQL_PASSWD=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c ${PWD_LENGTH};)
MYSQL_DB_NAME=$(echo ${DOMAIN_NAME} | tr '[.]' '[_]')

if [ ! $IS_SSL ]; then
	IS_SSL="no-ssl"
fi

if [ $DOMAIN_NAME ]; then
	mkdir -p /var/www/$DOMAIN_NAME/www
	mkdir -p /var/www/$DOMAIN_NAME/tmp
	mkdir -p /var/www/$DOMAIN_NAME/log/nginx
	mkdir -p /var/www/$DOMAIN_NAME/log/apache

	chown -R www-data:www-data /var/www/$DOMAIN_NAME
	chmod -R 775 /var/www/$DOMAIN_NAME

	echo "<?php echo '<h1>Hello from $DOMAIN_NAME</h1>'; ?>" >> /var/www/$DOMAIN_NAME/www/index.php

	cat > "/etc/apache2/sites-enabled/$DOMAIN_NAME.conf" <<EOF
<VirtualHost *:8080>
    ServerName $DOMAIN_NAME
    ServerAlias www.$DOMAIN_NAME
    DocumentRoot /var/www/$DOMAIN_NAME/www
    Options -Indexes

    ErrorLog /var/www/$DOMAIN_NAME/log/apache/error_log
    TransferLog /var/www/$DOMAIN_NAME/log/apache/access_log

    php_admin_value upload_tmp_dir /var/www/$DOMAIN_NAME/tmp
    php_admin_value doc_root /var/www/$DOMAIN_NAME
    php_admin_value open_basedir /var/www/$DOMAIN_NAME:/usr/local/share/smarty:/usr/local/share/pear
    php_admin_value session.save_path 0;0660;/var/www/$DOMAIN_NAME/tmp
</VirtualHost>
EOF

	if [ $IS_SSL = "no-ssl" ]; then
		cat > "/etc/nginx/sites-enabled/$DOMAIN_NAME.conf" <<EOF
server {
	set \$root_path /var/www/$DOMAIN_NAME/www;

	listen 80;
	server_name $DOMAIN_NAME www.$DOMAIN_NAME;
	
	access_log /var/www/$DOMAIN_NAME/log/nginx/access_log;
	error_log /var/www/$DOMAIN_NAME/log/nginx/error_log;

	gzip on;
	gzip_disable "msie6";
	gzip_min_length 1000;
	gzip_vary on;
	gzip_proxied expired no-cache no-store private auth;
	gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;

	root \$root_path;
	index index.php index.html index.htm;

	location / {
		proxy_pass http://127.0.0.1:8080/;
		proxy_redirect off;
		proxy_set_header Host \$host;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For  \$proxy_add_x_forwarded_for;
	}

	location ~* ^.+\.(jpg|jpeg|gif|png|css|zip|tgz|gz|rar|bz2|doc|docx|xls|xlsx|exe|pdf|ppt|tar|wav|bmp|rtf|js)$ {
		expires modified +1w;
	}
}
EOF

		echo ${FTP_PASSWD} | ftpasswd --stdin --passwd --file=/etc/proftpd/ftpd.passwd --name=$DOMAIN_NAME --uid=33 --gid=33 --home=/var/www/$DOMAIN_NAME --shell=/usr/sbin/nologin

		mysql -uroot -p1 <<EOF
CREATE DATABASE ${MYSQL_DB_NAME} DEFAULT CHARACTER SET utf8 DEFAULT COLLATE utf8_general_ci;
GRANT ALL PRIVILEGES ON ${MYSQL_DB_NAME}.* TO ${MYSQL_DB_NAME}@localhost IDENTIFIED BY '${MYSQL_PASSWD}' WITH GRANT OPTION;
quit
EOF

		echo "------------------------------------------------------------"
		echo "Доступ для сайта ${DOMAIN_NAME}"
		echo "--------"
		echo "Доступ к базе данных MySQL:"
		echo "Логин - ${DOMAIN_NAME} Пароль - ${MYSQL_PASSWD} База данных - ${MYSQL_DB_NAME}"
		echo "--------"
		echo "Доступ к FTP:"
		echo "Логин - ${FTP_PASSWD} Пароль - ${DOMAIN_NAME}"
		echo "------------------------------------------------------------"

	fi

	if [ $IS_SSL = "ssl" ]; then

		certbot certonly --register-unsafely-without-email --agree-tos --webroot -w /var/www/$DOMAIN_NAME/www -d $DOMAIN_NAME -d www.$DOMAIN_NAME

		if [ -f "/etc/nginx/sites-enabled/$DOMAIN_NAME.conf" ]; then
			cp /etc/nginx/sites-enabled/$DOMAIN_NAME.conf /etc/nginx/${DOMAIN_NAME}_no_ssl.conf
			rm /etc/nginx/sites-enabled/$DOMAIN_NAME.conf
		fi

cat > "/etc/nginx/sites-enabled/$DOMAIN_NAME.conf" <<EOF
server {
	listen 80;
	server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
	return 301 https://\$host\$request_uri;
}

server {
	listen 443 ssl;
	ssl on;
	ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;

	server_name $DOMAIN_NAME www.$DOMAIN_NAME;
	set \$root_path /var/www/$DOMAIN_NAME/www;

	access_log /var/www/$DOMAIN_NAME/log/nginx/access_log;
	error_log /var/www/$DOMAIN_NAME/log/nginx/error_log;

	gzip on;
	gzip_disable "msie6";
	gzip_min_length 1000;
	gzip_vary on;
	gzip_proxied expired no-cache no-store private auth;
	gzip_types text/plain text/css application/json application/x-javascript text/xml application/xml application/xml+rss text/javascript application/javascript;

	root \$root_path;
	index index.php index.html index.htm;

	location / {
		proxy_pass http://127.0.0.1:8080/;
		proxy_redirect off;
		proxy_set_header Host \$host:\$server_port;
		proxy_set_header X-Forwarded-Proto \$scheme;
		proxy_set_header X-Real-IP \$remote_addr;
		proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
	}
    
	location ~* ^.+\.(jpg|jpeg|gif|png|css|zip|tgz|gz|rar|bz2|doc|docx|xls|xlsx|exe|pdf|ppt|tar|wav|bmp|rtf|js)$ {
		expires modified +1w;
	}
}
EOF
	fi

	nginx -t
	apachectl configtest
	systemctl reload nginx
	systemctl reload apache2
else
	echo "Не указано доменное имя!"
fi