<?php
// Trust Load Balancer HTTPS headers (must be at the top to prevent redirect loops)
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}
if (isset($_SERVER['HTTP_X_FORWARDED_HOST'])) {
    $_SERVER['HTTP_HOST'] = $_SERVER['HTTP_X_FORWARDED_HOST'];
}

// Environment type configuration
if (!defined('WP_ENVIRONMENT_TYPE')) {
    define('WP_ENVIRONMENT_TYPE', getenv('WP_ENVIRONMENT_TYPE') ?: 'development');
}

// Log environment type for debugging
error_log('WP_ENVIRONMENT_TYPE is set to: ' . WP_ENVIRONMENT_TYPE);

// Environment-specific debug settings (set early to prevent redefinition)
$environment_type = WP_ENVIRONMENT_TYPE;
switch ($environment_type) {
    case 'local':
        if (!defined('WP_DEBUG')) {
            define('WP_DEBUG', true);
        }
        if (!defined('WP_DEBUG_LOG')) {
            define('WP_DEBUG_LOG', true);
        }
        if (!defined('WP_DEBUG_DISPLAY')) {
            define('WP_DEBUG_DISPLAY', false);
        }
        if (!defined('FORCE_SSL_ADMIN')) {
            define('FORCE_SSL_ADMIN', filter_var(getenv('FORCE_SSL_ADMIN'), FILTER_VALIDATE_BOOLEAN));
        }
        break;

    case 'production':
    default:
        if (!defined('WP_DEBUG')) {
            define('WP_DEBUG', false);
        }
        if (!defined('WP_DEBUG_LOG')) {
            define('WP_DEBUG_LOG', false);
        }
        if (!defined('WP_DEBUG_DISPLAY')) {
            define('WP_DEBUG_DISPLAY', false);
        }
        if (!defined('FORCE_SSL_ADMIN')) {
            define('FORCE_SSL_ADMIN', filter_var(getenv('FORCE_SSL_ADMIN'), FILTER_VALIDATE_BOOLEAN));
        }
        break;
}

// Database configuration
$db_name = getenv('WORDPRESS_DB_NAME');
$db_user = getenv('WORDPRESS_DB_USER');
$db_password = getenv('WORDPRESS_DB_PASSWORD');
$db_host = getenv('WORDPRESS_DB_HOST') . ':3306';

define('DB_NAME',     $db_name);
define('DB_USER',     $db_user);
define('DB_PASSWORD', $db_password);
define('DB_HOST',     $db_host);

// MySQL SSL Configuration
$db_ssl = filter_var(getenv('DB_SSL'), FILTER_VALIDATE_BOOLEAN);
error_log('DB_SSL setting: ' . ($db_ssl ? 'true' : 'false'));

if ($db_ssl) {
    define('MYSQL_CLIENT_FLAGS', MYSQLI_CLIENT_SSL);
    define('DB_SSL', true);
    error_log('SSL enabled for database connection');
} else {
    define('DB_SSL', false);
    error_log('SSL disabled for database connection');
}
define('DB_CHARSET',  'utf8mb4');
define('DB_COLLATE',  '');

// WordPress security keys
define('AUTH_KEY',         getenv('AUTH_KEY'));
define('SECURE_AUTH_KEY',  getenv('SECURE_AUTH_KEY'));
define('LOGGED_IN_KEY',    getenv('LOGGED_IN_KEY'));
define('NONCE_KEY',        getenv('NONCE_KEY'));
define('AUTH_SALT',        getenv('AUTH_SALT'));
define('SECURE_AUTH_SALT', getenv('SECURE_AUTH_SALT'));
define('LOGGED_IN_SALT',   getenv('LOGGED_IN_SALT'));
define('NONCE_SALT',       getenv('NONCE_SALT'));

// File system method
define('FS_METHOD', 'direct');

// WordPress URLs (from environment variables)
define('WP_HOME', getenv('WP_HOME') ?: 'http://localhost');
define('WP_SITEURL', getenv('WP_SITEURL') ?: 'http://localhost');

// Additional WordPress configurations
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '256M');

// Enable WordPress cache
define('WP_CACHE', true);

// Disable per-request wp-cron; run it via system cron instead
if (!defined('DISABLE_WP_CRON')) {
    define('DISABLE_WP_CRON', true);
}

// Disable file editing from WordPress admin
define('DISALLOW_FILE_EDIT', true);

// Set uploads directory
define('UPLOADS', 'wp-content/uploads');

// Database table prefix
$table_prefix = 'UOXRc7pR_';

// WordPress absolute path
if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}


// Load WordPress
require_once ABSPATH . 'wp-settings.php';
