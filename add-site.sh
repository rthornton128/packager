# add-shite.sh adds new Drupal sites and configures them to be ready for first run

WEBROOT="/var/www"
PROJECT_ROOT="$WEBROOT/$1"
PROJECT_URL="$1.local.com"
DRUPAL_ROOT="$PROJECT_ROOT/web"
NGINX_DIR="/etc/nginx"
NGINX_CONF="drupal.nginx"

cat 127.0.0.1 $PROJECT_URL >> /etc/hosts
sed -e "s#server\_name example\.com;#server_name $PROJECT_URL;#g" -e \
	"s#root /var/www/drupal8;#root $DRUPAL_ROOT;#g" $NGINX_CONF > tmp
chown root:root tmp
cp -fv tmp "$NGINX_DIR/sites-available/$1"
ln -s $NGINX_"DIR/sites-available/$1" "$NGINX_DIR/sites-enabled/$1"
sudo -u $SUDO_USER composer create-project drupal-composer/drupal-project $PROJECT_ROOT \
	--stability=dev
echo "Project installed to $PROJECT_ROOT"

