FROM wordpress:latest

# Install basic dependencies
RUN apt-get update \
 && apt-get install -y --no-install-recommends unzip curl jq ca-certificates openssh-client \
 && rm -rf /var/lib/apt/lists/*

# Install WP-CLI for WordPress management
RUN curl -o wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
 && chmod +x wp-cli.phar \
 && mv wp-cli.phar /usr/local/bin/wp

# Clean entire html directory to ensure fresh state on every build
RUN rm -rf /var/www/html/* /var/www/html/.*  2>/dev/null || true

COPY src/ /var/www/html/

# Set proper ownership and permissions for WordPress directories
RUN chown -R www-data:www-data /var/www/html \
 && find /var/www/html -type d -exec chmod 755 {} \; \
 && find /var/www/html -type f -exec chmod 644 {} \; \
 && chmod 666 /var/www/html/wp-config.php 2>/dev/null || true

# Create directory for artifacts plugins
RUN mkdir -p /usr/local/share/artifacts-plugins

# Copy downloaded plugins from Azure Artifacts (directory created by pipeline)
COPY artifacts-plugins /usr/local/share/artifacts-plugins

# Copy entrypoint scripts
COPY scripts/entrypoint.sh /usr/local/bin/custom-entrypoint.sh
RUN chmod +x /usr/local/bin/custom-entrypoint.sh

# Ensure proper permissions for WordPress critical directories
RUN mkdir -p /var/www/html/wp-content/uploads \
 && mkdir -p /var/www/html/wp-content/plugins \
 && mkdir -p /var/www/html/wp-content/themes \
 && chown -R www-data:www-data /var/www/html/wp-content \
 && chmod -R 755 /var/www/html/wp-content \
 && chmod -R 775 /var/www/html/wp-content/uploads

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