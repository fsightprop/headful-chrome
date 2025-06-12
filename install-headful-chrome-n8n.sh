#!/bin/bash

# Simple installation script for Headful Chrome on n8n
# Created by fsight.prop

echo "[*] Starting Headful Chrome Remote Puppeteer installation..."

# Install system dependencies
echo "[*] Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y curl git docker.io docker-compose x11vnc xvfb fluxbox wget gnupg ca-certificates
sudo systemctl enable --now docker

# Use the current directory as the installation directory
INSTALL_DIR=$(pwd)
echo "[*] Using current directory as installation directory..."

# Create Dockerfile
echo "[*] Creating Dockerfile..."
cat > Dockerfile <<EOL
FROM ghcr.io/puppeteer/puppeteer:21.0.0

# Add Google Chrome's official GPG key
RUN wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor -o /usr/share/keyrings/google-chrome-keyring.gpg

# Update sources to use the new key and install dependencies
RUN echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && apt-get install -y \
    xvfb \
    x11vnc \
    fluxbox \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Copy configuration files
COPY supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY nginx.conf /etc/nginx/sites-available/default
COPY main.js /usr/src/app/main.js
COPY start.sh /usr/src/app/start.sh
RUN chmod +x /usr/src/app/start.sh

# Expose ports and define entrypoint
EXPOSE 80 5900
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]
EOL

# Create supervisord configuration
echo "[*] Creating supervisord configuration..."
cat > supervisord.conf <<EOL
[supervisord]
nodaemon=true
user=root

[program:xvfb]
command=Xvfb :1 -screen 0 1280x800x24
autorestart=true

[program:fluxbox]
command=fluxbox -display :1
autorestart=true

[program:x11vnc]
command=x11vnc -display :1 -forever -nopw
autorestart=true

[program:nginx]
command=/usr/sbin/nginx -g 'daemon off;'
autorestart=true

[program:node]
command=node /usr/src/app/main.js
autorestart=true
environment=DISPLAY=":1"
EOL

# Create nginx configuration
echo "[*] Creating nginx configuration..."
cat > nginx.conf <<EOL
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOL

# Create main Node.js script
echo "[*] Creating main Node.js script..."
cat > main.js <<EOL
const express = require('express');
const { exec } = require('child_process');

const app = express();
const port = 3000;

app.get('/screenshot', (req, res) => {
    const url = req.query.url;
    if (!url) {
        return res.status(400).send('URL is required');
    }

    exec(\`node -e 'require("puppeteer").launch({headless: false, args: ["--no-sandbox"]}).then(async browser => {const page = await browser.newPage(); await page.goto("${url}"); await page.screenshot({path: "/tmp/screenshot.png"}); await browser.close()})'\`, (error, stdout, stderr) => {
        if (error) {
            console.error(\`exec error: \${error}\`);
            return res.status(500).send(stderr);
        }
        res.sendFile('/tmp/screenshot.png');
    });
});

app.listen(port, () => {
    console.log(\`Server listening at http://localhost:\${port}\`);
});
EOL

# Create start script
echo "[*] Creating start script..."
cat > start.sh <<EOL
#!/bin/bash
service supervisor start
tail -f /var/log/supervisor/supervisord.log
EOL

# Create docker-compose configuration
echo "[*] Creating docker-compose configuration..."
cat > docker-compose.yml <<EOL
services:
  headful-chrome:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8080:80"
      - "5900:5900"
    networks:
      - headful-net
    restart: always

networks:
  headful-net:
EOL

# Create systemd service
echo "[*] Creating systemd service..."
cat > headful-chrome.service <<EOL
[Unit]
Description=Headful Chrome Service
Requires=docker.service
After=docker.service

[Service]
Restart=always
WorkingDirectory=$INSTALL_DIR
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down

[Install]
WantedBy=multi-user.target
EOL

# Make script executable
chmod +x start.sh

echo "[*] Setup script finished."