#!/bin/dash

# Directories
INSTALLDIR="/usr/local"
BINDIR="$INSTALLDIR/bin"
WEBROOT="/var/www"

# Package lists
WEBSRV=$(cat "websrv.list")
PHP=$(cat "php.list")
DB=$(cat "db.list")
EXTRA=$(cat "drupal.list") $(cat "extra.list")

# Colors
YLW="\033[0;33m"
GRY="\033[0;37m"

# Composer is a handy way to install Drupal. The fastest for a fairly bare-bones install
# is using: '
install_composer() {
	WGET=$(which "wget")
	echo "Output=$WGET"
	if [ ! $WGET ]; then
		echo "wget not installed. Use 'apt-get install wget' and run this program again";
		return 1
	fi

	PHP=$(which "php")
	if [ ! $PHP ]; then
		echo "php not installed. Use 'apt-get install php' and run this program again";
	fi

	echo "Installing composer..."
	FILENAME="composer-setup.php"
	wget -vO "$FILENAME" "http://getcomposer.org/installer"
	php "$FILENAME" --install-dir="/usr/local/bin" --filename="composer"
	chmod +x "/usr/local/bin/composer"
	rm -f "$FILENAME"

	echo -n "${YLW}INFO${GRY}: To install Drupal, run:"
	echo -n "\$ composer create-project drupal-composer/drupal-project \<project_name\> "
	echo "--stabilty=dev"
	echo -n "${YLW}INFO${GRY}: alternatively, for a full commerce install, use the "
	echo "'acromedia/drupalorange-project-template' project"
}

# strictly speaking, not actually configuring nginx (see: add-site.sh) but rather setting
# up the root 'www' directory with correct permissions and ensuring user is added to
# 'www-data' group. It is important that 'package_install()' is run first or this will likely
# fail
nginx_config() {
	echo "Setting $WEBROOT ownership to root:www-data and adding $SUDO_USER to www-data"
	chown "root:www-data $WEBROOT"
	usermod -a -G "www-data" $SUDO_USER
}

package_install() {
	echo "Installing necessary packages..."
	echo "apt udate"
	apt-get update
	echo "installing packages";
	apt-get install $WEBSRV $PHP $DB $EXTRA
}

php_config() {
	GREP=$(which "grep")
	if [ ! $GREP ]; then
		echo "grep not installed. Use 'apt-get install grep' and run this program again";
		return 1
	fi

	SED=$(which "sed")
	if [ ! $SED ]; then
		echo "sed not installed. Use 'apt-get install sed' and run this program again";
		return 1
	fi

	echo "Configuring PHP"
	if [ ! -f "/etc/php/7.0/fpm/php.ini" ]; then
		echo "couldn't find php.ini"
		return 2
	fi

	PHPINI="/etc/php/7.0/fpm/php.ini"

	#backup php.ini
	echo "..backing up php.ini"
	cp -f $PHPINI $PHPINI.bak
	$SED -i "s/max_execution_time \= [0-9]*$/max_execution_time \= 300/" $PHPINI
	$SED -i "s/memory_limit \= [0-9]*M$/memory_limit \= 128M/" $PHPINI
	echo "..set: $($GREP 'max_execution_time =')"
	echo "..set: $($GREP 'memory_limit =')"

	XDEBUG="/etc/php/7.0/fpm/conf.d/20-xdebug.ini" 
	if [ -f $XDEBUG ]; then
		echo "Configuring xdebug.ini..."
		if [ $(grep "remote_enable" $XDEBUG) ]; then
			echo "xdebug already configured, skipping"
		else
			echo "..backing up $XDEBUG"
			cp -f $XDEBUG $XDEBUG.bak
			echo "xdebug.remote_enable=1" >> $XDEBUG
			echo "xdebug.remote_host=localhost" >> $XDEBUG
			echo "xdebug.remote_port=9000" >> $XDEBUG
		fi
	else
		echo "xdebug.ini not found, skipping"
	fi
}

case $1 in
	"install") package_install ;;
	"composer") install_composer ;;
	"php") php_config ;;
	"nginx") nginx_config ;;
	"all")
		package_install
		nginx_config # must come after package_install
		php_config
		install_composer
	;;
	*) echo 'enter a command to execute or "all"' ;;
esac

