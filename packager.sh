#!/bin/dash

# Directories
INSTALLDIR="/usr/local"
BINDIR="$INSTALLDIR/bin"
WEBROOT="/var/www"

# Package lists
WEBSRV=`cat websrv.list`
PHP=`cat php.list`
DB=`cat db.list`
EXTRA=`cat drupal.list`
EXTRA="${EXTRA} `cat extra.list`"

# Colors
YLW="\033[0;33m"
GRY="\033[0;37m"

# check if program is installed and exit if not with error message
require_prog() {
	eval $1=`which $2`
	if [ ! $1 ]; then
		echo "$2 not installed. Use 'apt-get install $2' and run this program again";
		exit 1
	fi
}

# Composer is a handy way to install Drupal. The fastest for a fairly bare-bones install
# is using: '
composer_install() {
	require_prog WGET wget
	require_prog PHP php

	echo "Installing composer..."
	FILENAME="composer-setup.php"
	$WGET -vO "$FILENAME" "http://getcomposer.org/installer"
	$PHP "$FILENAME" --install-dir="/usr/local/bin" --filename="composer"
	chmod 775 "/usr/local/bin/composer"
	chown $USER:$USER /home/$USER/.composer
	rm -f "$FILENAME"

	echo -n "${YLW}INFO${GRY}: To install Drupal, run:"
	echo -n "\$ composer create-project drupal-composer/drupal-project \<project_name\> "
	echo "--stabilty=dev"
	echo -n "${YLW}INFO${GRY}: alternatively, for a full commerce install, use the "
	echo "'acromedia/drupalorange-project-template' project"
}

composer_install_extra() {
	# install the following php packages globally but not as root per composer warning
	if [ ! -z $SUDO_USER ]; then
		USER=$SUDO_USER
	fi
	COMPOSER_HOME="/home/$USER/.composer"
	COMPOSER_VENDOR="$COMPOSER_HOME/vendor"
	sudo -u $USER composer global require drupal/coder
	sudo -u $USER $COMPOSER_VENDOR/bin/phpcs --config-set installed_paths \
$COMPOSER_VENDOR/drupal/coder/coder_sniffer
}

# strictly speaking, not actually configuring nginx (see: add-site.sh) but rather setting
# up the root 'www' directory with correct permissions and ensuring user is added to
# 'www-data' group. It is important that 'package_install()' is run first or this will likely
# fail
nginx_config() {
	echo "Setting $WEBROOT ownership to root:www-data and adding $SUDO_USER to www-data"
	#chown root:www-data $WEBROOT
	#usermod -a -G "www-data" $SUDO_USER
}

# On ubuntu, nodejs is installed as "nodejs" but gulp/sass will fail to install because
# their install scripts expect to find "node". This will create a symlink if node does not
# exist
nodejs_config() {
	require_prog NODEJS nodejs
	if [ ! -e "/usr/bin/node" ] && [ ! -e "/usr/local/bin/node" ] && [ ! $(which "node") ]; then
		echo "'node' not found, creating symlink";
		ln -s $NODEJS "/usr/local/bin/node";
	else
		echo "'node' installed properly";
	fi
}

nodejs_extra() {
	require_prog NPM npm
	$NPM install --global gulp-cli
	$NPM install --global gulp
	$NPM install --global gulp-sass
	$NPM install --global gulp-autoprefixer
}

package_install() {
	echo "Installing necessary packages..."
	echo "apt udate"
	apt-get update
	echo "installing packages";
	apt-get install $WEBSRV $DB $PHP $EXTRA
}

php_config() {
	require_prog GREP grep
	require_prog SED sed

	echo "Configuring PHP"
	PHPINI="/etc/php/7.0/fpm/php.ini"
	if [ ! -f "$PHPINI" ]; then
		echo "couldn't find php.ini"
		exit 2
	fi

	#backup php.ini
	echo "..backing up php.ini"
	cp -v $PHPINI $PHPINI.bak
	$SED -i "s/max_execution_time \= [0-9]*$/max_execution_time \= 300/" $PHPINI
	$SED -i "s/memory_limit \= [0-9]*M$/memory_limit \= 128M/" $PHPINI
	echo "..set: $($GREP 'max_execution_time =' $PHPINI)"
	echo "..set: $($GREP 'memory_limit =' $PHPINI)"

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
	"composer") composer_install;;
	"composer-extra") composer_install_extra ;;
	"node") nodejs_config;;
	"node-extra") nodejs_extra;;
	"php") php_config ;;
	"nginx") nginx_config ;;
	"all")
		package_install # MUST go first
		nginx_config # must come after package_install
		php_config # keep this third
		composer_install; composer_install_extra
		nodejs_config; nodejs-extra
	;;
	*) echo 'enter a command to execute or "all"' ;;
esac

