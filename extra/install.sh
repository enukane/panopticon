#!/bin/sh

BASEDIR=`dirname "${0}"`

if [ "root" != `whoami` ]; then
	echo "panopticon failed to install"
	logger "panopticon failed to install"
	exit 1
fi

cp $BASEDIR/panopticond /etc/init.d/panopticond
chmod +x /etc/init.d/panopticond

update-rc.d panopticond defaults
