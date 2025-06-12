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
