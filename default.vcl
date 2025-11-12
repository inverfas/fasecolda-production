vcl 4.1;

# Backend definition - Apache on port 8080
backend default {
    .host = "127.0.0.1";
    .port = "8080";
    .connect_timeout = 3s;
    .first_byte_timeout = 15s;
    .between_bytes_timeout = 5s;
    .max_connections = 100;

    .probe = {
        .url = "/";
        .timeout = 2s;
        .interval = 5s;
        .window = 5;
        .threshold = 3;
    }
}

# Access control list for purge requests
acl purge {
    "localhost";
    "127.0.0.1";
}

sub vcl_recv {
    # Remove has_js cookie
    set req.http.Cookie = regsuball(req.http.Cookie, "has_js=[^;]+(; )?", "");

    # Remove Google Analytics and tracking cookies
    set req.http.Cookie = regsuball(req.http.Cookie, "__utm.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_ga=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_gat=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_gid=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmctr=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmcmd.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "utmccn.=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "_fbp=[^;]+(; )?", "");
    set req.http.Cookie = regsuball(req.http.Cookie, "fr=[^;]+(; )?", "");

    # Remove empty cookies
    if (req.http.Cookie ~ "^\s*$") {
        unset req.http.Cookie;
    }

    # Allow purging from ACL
    if (req.method == "PURGE") {
        if (!client.ip ~ purge) {
            return (synth(405, "Not allowed."));
        }
        return (purge);
    }

    # Only cache GET and HEAD requests
    if (req.method != "GET" && req.method != "HEAD") {
        return (pass);
    }

    # Don't cache WordPress admin or login
    if (req.url ~ "wp-admin" || req.url ~ "wp-login") {
        return (pass);
    }

    # Pass wp-cron.php but don't wait for it (let it run async)
    if (req.url ~ "wp-cron.php") {
        return (pass);
    }

    # Don't cache WooCommerce pages
    if (req.url ~ "^/(cart|my-account|checkout|addons|/?add-to-cart=)") {
        return (pass);
    }

    # Don't cache logged-in users or commenters
    if (req.http.Cookie ~ "wordpress_logged_in_|comment_author") {
        return (pass);
    }

    # Remove all cookies for static files
    if (req.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|mp4|webm|webp)$") {
        unset req.http.Cookie;
        return (hash);
    }

    # Remove cookies for cacheable pages
    if (!(req.url ~ "wp-(admin|login|cron)") && !(req.http.Cookie ~ "wordpress_logged_in_|comment_author")) {
        unset req.http.Cookie;
    }

    return (hash);
}

sub vcl_backend_response {
    # Set ban-lurker friendly custom headers
    set beresp.http.X-Url = bereq.url;
    set beresp.http.X-Host = bereq.http.host;

    # Cache static content for 1 hour
    if (bereq.url ~ "\.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot|mp4|webm|webp)$") {
        unset beresp.http.Set-Cookie;
        set beresp.ttl = 1h;
        set beresp.http.Cache-Control = "public, max-age=3600";
    }

    # Cache HTML pages for 1 hour
    if (beresp.http.Content-Type ~ "text/html") {
        set beresp.ttl = 1h;
        set beresp.http.Cache-Control = "public, max-age=3600";
    }

    # Don't cache if WordPress sets no-cache headers
    if (beresp.http.Cache-Control ~ "private" || beresp.http.Cache-Control ~ "no-cache" || beresp.http.Cache-Control ~ "no-store") {
        set beresp.ttl = 0s;
        set beresp.uncacheable = true;
        return (deliver);
    }

    # Enable grace mode (serve stale content if backend is down or slow)
    set beresp.grace = 24h;

    # Keep object in cache even after TTL expires for grace period
    if (beresp.ttl < 1h) {
        set beresp.ttl = 1h;
    }

    return (deliver);
}

sub vcl_deliver {
    # Add cache status header for debugging
    if (obj.hits > 0) {
        set resp.http.X-Cache = "HIT";
        set resp.http.X-Cache-Hits = obj.hits;
    } else {
        set resp.http.X-Cache = "MISS";
    }

    # Remove backend headers (security)
    unset resp.http.X-Url;
    unset resp.http.X-Host;
    unset resp.http.X-Powered-By;
    unset resp.http.Server;
    unset resp.http.Via;

    return (deliver);
}
