#!/bin/bash

# set this to your database user
USER=acro

# enable for testing/debugging
set -x

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
	echo "Usage: add-db.sh DB [SQL_FILE]"
	exit 1
fi

mysql -ve "CREATE DATABASE $1;"
mysql -ve "GRANT ALL PRIVILEGES ON $1.* TO '$USER'@'localhost';"
if [ ! -z "$2" ]; then
	case "$2" in
	*.gz | *.tgz)
		zcat $2 | mysql --user=$USER -p $1
	;;
	*)
		mysql --user=$USER -p $1 < $2
	;;
	esac
fi
