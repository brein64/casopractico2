#!/bin/sh

# Generate username & password pair for authentication
# htpasswd -b -c /usr/local/apache2/.htpasswd ${AUTH_USER} ${AUTH_PASS}

htpasswd -nb ${AUTH_USER} ${AUTH_PASS} > /usr/local/apache2/.htpasswd

# Fix permissions if desired.
if [ -z "$USER_ID" ]
then
  usermod -u $USER_ID -o www-data
  chown -R www-data /var/www
fi

# Run CMD
exec "$@"