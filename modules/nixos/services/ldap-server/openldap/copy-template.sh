#!/bin/bash -e
TEMPLATE_PATH=/customUser.xml

if [ -f $TEMPLATE_PATH ]; then
  mv $TEMPLATE_PATH  /var/www/phpldapadmin/templates/creation/
fi

exit 0
