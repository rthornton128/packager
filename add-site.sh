#!/bin/bash -x

# add-site.sh adds new Drupal sites and configures them to be ready for first run

WEBROOT="/var/www"
PROJECT_ROOT="$WEBROOT/$1"
PROJECT_URL="$1.local.com"
DRUPAL_ROOT="$PROJECT_ROOT/web"
NGINX_DIR="/etc/nginx"
NGINX_CONF="drupal.nginx"
DRUPAL_DB="${1//-}d8db"
DRUPAL_USER="${1//-}drupal"
DRUPAL_PWD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | head -c 10)
SETTINGS="$DRUPAL_ROOT/sites/default/settings.local.php"

if [ -z $1 ]; then
	echo "must include name of project to create";
	exit 1;
fi

# add-site.sh should be run as root (sudo)
if [ $EUID -ne 0 ]; then
	echo "this program should be run as root"
	exit 1;
fi

# add to /etc/hosts only if it doesn't already exist
grep -q $PROJECT_URL /etc/hosts;
if [ $? -eq 1 ]; then
	echo "127.0.0.1 $PROJECT_URL" >> /etc/hosts
fi


# nginx site setup
sed -e "s#server\_name example\.com;#server_name $PROJECT_URL;#g" \
 -e "s#root /var/www/drupal8;#root $DRUPAL_ROOT;#g" $NGINX_CONF > tmp
chown root:root tmp
cp -nv tmp "$NGINX_DIR/sites-available/$1"
ln -s "$NGINX_DIR/sites-available/$1" "$NGINX_DIR/sites-enabled/$1"
service nginx restart

mkdir -p $PROJECT_ROOT;
chown $SUDO_USER:$SUDO_USER $PROJECT_ROOT

# create Drupal base if not pulling from an existing git repo
if [ -z "$2" ] || [ "$2" == " " ]; then
	#sudo -u $SUDO_USER composer create-project drupal-composer/drupal-project \
	#sudo -u $SUDO_USER composer create-project drupalcommerce/project-base \
	sudo -u $SUDO_USER composer create-project \
 acromedia/drupalorange-project-template $PROJECT_ROOT --stability=dev;
else
	sudo -u $SUDO_USER git clone $2 $PROJECT_ROOT;
	cd $PROJECT_ROOT;
	sudo -u $SUDO_USER composer update;
	cd -;
fi

mysql -ve "CREATE USER '$DRUPAL_USER'@'localhost' IDENTIFIED BY '$DRUPAL_PWD';"
mysql -ve "CREATE DATABASE $DRUPAL_DB;"
mysql -ve "GRANT ALL PRIVILEGES ON $DRUPAL_DB.* TO '$DRUPAL_USER'@'localhost';"

# Install the site with vendor local drush installation
cd $PROJECT_ROOT/web;
sudo -u $SUDO_USER ../vendor/bin/drush site-install \
${DRUPAL_PROFILE} \
--site-name=$1 \
--acount-pass=admin \
--db-url=mysql://${DRUPAL_USER}:${DRUPAL_PWD}@localhost/${DRUPAL_DB}

echo "Project installed to $PROJECT_ROOT"

