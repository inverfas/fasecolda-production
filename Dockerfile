FROM wordpress:latest

# Install basic dependencies and Varnish
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl jq ca-certificates openssh-client nano telnet varnish \
 && rm -rf /var/lib/apt/lists/*

# Install WP-CLI for WordPress management
RUN curl -o wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar \
 && mv wp-cli.phar /usr/local/bin/wp

# Copy custom PHP configuration
COPY custom-php.ini /usr/local/etc/php/conf.d/custom-php.ini

# Copy custom wp-config.php
COPY wp-config.php /var/www/html/wp-config.php

# Copy Varnish configuration
COPY default.vcl /etc/varnish/default.vcl

# Ensure proper permissions for WordPress critical directories
RUN mkdir -p /var/www/html/wp-content/uploads \
 && mkdir -p /var/www/html/wp-content/plugins \
 && mkdir -p /var/www/html/wp-content/themes \
 && chown -R www-data:www-data /var/www/html/wp-content \
 && chown www-data:www-data /var/www/html/wp-config.php \
 && chmod -R 755 /var/www/html/wp-content \
 && chmod -R 775 /var/www/html/wp-content/uploads \
 && chmod 644 /var/www/html/wp-config.php

# Configure PHP sessions and temp directory
RUN mkdir -p /var/lib/php/sessions /tmp \
 && chown -R www-data:www-data /var/lib/php/sessions /tmp \
 && chmod 1777 /tmp \
 && chmod 755 /var/lib/php/sessions

# Configure Apache to listen on port 8080
RUN sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf \
 && sed -i 's/:80/:8080/' /etc/apache2/sites-available/000-default.conf

# Build args for environment
ARG ENVIRONMENT=development
ARG WP_ENVIRONMENT_TYPE=development

# Set environment variables from build args
ENV ENVIRONMENT=${ENVIRONMENT}
ENV WP_ENVIRONMENT_TYPE=${WP_ENVIRONMENT_TYPE}

# Copy startup script
COPY start-varnish.sh /usr/local/bin/start-varnish.sh
RUN chmod +x /usr/local/bin/start-varnish.sh

EXPOSE 80

# Start Varnish and Apache
CMD ["/usr/local/bin/start-varnish.sh"]