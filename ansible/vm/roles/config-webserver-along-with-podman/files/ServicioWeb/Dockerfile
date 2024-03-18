FROM docker.io/httpd:2.4.58-alpine3.19

COPY append /usr/local/apache2/htdocs/

ENV AUTH_USER bpineros
ENV AUTH_PASS 123

RUN apk add apache2


# Enable vhosts.
RUN sed -i -e 's%#Include conf/extra/httpd-vhosts.conf%Include conf/extra/httpd-vhosts.conf%g' /usr/local/apache2/conf/httpd.conf
# Add our custom vhost.
COPY vhost.conf /usr/local/apache2/conf/extra/httpd-vhosts.conf
COPY cert-selfsigned.crt /etc/ssl/certs/cert-selfsigned.crt
COPY cert-selfsigned.key /etc/ssl/private/cert-selfsigned.key

RUN sed -i \
		-e 's/^#\(LoadModule .*mod_ssl.so\)/\1/' \
		-e 's/^#\(LoadModule .*mod_socache_shmcb.so\)/\1/' \
		conf/httpd.conf


# Create server root and set it as workdir.
WORKDIR /var/www

# Add entrypoint to create .htpasswd file.
COPY docker-entrypoint.sh /
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]

EXPOSE 80

CMD ["httpd-foreground"]