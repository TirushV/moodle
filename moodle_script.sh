#!/bin/bash

echo "********************************************************************"
echo "Please enable port 80 and 443 inbound rules in the security group...."
echo "********************************************************************"
# Install Nginx and enable to start on boot
sudo apt-get update -y
echo "********************************************************************"
echo "Updated the server...."
sleep 2
echo "Installing nginx webserver...."
echo "********************************************************************"
sudo apt-get install nginx -y
sudo systemctl stop nginx
sudo systemctl start nginx
sudo systemctl enable nginx
echo "Successfully installed nginx...."
echo "********************************************************************"

# Install MariaDB and enable to start on boot
sleep 2
echo "Installing mariadb-server...."
sudo apt-get install mariadb-server -y
echo "Installing mariadb-client...."
sudo apt-get install mariadb-client -y
sudo systemctl stop mariadb
sudo systemctl start mariadb
sudo systemctl enable mariadb
echo "Successfully installed mariadb...."
echo "********************************************************************"

# mysql secure installation for root
sleep 2
echo "mysql secure installation for root with no password"
mysql_secure_installation <<EOF

n
y
y
y
y
EOF
echo "********************************************************************"
#sed '28 i innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf # Practice command

# real command for updating db configuration
sed -i '25 i innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf > /tmp/sucess.txt
echo "Updated innodb_file_format to Barracuda...."
sed -i '26 i innodb_file_per_table = 1' /etc/mysql/mariadb.conf.d/50-server.cnf > /tmp/sucess.txt
echo "Updated innodb_file_per_table to 1...."
sed -i '27 i innodb_large_prefix = ON' /etc/mysql/mariadb.conf.d/50-server.cnf > /tmp/sucess.txt
echo "Updated innodb_large_prefix to ON...."
echo "Now restarting the database...."
sudo systemctl restart mariadb
echo "********************************************************************"

# To a third-party repository with the latest versions of PHP
sleep 2
echo "Installing third party repository for php latest packages...."
sudo apt-get install software-properties-common -y

sudo add-apt-repository ppa:ondrej/php <<EOF


EOF
echo "Repo added...."

# Update the packages to install php 7.4
sleep 2
echo "Now updating the server...."
sudo apt update -y
echo "Successfully done updating the packages...."
echo "********************************************************************"

# Install required packages for php
sleep 2
echo "Now installing php required packages"
sudo apt install php7.4-fpm php7.4-common php7.4-mysql php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-xmlrpc php7.4-gd php7.4-xml php7.4-cli php7.4-zip -y

# Updating php.ini file to increase limits of moodle
echo "Updating php.ini file to increase limits of moodle...."
sed -i 's/memory_limit = 128M/memory_limit = 256M/g' /etc/php/7.4/fpm/php.ini
echo "Updated memory_limit from 128M to 256M.... in /etc/php/7.4/fpm/php.ini file"
sed -i "s/upload_max_filesize = 8M/upload_max_filesize = 100M/g" /etc/php/7.4/fpm/php.ini
echo "Updated upload_max_filesize from 8M to 100M...."
sed -i "s/max_execution_time = 30/max_execution_time = 360/g" /etc/php/7.4/fpm/php.ini
sed -i "s/;date.timezone = America/Chicago/date.timezone = Asia/Kolkata/g" /etc/php/7.4/fpm/php.ini
# sed -i "s/max_execution_time = 30/max_execution_time = 360/g" /etc/php/7.4/fpm/php.ini
echo "********************************************************************"
service php7.4-fpm restart

echo "Updating sql queries inside file...."
echo "********************************************************"
echo "**** Need a password please enter a password for db ****"
# echo $1
#read -s -p "Password: " varname
cat > mysql.txt << EOF
CREATE DATABASE moodle;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'password';
GRANT ALL ON moodle.* TO 'moodleuser'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EXIT;
EOF
echo "********************************************************************"

echo "Running SQL Queries using root"
mysql --user=root --password="password" < mysql.txt
echo "Successfully completed...."
echo "********************************************************************"
rm -rf mysql.txt
echo "Deleted mysql file after updating database...."

# Install git and curl
echo "Installing git and curl"
sudo apt install git curl -y

echo "Changing the directory...."
cd /var/www/html
echo "Downloading moodle code...."
sudo git clone -b MOODLE_39_STABLE git://git.moodle.org/moodle.git moodle

echo "Updating directory permissions"
sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/
sudo chmod -R 755 /var/www/

# Delete default files of nginx
rm -rf /etc/nginx/sites-available/default
rm -rf /etc/nginx/sites-enabled/default
#read -p "Enter the domain: " domain
cat > /etc/nginx/sites-available/moodle << 'EOF'
server {
    listen 80;
    listen [::]:80;
    root /var/www/html/moodle;
    index  index.php;
    server_name localhost;

    client_max_body_size 100M;
    autoindex off;
    location / {
        try_files $uri $uri/ =404;
    }

    location ~ [^/].php(/|$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF

sed -i "s+localhost+$1+g" /etc/nginx/sites-available/moodle

sleep 5
ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled

sleep 2
echo "Renaming config-dist.php to config.php...."
cd /var/www/html/moodle
sudo mv config-dist.php config.php

echo "Updating database name from pgsql to mariadb"
sed -i "s/pgsql/mariadb/g" /var/www/html/moodle/config.php

echo "Updating username...."
sed -i "s/username/moodleuser/g" /var/www/html/moodle/config.php

sed -i "s/password/password/g" /var/www/html/moodle/config.php

echo "Updating the url...."
sed -i "s+http://example.com/moodle/https://$1+g" /var/www/html/moodle/config.php

echo "Updated moodledata directory path...."
sed -i "s+/home/example/moodledata+/var/www/moodledata+g" /var/www/html/moodle/config.php # need to update

echo "Changing permissions...."
sed -i "s+02777+0777+g" /var/www/html/moodle/config.php

echo "Restarting nginx webserver...."
sudo systemctl restart nginx

#Install certbot for ssl
echo "Installing certbot for getting ssl of moodle website...."
sudo apt install certbot python3-certbot-nginx -y

sudo certbot -n --nginx -d $1 -m tirushv9@gmail.com --redirect --agree-tos
echo "Installed ssl certificate! now you can access the server at: https://$1 ....!"
# sudo certbot -n --nginx -d building.tirush.tech -m tirushv9@gmail.com --redirect --agree-tos
