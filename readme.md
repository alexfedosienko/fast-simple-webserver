# Быстрая установка и настройка простого веб сервера на Ubuntu 18.04

### Данный скрипт устанавливает сборку:
- Nginx - в роли прокси для apache2
- Apache - веб-сервер
- MariaDB - MySQL сервер
- Memcached - кэширование
- proFTPd - FTP сервер
- PHP + PHP-FPM (fastCGI)
- Postfix - почтовый сервер

### Сама установка:

* Подключаемся к серверу по SSH
```ssh root:password@server_ip```
* Обновляемся и устанавливаем git
```apt-get --yes update && apt-get --yes upgrade && apt-get --yes install git```
* Клонируем репозиторий
```git clone https://github.com/alexfedosienko/fast-simple-webserver.git```
* Переходим в директорию и делаем файлы исполняемыми
```cd fast-simple-webserve && chmod +x autoinstall.sh && chmod +x addsite.sh```
* Запускаем установку
```sh autoinstall.sh```
* Добавляем сайт без ssl
```sh addsite.sh domain.ru no-ssl```
* Добавляем сайт с ssl (для создания сайта с ssl нужно создать сайт без ssl)
```sh addsite.sh domain.ru ssl```