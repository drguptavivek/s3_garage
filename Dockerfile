FROM dxflrs/garage:v1.0.1 AS garage-source

FROM openresty/openresty:alpine

# Install dependencies
# - bash: for the entrypoint script
# - gettext: for envsubst (config generation)
# - curl: for healthchecks
# - shadow: to create the nginx user (if needed, though adduser is in busybox)
RUN apk add --no-cache bash gettext curl

# Create nginx user/group to match the configuration "user nginx;"
# OpenResty alpine might not have it by default.
RUN addgroup -S nginx || true && adduser -S -G nginx nginx || true

# Copy Garage binary
COPY --from=garage-source /garage /usr/local/bin/garage

# Copy configurations
# OpenResty config path: /usr/local/openresty/nginx/conf/nginx.conf
COPY config/nginx-ratelimit.conf /usr/local/openresty/nginx/conf/nginx.conf
COPY config/garage.toml /etc/garage.toml.template

# Copy and setup entrypoint
COPY scripts/garage-entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create required directories for logs and pid file as defined in nginx-ratelimit.conf
RUN mkdir -p /var/lib/garage/meta \
             /var/lib/garage/data \
             /var/log/nginx \
             /var/run \
             /etc/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && ln -s /usr/local/openresty/nginx/conf/mime.types /etc/nginx/mime.types

# Expose ports
EXPOSE 3900 3901 3903

ENTRYPOINT ["/entrypoint.sh"]
