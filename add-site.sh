#!/bin/bash

# add-site.sh adds new Drupal sites and configures them to be ready for first run

if [ $# -ne 2 ] ; then
	echo "Usage: add-site.sh PATH SQL_DB"
	exit 1
fi

# add-site.sh should be run as root (sudo)
if [ $EUID -ne 0 ]; then
	echo "this program should be run as root"
	exit 1;
fi

ROOT=`realpath $1`
PROJECT=`basename $1`
USER="$SUDO_USER"
GROUP="www-data"
REMOTE=""
DOMAIN="local.com"
URL="$PROJECT.$DOMAIN"
NGINXCONF="/etc/nginx"
HOSTENTRY="N"
PHPVER="7.x"
DRUPALVER="7"
DBUSER="acro"
DBPASS=""
SQLDB=`realpath $2`
WEBROOT="wwwroot"
SETTINGSDIR="sites/default"
FILESDIR="files"
PRIVATEDIR="files/private"
TMPDIR=$ROOT"/.tmp"

read -p "Project name [$PROJECT]: " choice
if [ ! -z "$choice" ] ; then PROJECT=$choice; fi

read -p "User/owner [$USER]: " choice
if [ ! -z "$choice" ] ; then USER=$choice ; elif [ -z $USER ] ; then USER="root" ; fi

read -p "Web server group [$GROUP]: " choice
if [ ! -z "$choice" ] ; then GROUP=$choice; fi

read -p "Remote URL [$REMOTE]: " choice
if [ ! -z "$choice" ] ; then REMOTE=$choice; fi

read -p "Local dev domain (localhost, dev, example.com) [$DOMAIN]: " choice
if [ ! -z "$choice" ] ; then DOMAIN=$choice; fi

read -p "Nginx settings directory [$NGINXCONF]: " choice
if [ ! -z "$choice" ] ; then NGINXCONF=$choice; fi

read -p "Create /etc/hosts entry? [$HOSTENTRY]: " choice
case "$choice" in y|Y) HOSTENTRY=Y ;; esac

read -p "PHP version [$PHPVER]: " choice
case "$choice" in 5|5.?) PHPVER="5.6" ;; *) PHPVER="7" ;; esac

read -p "Drupal version [$DRUPALVER]: " choice
case "$choice" in 6|7|8) DRUPALVER="$choice" ;; esac

read -p "Database User [$DBUSER]: " choice
if [ ! -z "$choice" ] ; then DBUSER=$choice; fi

read -p "Database Password (empty okay) [$DBPASS]: " choice
if [ ! -z "$choice" ] ; then DBPASS=$choice; fi

if [ "$DRUPALVER" = "8" ] ; then WEBROOT="www" ; fi
read -p "Web root [$WEBROOT]: " choice
if [ ! -z "$choice" ] ; then WEBROOT=$choice; fi

read -p "Settings directory [$SETTINGSDIR]: " choice
if [ ! -z "$choice" ] ; then SETTINGSDIR=$choice; fi

read -p "Public files directory [$FILESDIR]: " choice
if [ ! -z "$choice" ] ; then FILESDIR=$choice; fi

read -p "Private files directory [$PRIVATEDIR]: " choice
if [ ! -z "$choice" ] ; then PRIVATEDIR=$choice; fi

read -p "Temporary files directory [$TMPDIR]: " choice
if [ ! -z "$choice" ] ; then TMPDIR=$choice; fi

#update URL
URL="$PROJECT.$DOMAIN"

#check settings.php setup
SETTINGSPATH="$ROOT/$WEBROOT/$SETTINGSDIR"
LOCALREADY="N"
HASSETTINGS="N"
if [ -f "$SETTINGSPATH/settings.php" ] ; then
    HASSETTINGS="Y"
    grep "settings\.local\.php" "$SETTINGSPATH/settings.php" > /dev/null
    if [ $? -eq 0 ] ; then
        LOCALREADY="Y"
    fi
elif [ -f "$SETTINGSPATH/default.settings.php" ] ; then
    `grep "settings\.local\.php" "$SETTINGSPATH/default.settings.php"` > /dev/null
    if [ $? -eq 0 ] ; then
        LOCALREADY="Y"
    fi
fi

echo
echo "SUMMARY"
echo "-------"
echo "Project: $PROJECT"
echo "Owner: $USER"
echo "Group: $GROUP"
echo "Remote URL: $REMOTE"
echo "Install dir: $ROOT"
echo "Local URL: $URL"
echo "Remote URL: $REMOTE"
echo "Add /etc/hosts entry: $HOSTENTRY"
echo "PHP Version: $PHPVER"
echo "Drupal Version: $DRUPALVER"
echo "SQL Database to Import: $SQLDB"
echo "Database credentials: $DBUSER:$DBPASS"
echo "settings.php directory: $SETTINGSDIR"
echo "settings.php exists: $HASSETTINGS"
echo "settings.local.php ready: $LOCALREADY"
echo "files directory: $FILESDIR"
echo "private directory: $PRIVATEDIR"
echo "tmp directory: $TMPDIR"
echo
read -p "Do you wish to continue? [Y] " choice
case $choice in n|N) echo ; echo "Cancelled!" ; exit 0 ;; esac

# append to /etc/hosts only if it doesn't already exist
if [ "$HOSTENTRY" = "Y" ] ; then
    echo "Appending $URL to /etc/hosts..."
    grep -q "$URL" /etc/hosts;
    if [ $? -eq 1 ]; then
    	echo 'echo "127.0.0.1 $URL" >> /etc/hosts'
    fi
fi

# Create local site and restart nginx service
echo "Creating nginx settings..."
sed -e "s#{WEBROOT}#$ROOT/$WEBROOT#" \
 -e "s#{URL}#$URL#" \
 -e "s#{PHPVER}#$PHPVER#" \
 -e "s#{DRUPALVER}#$DRUPALVER#" \
 drupal.nginx > "$PROJECT.conf"
echo cp -f "$PROJECT.conf" "/etc/nginx/sites-available/$PROJECT.conf"
echo ln -s "/etc/nginx/sites-available/$PROJECT.conf" "/etc/nginx/sites-enabled/$PROJECT.conf"
echo service nginx restart
echo rm -f "$PROJECT.conf"

echo "Create settings directories with correct permissions and ownership..."
echo mkdir -p "$SETTINGSPATH/$FILESDIR"
echo mkdir -p "$SETTINGSPATH/$PRIVATEDIR"
echo chown "$USER:$GROUP" "$SETTINGSPATH/$FILESDIR"
echo chown "$USER:$GROUP" "$SETTINGSPATH/$PRIVATEDIR"
echo chmod 2775 "$SETTINGSPATH/$FILESDIR"
echo chmod 2775 "$SETTINGSPATH/$PRIVATEDIR"

echo "Creating temp directory if it doesn't already exist..."
if [ -d "$TMPDIR" ] ; then
    echo mkdir "$TMPDIR"
fi

echo "Setup settings.local.php..."
if [ $HASSETTINGS = "N" ] ; then
    echo cp "$SETTINGSPATH/default.settings.php" "$SETTINGSPATH/settings.php"
fi
if [ $LOCALREADY = "N" ] ; then
    echo cat "$local_settings = dirname(__FILE__) . '/settings.local.php';" >> "$SETTINGSPATH/settings.php"
    echo cat "if (file_exists($local_settings)) {" >> "$SETTINGSPATH/settings.php"
    echo cat "  include $local_settings;" >> "$SETTINGSPATH/settings.php"
    echo cat "}" >> "$SETTINGSPATH/settings.php"
fi
LOCALSETTINGS="d$DRUPALVER.settings.local.php"
sed -e "s#{DBNAME}#$PROJECT#" \
 -e "s#{DBUSER}#$DBUSER#" \
 -e "s#{DBPASS}#$DBPASS#" \
 -e "s#{FILESDIR}#$FILESDIR#" \
 -e "s#{PRIVATEDIR}#$PRIVATEDIR#" \
 -e "s#{TMPDIR}#$TMPDIR#" \
 -e "s#{REMOTE}#$REMOTE#" \
  "$LOCALSETTINGS" > "$PROJECT.settings.php"
echo cp -f  "$PROJECT.settings.php" "$SETTINGSPATH/settings.local.php"
echo chmod 440 "$SETTINGSPATH/settings.php"
echo chmod 440 "$SETTINGSPATH/settings.local.php"
echo rm "$PROJECT.settings.php"

# Install database
echo "Installing database..."
echo mysql -ve "CREATE DATABASE $PROJECT;"
echo mysql -ve "GRANT ALL PRIVILEGES ON $PROJECT.* TO '$DBUSER'@'localhost';"
case "$SQLDB" in
*.gz | *.tgz)
    echo zcat $SQLDB | mysql
;;
*)
    echo mysql < $SQLDB
;;
esac

echo "Checking for composer..."
if [ -f "$ROOT/composer.json" ] ; then
    echo "Running composer install..."
    echo cd "$ROOT"
    echo composer install
elif [ -f "$ROOT/$WEBROOT/composer.json" ] ; then
    echo "Running composer install..."
    echo cd "$ROOT/$WEBROOT"
    echo composer install
fi

echo "Executing drush to clear all caches..."
echo cd "$ROOT/$WEBROOT"
case $DRUPALVER in
6|7) echo drush cc all -y ;;
8) echo drush cr -y ;;
esac

echo "Project '$PROJECT' setup. You may now browse the site at: $URL!"
