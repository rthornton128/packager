#!/bin/bash

# do a quick sanity check to see if script is being run on a
# Ubuntu based system and PHP is installed.
if [ -z "$(uname -a | grep '[Uu]buntu')" ] ; then
    echo "WARN: Ubuntu based system expected; run at your own risk"
    read -p "Press any key to continue..." -n 1
    echo
fi

db_conf() {
    # attempt to detect installed database server if not already cached
    if [ -z "$DB" ] ; then 
        DB=$(ps -A | grep -o -m 1 "mysql\|mariadb\|pgsql")
    fi
    if [ -z "$DB" ] ; then
        DB=$(dpkg -l | grep -o -m 1 "mysql\|mariadb\|pgsql")
    fi
    read -p "Database server [$DB]: " choice
    if [ $choice ] ; then DB=$choice ; fi

    if [ -z "$DBADDR" ] ; then DBADDR="localhost" ; fi
    read -p "Database address [$DBADDR]: " choice
    if [ $choice ] ; then DBADDR=$choice ; fi

    if [ -z "$DBPORT" ] ; then DBPORT="80" ; fi
    read -p "Database port [$DBPORT]: " choice
    if [ $choice ] ; then DBPORT=$choice ; fi
    
    read -p "Database user [$DBUSER]: " choice
    if [ $choice ] ; then DBUSER=$choice ; fi
    
    read -p "Database password [$DBPASS]: " choice
    if [ $choice ] ; then DBPASS=$choice ; fi
    return
}

db_setting() {
    echo "Database server: $DB"
    echo "Database address: $DBADDR"
    echo "Database port: $DBPORT"
    echo "Database user: $DBUSER"
    echo "Database password: $DBPASS"
    if [ $DBPATH ] ; then echo "Database to import: $DBPATH" ; fi
    return
}

db_run() {
    case $DB in 
        mysql|mariadb)
            mysql -ve "DROP DATABASE IF EXISTS $PROJECT;"
            mysql -ve "CREATE DATABASE $PROJECT;"
            mysql -ve "GRANT ALL PRIVILEGES ON $PROJECT.* TO '$DBUSER'@'localhost';"
            case "$DBPATH" in
                *.gz | *.tgz) zcat $DBPATH | mysql $PROJECT ;;
                *.sql) mysql $PROJECT < $DBPATH ;;
            esac
            ;;
        pgsql)
            echo "Please configure postgres manually"
            ;;
    esac

    # output cache data
    echo "DB=$DB" >> $CACHEFILE
    echo "DBADDR=$DBADDR" >> $CACHEFILE
    echo "DBPORT=$DBPORT" >> $CACHEFILE
    echo "DBUSER=$DBUSER" >> $CACHEFILE
    echo "DBPASS=$DBPASS" >> $CACHEFILE
    return
}

drupal_conf() {
    # check for Drupal version
    TMP=$PROJECTPATH
    TMP="$(find $TMP -name system.info -o -name system.info.yml 2>/dev/null)"
    if [ "$TMP" ] ; then
        DRUPALVER="$(grep "^core" $TMP | grep -o "[0-9]" | head -1)"
    fi
    read -p "Drupal version [$DRUPALVER]: " choice
    if [ $choice ] ; then DRUPALVER=$choice ; fi
    if [ -z "$DRUPALVER" ] ; then DRUPALVER="8" ; fi

    read -p "Drupal webroot [$DRUPALPATH]: " choice
    if [ $choice ] ; then DRUPALPATH=$choice ; fi

    # guess at php version to use
    PHPVER=$(realpath $(which php) | grep -o "[57].[0-9]")
    read -p "Drupal PHP version [$PHPVER]: " choice
    case $choice in
        5) PHPVER=5.6 ;;
        7) PHPVER=7.0 ;;
        5.6|7.0|7.1) PHPVER=$choice ;;
        "") ;;
        *) PHPVER=$(realpath $(command -v php) | grep -o "[57].[0-9]") ;;
    esac
    if [ -z "$(command -v php${PHPVER})" ] ; then
        echo "Unable to find working php${PHPVER}"
        exit 1
    fi
    return
}

drupal_setting() {
    echo "Drupal version: $DRUPALVER"
    echo "Drupal webroot: $DRUPALPATH"
    echo "Drupal PHP version: $PHPVER"
    return
}

drupal_run() {
    case $DRUPALVER in
        6|7) $(cd "$PROJECTPATH/$DRUPALPATH" ; sudo -u $USER drush cc all -y) ;;
        8|9) $(cd "$PROJECTPATH" ; sudo -u $USER composer install)
            $(cd "$PROJECTPATH/$DRUPALPATH" ; sudo -u $USER drush cr -y) ;;
    esac
    
    # write cache
    echo "DRUPAL=$DRUPAL" >> $CACHEFILE
    echo "DRUPALVER=$DRUPALVER" >> $CACHEFILE
    echo "DRUPALPATH=$DRUPALPATH" >> $CACHEFILE
    return
}

fetch_conf() {
    if [ `echo $FETCHPATH | grep "^\(git://\|https://\S*.git$\)"` ] ; then
        FETCHPROG=git
        return
    fi
    if [ `echo $FETCHPATH | grep "^https://"` ] ; then
        FETCHPROG=wget
        return
    fi
    if [ `echo $FETCHPATH | grep ".tar.gz$"` ] ; then
        FETCHPROG=tar
    fi
    if [ `echo $FETCHPATH | grep "^[dD]\(rupal\)\?8$"` ] ; then
        FETCHPROG=composer
        FETCHPATH="drupal-composer/drupal-project:8.x-dev"
        DRUPAL=Y
    fi
    return
}

fetch_setting() {
    echo "Path to fetch files from: ($FETCHPROG) $FETCHPATH"
    return
}

fetch_run() {
echo "fetch"
    case $FETCHPROG in
        composer)
            $(sudo -u $USER composer create-project $FETCHPATH \
                $PROJECTPATH --stability=dev --no-interaction)
            ;;
        git) echo git clone $FETCHPATH $PROJECTPATH ;;
        wget) 
            echo wget -nc $FETCHPATH -P $ROOTPATH
            FETCHPATH="$ROOTPATH/$(basename $FETCHPATH)"
            ;;
    esac
    if [ `echo $FETCHPATH | grep ".tar.gz$"` ] ;  then
        echo tar xzf $FETCHPATH $PROJECTPATH 
    fi
    echo "FETCHPROG=$FETCHPATH" >> $CACHEFILE
    echo "FETCHPROG=$FETCHPROG" >> $CACHEFILE
    return
}

project_conf() {
    if [ $1 ] ; then PROJECT=$1 ; fi
    
    if [ -z "$ROOTPATH" ]  ; then ROOTPATH="$(pwd)/sites" ; fi
    read -p "Root path [$ROOTPATH]: " choice
    if [ "$choice" ] ; then ROOTPATH=$choice ; fi

    # get absolute path of root directory
    ROOTPATH=$(realpath $ROOTPATH)
    
    # take a guess at the project name if not provided
    if [ -z "$PROJECT" ] ; then PROJECT=$(basename $ROOTPATH) ; fi

    read -p "Project name [$PROJECT]: " choice
    if [ $choice ] ; then
        PROJECT=$choice
    fi
    
    if [ "$PROJECT" = "$(basename $ROOTPATH)" ] ; then
        ROOTPATH=$(dirname $ROOTPATH)
    fi
    PROJECTPATH="$ROOTPATH/$PROJECT"a

    if [ -z "$DOMAIN" ] ; then DOMAIN="dev" ; fi
    read -p "Domain (dev,localhost,example.com) [$DOMAIN]:" choice
    if [ "$choice" ] ; then DOMAIN=$choice ; fi

    return
}

project_setting() {
    echo "Project name: $PROJECT"
    echo "Project root: $PROJECTPATH"
    echo "Project domain: $DOMAIN"
    return
}

project_run() {
    mkdir -p $PROJECTPATH
    # clear cache file
    rm -f $CACHEFILE
    # store cache data
    echo "PROJECT=$PROJECT" >> $CACHEFILE
    echo "PROJECTROOT=$PROJECT" >> $CACHEFILE
    echo "ROOTPATH=$ROOTPATH" >> $CACHEFILE
    echo "DOMAIN=$DOMAIN" >> $CACHEFILE
    return
}

webserv_conf() {
    ADDHOST=$(ps -A | grep dnsmasq > /dev/null && echo "N")
    if [ -z "$ADDHOST" ] ; then ADDHOST="Y" ; fi
    read -p "Add /etc/hosts entry [$ADDHOST]: " choice
    case $choice in
        Y|y) ADDHOST="Y" ;;
        N|n) ADDHOST="N" ;;
    esac
    if [ "$ADDHOST" = "Y" ] ; then
        if [ -z "$DOMAIN" ] ; then DOMAIN="dev" ; fi
        read -p "Domain root (dev,local,example.com) [$DOMAIN]: " choice
        if [ "$choice" ] ; then DOMAIN=$choice ; fi
    fi

    # detect installed webserver
    if [ -z "$WEBSERV" ] ; then
        WEBSERV="$(ps -A | grep -o -m 1 "nginx\|apache2")"
        if [ -z "$WEBSERV" ] ; then
            WEBSERV="$(pkg -l | grep -o -m 1 "nginx\|apache2")"
        fi
    fi
    read -p "Webserver to add vhost to [$WEBSERV]: " choice
    case "$choice" in
        apache|apache2) WEBSERV="apache2" ;;
        ng|nginx) WEBSERV="nginx" ;;
        "") ;;
        *) echo "Invalid server choice: $choice" ; exit 1 ;;
    esac
    return
}

webserv_setting() {
    echo "Add /etc/hosts entry: $ADDHOST"
    if [ "$ADDHOST" = "Y" ] ; then echo "Domain name: $DOMAIN" ; fi
    echo "Webserver to add vhost: $WEBSERV"
}

webserv_run() {
echo "webserv"
    WEBROOT=$PROJECTPATH
    if [ "$DRUPAL" = "Y" ] ; then WEBROOT="$WEBROOT/$DRUPALPATH" ; fi

    # only create vhost if template can be found
    TARG="/etc/$WEBSERV/sites-available/$PROJECT.conf"
    if [ ! -f "$(pwd)/$WEBSERV/template.conf" ] ; then
        echo "Template file not found; skipping"
        return
    fi

    # generate vhost file and install it
    sed -e "s#{DOMAIN}#$PROJECT.$DOMAIN#" \
        -e "s#{WEBROOT}#$WEBROOT#" \
        -e "s#{ACCOUNT}#$PROJECT#g" \
        -e "s#{PHPVER}#$PHPVER#" \
        -e "s#{DRUPALVER}#$DRUPALVER#" \
        "$(pwd)/$WEBSERV/template.conf" > $TARG

    mkdir -p "/var/log/$WEBSERV/$PROJECT"
    ln -s $TARG "/etc/${WEBSERV}/sites-enabled/$PROJECT.conf"
    service $WEBSERV reload

    # write settings to cache
    echo "ADDHOST=$ADDHOST" >> $CACHEFILE
    echo "DOMAIN=$DOMAIN" >> $CACHEFILE
    echo "WEBSERV=$WEBSERV" >> $CACHEFILE
}

confirm_settings() {
    echo
    read -p "Would you like to go ahead with these settings [Y/n]? " choice
    case $choice in
    ""|"y"|"Y") return ;;
    *) exit 0 ;;
    esac
    return
}


# load cached configuration
CACHEPATH="$HOME/.packager"
CACHEFILE="$CACHEPATH/cache"
if [ -f "$CACHEFILE" ] ; then
    . "$CACHEFILE"
else
    mkdir -p "$CACHEPATH" > /dev/null
fi

while getopts "dg:p:s:" opts ; do
    case $opts in
        s) DBPATH=$OPTARG ; shift ;;
        g) FETCHPATH=$OPTARG ; shift ;;
        p) PROJECT=$OPTARG ; shift ;;
        d) DRUPAL=Y ;;
    esac
    shift
done

project_conf $1
db_conf
if [ "$FETCHPATH" ] ; then fetch_conf ; fi
if [ "$DRUPAL" = "Y" ] ; then drupal_conf ; fi
webserv_conf
echo
echo "Settings"
echo "--------"
project_setting
db_setting
if [ "$FETCHPATH" ] ; then fetch_setting ; fi
if [ "$DRUPAL" = "Y" ] ; then drupal_setting ; fi
webserv_setting
echo
confirm_settings
project_run
db_run
fetch_run
if [ "$DRUPAL" = "Y" ] ; then drupal_run ; fi
webserv_run
