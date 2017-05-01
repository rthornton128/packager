#!/bin/bash

# TODO: detect which (if any) web server is running/installed (php_inst)

confirm_settings() {
    echo
    CHOICE="Y"
    read -p "Would you like to go ahead with these settings [Y/n]? " CHOICE
    case $CHOICE in
        ""|"y"|"Y") return ;;
        *) exit 0 ;;
    esac
    return
}

# Composer (mainly D8, some D7)

composer_conf() {
    return
}

composer_setting() {
    return
}

composer_inst() {
    return
}

# Database server
db_conf() {
    DB="mariadb"
    read -p "SQL Database [$DB]: " CHOICE
    case $CHOICE in
        ""|"mdb"|"maria"|"mariadb") DB="mariadb" ;;
        "msql"|"mysql") DB="mysql" ;;
        "postgre"|"postgresql") DB="postgresql" ;;
        *)
            echo -n "WARN: Unknown or invalid db choice; "
            echo "Using default: $DB"
            ;;
    esac
    return
}

db_inst() {
    if [ -z "$DB" ] ; then db_conf ; fi
    case $DB in
        "mariadb")
            apt install mariadb-client mariadb-server -y
            ;;
        "mysql")
            apt install mysql-client mysql-server -y
            ;;
        "postgresql")
            # TODO these might be wrong
            apt install postgresql-client-common postgresql-common -y
            ;;
    esac
    return
}

db_setting() { echo "Database server: $DB" ; return ; }

# DNS Masq
dnsmasq_conf() {
    DOMAIN="dev"
    read -p "Local domain name (dev,localhost,example.net) [$DOMAIN]: " CHOICE
    if [ ! -z $CHOICE ] ; then DOMAIN=$CHOICE; fi
     
    ADDRESS="127.0.0.1"
    read -p "Local address [$ADDRESS]: " CHOICE
    if [ ! -z $CHOICE ] ; then ADDRESS=$CHOICE; fi

    return
}

dnsmasq_inst() {
    apt install dnsmasq -y
    grep "$DOMAIN" /etc/dnsmasq.conf
    if [ $? -eq 1 ] ; then
        echo >> /etc/dnsmasq.conf
        echo "# added by packager/dnsmasq script" >> /etc/dnsmasq.conf
        echo "address=/$DOMAIN/$ADDRESS" >> /etc/dnsmasq.conf ;
    fi

    # check if /etc/resolve.conf has the correct settings
    grep "generated" /etc/resolv.conf > /dev/null
    if [ $? -eq 1 ]; then echo "nameserver $ADDRESS" >> /etc/resolve.conf ; fi
     
    return
}

dnsmasq_setting() {
    echo "Local domain: *.$DOMAIN"
    echo "Local IP: $ADDRESS"
    return
}

php_conf() {
    PHPDB=$DB
    PHPMEM="128"
    PHPTIME="240"
    PHPVER=""
    read -p "PHP Version to install [$PHPVER]: " CHOICE
    case $CHOICE in
        "") ;;
        "5"|"5.6") PHPVER="5.6" ;;
        "7"|"7.0") PHPVER="7.0" ;;
        "7.1") PHPVER="7.1" ;;
        *)
            PHPVER=""
            echo -n "WARN Invalid PHP versio \"$CHOICE\"n;"
            echo "installing system default"
            ;;
    esac
    if [ $DB = "mariadb" ] ; then PHPDB="mysql" ; fi

    read -p "PHP max execution timeout [$PHPTIME]: " CHOICE
    # TODO needs validation
    if [ ! -z $CHOICE ] ; then
        $PHPTIME=$CHOICE
    fi

    read -p "PHP memory limit (in megabytes) [$PHPMEM]: " CHOICE
    # TODO needs validation
    if [ ! -z $CHOICE ] ; then
        $PHPMEM=$CHOICE
    fi

    return
}

php_inst() {
    case $PHPVER in
        "5.6"|"7.1")
            add-apt-repository ppa:ondrej/php
            apt-get update
            ;;
    esac
    apt install php${PHPVER} php${PHPVER}-bcmath php${PHPVER}-curl php-date \
        php${PHPVER}-gd php${PHPVER}-json php${PHPVER}-mbstring \
        php${PHPVER}-${PHPDB} php-ssh2 php-xdebug php${PHPVER}-xml \
        php${PHPVER}-zip -y

    INI="/etc/php/${PHPVER}/fpm/php.ini"
    if [ ! -f $INI ] ; then
        echo "WARN: failed to find php.ini, make sure you make these chanages \
        manually"
        echo "max_execution_time==${PHPTIME}"
        echo "memory_limit=${PHPMEM}"
        return
    fi
    sed -i "s/max_execution_time \= [0-9]*$/max_execution_time \= ${PHPTIME}/" $INI
    sed -i "s/memory_limit \= [0-9]+M$/memory_limit \= ${PHPMEM}M/" $INI
    return
}

php_setting() {
    if [ -z "$PHPVER" ] ; then VER="default" ; else VER=$PHPVER ; fi
    echo "PHP version: $VER"
    echo "PHP database module: php${PHPVER}-${PHPDB}"
    echo "PHP max execution time: $PHPTIME"
    echo "PHP memory limit: ${PHPMEM}M"
    return
}

# Sass, Gulp and Nodejs
sass_conf() {
    return
}

sass_setting() {
    return
}

sass_inst() {
    return
}

# Web Server
websrv_conf() {
    WEBSRV="apache2"
    read -p "Web server to configure PHP for [$WEBSRV]:" CHOICE
    case $CHOICE in 
        ""|"ap"|"apache"|"apache2") WEBSRV="apache2" ;;
        "ng"|"ngx"|"nginx") WEBSRV="nginx" ;;
        *)
            echo "WARN: Invalid or unknown web server \"$CHOICE\"!"
            echo "Using default: \"$WEBSRV\""
            ;;
    esac
    return
}

websrv_inst() {
    if [ -z $WEBSRV ] ; then websrv_conf ; fi 
    read -p "Web server to install (apache2 or nginx) [$WEBSRV]:" CHOICE 
    case $CHOICE in "apache2"|"nginx") WEBSRV=$CHOICE;; esac 
 
    apt install $WEBSRV -y
	 
    case $WEBSRV in 
        "apache2") 
            a2enmod rewrite > /dev/null 
            echo "Restarting apache2 service..." 
            service apache2 restart 
            ;; 
        "nginx") 
            ;; 
    esac
    return
}

websrv_setting() { echo "Web server: $WEBSRV" ; return ; }

# main entrypoint
case $1 in
    "apache2"|"nginx"|"websrv")
        echo "Configuring Web server..."
        websrv_conf
        echo
        echo "Settings:"
        websrv_setting
        confirm_settings
        websrv_inst
        ;;
    "composer")
        echo "Configuring composer..."
        composer_conf
        echo
        echo "Settings:"
        composer_setting
        confirm_settings
        composer_inst
        ;;
    "db"|"sql")
        echo "Configuring database..."
        db_conf
        echo
        echo "Settings:"
        db_setting
        confirm_settings
        db_ins
        ;;
    "dnsmasq")
        echo "Configuring PHP..."
        dnsmasq_conf
        echo
        echo "Settings:"
        dnsmasq_setting
        confirm_settings
        dnsmasq_inst
        ;;
    "php")
        echo "Configuring PHP..."
        if [ -z "$DB" ] ; then db_conf ; fi
        php_conf
        echo
        echo "Settings:"
        php_setting
        confirm_settings
        php_inst
        ;;
    "sass"|"gulp")
        echo "Configuring composer..."
        sass_conf
        echo
        echo "Settings:"
        sass_setting
        confirm_settings
        sass_inst
        ;;
    "all")
        websrv_conf
        db_conf
        php_conf
        composer_conf
        sass_conf
        dnsmasq_conf
        echo
        echo "Settings:"
        websrv_setting
        db_setting
        php_setting
        composer_setting
        sass_setting
        dnsmasq_setting
        confirm_settings
        websrv_inst
        db_inst
        php_inst
        composer_inst
        sass_inst
        dnsmasq_inst
        ;;
    *)
	# print usage and exit with error code
        echo "unknown option: \"$1\"; available options are:"
        echo "  db | sql"
        echo "  dnsmasq"
        echo "  php"
        echo "  websrv|apache2|nginx"
        echo "  all"
	exit 1
        ;;
esac
