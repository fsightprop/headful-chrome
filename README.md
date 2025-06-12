# Headful Chrome Remote Puppeteer for n8n

A Docker-based solution that provides a headful (visible) Chrome browser instance with remote debugging capabilities, specifically designed for n8n automation workflows.

## Features

- 🖥️ **Headful Chrome Browser**: Run Chrome with a visible interface (not headless)
- 🔍 **VNC Access**: Connect via VNC to see and interact with the browser
- 🔧 **Remote Debugging**: Full Chrome DevTools Protocol access
- 🔄 **n8n Integration**: Designed specifically for n8n workflows
- 📦 **All-in-One Installation**: Single script setup with systemd service
- 🔒 **Session Persistence**: Keep browser sessions alive between workflows

## Quick Start

### One-Line Installation

```bash
curl -sSL https://raw.githubusercontent.com/fsightprop/headful-chrome-n8n/main/install-headful-chrome-n8n.sh | sudo bash
```

Or manually:

```bash
wget https://raw.githubusercontent.com/fsightprop/headful-chrome-n8n/main/install-headful-chrome-n8n.sh
chmod +x install-headful-chrome-n8n.sh
sudo ./install-headful-chrome-n8n.sh
```

### Manual Docker Setup

```bash
git clone https://github.com/fsightprop/headful-chrome-n8n.git
cd headful-chrome-n8n
docker-compose up -d
```

## Configuration

### Default Ports

- **5900**: VNC Server (connect with any VNC client)
- **9222**: Chrome Remote Debugging Protocol
- **9223**: Nginx Proxy (for stable WebSocket connections)

### Environment Variables

```yaml
NODE_ENV: production
DISPLAY: :99
VNC_PASSWORD: password  # Change this!
```

## Usage

### 1. VNC Access

Connect to the browser using any VNC client:

```
Host: localhost
Port: 5900
Password: password
```

### 2. n8n Integration

In your n8n workflows:

1. **Get Browser Info**:
   ```
   HTTP Request Node
   URL: http://headful-chrome-n8n:9222/json/version
   ```

2. **Extract WebSocket URL** from the response

3. **Use in Puppeteer/Playwright nodes**:
   ```
   Browser WebSocket Endpoint: ws://headful-chrome-n8n:9222/devtools/browser/[BROWSER-ID]
   ```

### 3. Important Notes

- Use `page.close()` instead of `browser.close()` to maintain sessions
- The browser will restart if you close it completely
- Check container logs: `docker logs headful-chrome-n8n`

## Service Management

```bash
# Check status
sudo systemctl status headful-chrome-n8n

# View logs
sudo journalctl -u headful-chrome-n8n -f

# Restart service
sudo systemctl restart headful-chrome-n8n

# Stop service
sudo systemctl stop headful-chrome-n8n
```

## n8n Workflow Examples

### Basic Connection Example

```json
{
  "name": "Puppeteer Remote Connection",
  "nodes": [
    {
      "parameters": {
        "url": "http://headful-chrome-n8n:9222/json/version",
        "options": {}
      },
      "name": "Get Browser Info",
      "type": "n8n-nodes-base.httpRequest",
      "position": [250, 300]
    }
  ]
}
```

## Troubleshooting

### Container won't start
```bash
docker logs headful-chrome-n8n
```

### VNC connection refused
- Check if port 5900 is already in use
- Verify firewall settings

### Chrome crashes
- Increase Docker memory limits
- Check system resources

## Security Notes

⚠️ **Important**: 
- Change the default VNC password
- Use proper network isolation in production
- Consider using SSH tunneling for VNC access

## Contributing

Pull requests are welcome! Please feel free to submit issues and enhancement requests.

## License

MIT License - see LICENSE file for details

## Credits

Based on concepts from:
- [Puppeteer](https://pptr.dev/)
- [n8n](https://n8n.io/)
- Docker and Chrome automation best practices
