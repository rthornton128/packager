#!/bin/sh

# Directories
INSTALLDIR="/usr/local"
BINDIR="$INSTALLDIR/bin"

# Package lists
WEBSRV=$(cat "websrv.list")
PHP=$(cat "php.list")
DB=$(cat "db.list")
EXTRA=$(cat "drupal.list") $(cat "extra.list")

package_install() {
	echo "apt udate"
	apt-get update
	echo "installing packages";
	apt-get install $WEBSRV $PHP $DB $EXTRA
}

install_composer() {
	FILENAME="composer-setup.php"
	wget -vO "$FILENAME" "http://getcomposer.org/installer"
	php "$FILENAME" --install-dir="/usr/local/bin" --filename="composer"
	chmod +x "/usr/local/bin/composer"
	rm -f "$FILENAME"
}

case $1 in
	"install") package_install ;;
	"composer") install_composer ;;
	"all")
		package_install
		install_composer
	;;
	*) echo 'enter a command to execute or "all"' ;;
esac

