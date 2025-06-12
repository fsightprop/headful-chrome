#!/bin/bash

# Headful Chrome Remote Puppeteer Installation Script for n8n
# This script installs and configures a headful Chrome instance with VNC access

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration variables
INSTALL_DIR="$(pwd)"
SERVICE_NAME="headful-chrome-n8n"
VNC_PORT=5900
DEBUG_PORT=9223
CHROME_PORT=9222
VNC_PASSWORD="password"  # Change this!

# Function to print colored output
print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_error() {
    echo -e "${RED}[!]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    print_error "Please run as root (use sudo)"
    exit 1
fi

print_status "Starting Headful Chrome Remote Puppeteer installation..."

# Check if we're in the right directory (has required files)
if [ ! -f "Dockerfile" ] && [ ! -f "docker-compose.yml" ]; then
    print_warning "No Docker files found in current directory."
    print_status "This script will create all necessary files in: $(pwd)"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Update system and install dependencies
print_status "Installing system dependencies..."
apt-get update
apt-get install -y \
    curl \
    git \
    docker.io \
    docker-compose \
    x11vnc \
    xvfb \
    fluxbox \
    wget \
    gnupg \
    ca-certificates

# Enable Docker service
systemctl enable docker
systemctl start docker

# Create installation directory
print_status "Using current directory as installation directory..."
# mkdir -p $INSTALL_DIR  # Not needed since we're using current directory
# cd $INSTALL_DIR  # Not needed since we're already there

# Create Dockerfile
print_status "Creating Dockerfile..."
cat > Dockerfile << 'EOF'
FROM node:18-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    wget \
    gnupg \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    xvfb \
    x11vnc \
    fluxbox \
    nginx \
    supervisor \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome
RUN wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add - \
    && echo "deb http://dl.google.com/linux/chrome/deb/ stable main" >> /etc/apt/sources.list.d/google.list \
    && apt-get update \
    && apt-get install -y google-chrome-stable \
    && rm -rf /var/lib/apt/lists/*

# Install Puppeteer
RUN npm install puppeteer

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
EOF

# Create supervisord configuration
print_status "Creating supervisord configuration..."
cat > supervisord.conf << 'EOF'
[supervisord]
nodaemon=true
user=root

[program:xvfb]
command=/usr/bin/Xvfb :99 -screen 0 1920x1080x24
autorestart=true
user=root
priority=100

[program:fluxbox]
command=/usr/bin/fluxbox
autorestart=true
user=root
environment=DISPLAY=":99"
priority=200

[program:x11vnc]
command=/usr/bin/x11vnc -display :99 -nopw -listen 0.0.0.0 -xkb -ncache 10 -forever -shared
autorestart=true
user=root
priority=300

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autorestart=true
user=root
priority=400

[program:chrome]
command=/usr/bin/node /app/index.js
autorestart=true
user=root
environment=DISPLAY=":99"
priority=500
EOF

# Create nginx configuration
print_status "Creating nginx configuration..."
cat > nginx.conf << 'EOF'
server {
    listen 9223;
    server_name localhost;

    location / {
        proxy_pass http://localhost:9222;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Create the main Node.js script
print_status "Creating main Node.js script..."
cat > index.js << 'EOF'
const puppeteer = require('puppeteer');

(async () => {
    console.log('Starting Chrome with remote debugging...');
    
    const browser = await puppeteer.launch({
        headless: false,
        args: [
            '--no-sandbox',
            '--disable-setuid-sandbox',
            '--disable-dev-shm-usage',
            '--disable-gpu',
            '--no-first-run',
            '--no-zygote',
            '--remote-debugging-port=9222',
            '--remote-debugging-address=0.0.0.0',
            '--window-size=1920,1080',
            '--start-maximized'
        ],
        defaultViewport: null,
        executablePath: '/usr/bin/google-chrome-stable'
    });

    const page = await browser.newPage();
    await page.goto('https://www.google.com');
    
    console.log('Chrome started successfully');
    console.log('Remote debugging URL: http://localhost:9222');
    console.log('VNC available on port 5900');
    
    // Keep the script running
    setInterval(() => {
        console.log('Chrome is running...');
    }, 60000);
})();
EOF

# Create start script
print_status "Creating start script..."
cat > start.sh << 'EOF'
#!/bin/bash
export DISPLAY=:99
/usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
EOF

# Create docker-compose.yml
print_status "Creating docker-compose configuration..."
cat > docker-compose.yml << EOF
version: '3.8'

services:
  headful-chrome:
    build: .
    container_name: headful-chrome-n8n
    restart: unless-stopped
    ports:
      - "${VNC_PORT}:5900"     # VNC
      - "${DEBUG_PORT}:9223"   # Nginx proxy for Chrome debugging
      - "${CHROME_PORT}:9222"  # Direct Chrome debugging
    environment:
      - NODE_ENV=production
      - DISPLAY=:99
    volumes:
      - ./data:/data
    networks:
      - n8n-network

networks:
  n8n-network:
    external: true
    name: n8n-network
EOF

# Create systemd service file
print_status "Creating systemd service..."
cat > /etc/systemd/system/${SERVICE_NAME}.service << EOF
[Unit]
Description=Headful Chrome Remote Puppeteer for n8n
After=docker.service
Requires=docker.service

[Service]
Type=simple
Restart=always
RestartSec=10
WorkingDirectory=${INSTALL_DIR}
ExecStartPre=/usr/bin/docker-compose down
ExecStart=/usr/bin/docker-compose up
ExecStop=/usr/bin/docker-compose down
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Create the n8n network if it doesn't exist
print_status "Creating Docker network..."
docker network create n8n-network 2>/dev/null || true

# Build the Docker image
print_status "Building Docker image..."
docker-compose build

# Create data directory
mkdir -p data

# Enable and start the service
print_status "Enabling and starting service..."
systemctl daemon-reload
systemctl enable ${SERVICE_NAME}
systemctl start ${SERVICE_NAME}

# Create n8n workflow examples
print_status "Creating n8n workflow examples..."
mkdir -p n8n-workflows

cat > n8n-workflows/puppeteer-connection-example.json << 'EOF'
{
  "name": "Puppeteer Remote Connection Example",
  "nodes": [
    {
      "parameters": {
        "url": "http://headful-chrome-n8n:9222/json/version",
        "options": {}
      },
      "name": "Get Browser Info",
      "type": "n8n-nodes-base.httpRequest",
      "position": [250, 300]
    },
    {
      "parameters": {
        "functionCode": "const browserInfo = items[0].json;\nconst wsEndpoint = browserInfo.webSocketDebuggerUrl;\n\n// Use this wsEndpoint in your Puppeteer node\nreturn [{\n  json: {\n    wsEndpoint,\n    browserInfo,\n    connectionExample: `puppeteer.connect({ browserWSEndpoint: '${wsEndpoint}' })`\n  }\n}];"
      },
      "name": "Extract WebSocket URL",
      "type": "n8n-nodes-base.function",
      "position": [450, 300]
    }
  ],
  "connections": {
    "Get Browser Info": {
      "main": [
        [
          {
            "node": "Extract WebSocket URL",
            "type": "main",
            "index": 0
          }
        ]
      ]
    }
  }
}
EOF

# Create usage instructions
print_status "Creating usage instructions..."
cat > README.md << EOF
# Headful Chrome Remote Puppeteer for n8n

## Installation Complete! 🎉

### Service Information:
- **Service Name**: ${SERVICE_NAME}
- **VNC Port**: ${VNC_PORT} (password: ${VNC_PASSWORD})
- **Chrome Debug Port**: ${CHROME_PORT}
- **Nginx Proxy Port**: ${DEBUG_PORT}

### Service Management:
\`\`\`bash
# Check service status
sudo systemctl status ${SERVICE_NAME}

# View logs
sudo journalctl -u ${SERVICE_NAME} -f

# Restart service
sudo systemctl restart ${SERVICE_NAME}

# Stop service
sudo systemctl stop ${SERVICE_NAME}
\`\`\`

### VNC Access:
1. Install a VNC client (RealVNC, TightVNC, etc.)
2. Connect to: \`localhost:${VNC_PORT}\`
3. Password: \`${VNC_PASSWORD}\`

### n8n Integration:
1. Use HTTP Request node to get browser info:
   - URL: \`http://headful-chrome-n8n:9222/json/version\`
   
2. Extract the \`webSocketDebuggerUrl\` from response

3. Use in Puppeteer nodes:
   - Browser WebSocket Endpoint: \`ws://headful-chrome-n8n:9222/...\`

### Important Notes:
- Use \`page.close()\` instead of \`browser.close()\` to maintain sessions
- The browser will restart if you close it completely
- Check example workflows in \`n8n-workflows/\` directory

### Troubleshooting:
- If container fails to start, check: \`docker logs headful-chrome-n8n\`
- For VNC issues, ensure port ${VNC_PORT} is not in use
- For connection issues, verify n8n-network exists: \`docker network ls\`
EOF

# Display completion message
print_status "Installation complete!"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Headful Chrome Remote Puppeteer Installed${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Service Status:"
systemctl status ${SERVICE_NAME} --no-pager | head -n 5
echo ""
echo "Quick Start:"
echo "1. Connect VNC client to localhost:${VNC_PORT}"
echo "2. Check browser at http://localhost:${DEBUG_PORT}"
echo "3. View logs: sudo journalctl -u ${SERVICE_NAME} -f"
echo ""
echo "n8n WebSocket endpoint will be:"
echo "ws://headful-chrome-n8n:9222/devtools/browser/[BROWSER-ID]"
echo ""
print_warning "Remember to change the VNC password in production!"
