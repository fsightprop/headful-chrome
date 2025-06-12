FROM ghcr.io/puppeteer/puppeteer:21.0.0

USER root

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    fluxbox \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/sites-enabled/default
COPY index.js /app/index.js
COPY start.sh /app/start.sh

RUN chmod +x /app/start.sh

# Expose ports
EXPOSE 5900 9222 9223

CMD ["/app/start.sh"]
