FROM wordpress:latest

# Install basic dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl jq ca-certificates openssh-client nano telnet \
 && rm -rf /var/lib/apt/lists/*

# Install WP-CLI for WordPress management
RUN curl -o wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar \
 && mv wp-cli.phar /usr/local/bin/wp

# Copy custom wp-config.php
COPY wp-config.php /var/www/html/wp-config.php

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

# Build args for environment
ARG ENVIRONMENT=development
ARG WP_ENVIRONMENT_TYPE=development

# Set environment variables from build args
ENV ENVIRONMENT=${ENVIRONMENT}
ENV WP_ENVIRONMENT_TYPE=${WP_ENVIRONMENT_TYPE}

EXPOSE 80

# Start Apache in foreground
CMD ["apache2-foreground"]