const { Client, LocalAuth } = require('whatsapp-web.js');
const qrcode = require('qrcode-terminal');
const { bot, teleReciver }= require('./telegram');

let client;

function createClient() {
  client = new Client({
    puppeteer: {
      headless: true,
      args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
    },
    webVersionCache: {
      type: 'remote',
      puppeteer: {
        headless: true,
        args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
      },
      remotePath:
        'https://raw.githubusercontent.com/wppconnect-team/wa-version/main/html/2.2412.54.html',
    },
  });

  client.on('qr', (qr) => {
    qrcode.generate(qr, { small: true });
    console.log(teleReciver);
    bot.sendMessage(teleReciver, "Please SCAN QR_CODE");
  });

  client.on('message', (msg) => {
    if (msg.body == '!ping') {
      msg.reply('pong');
    }
  });

  client.on('loading_screen', (percent, message) => {
    console.log('LOADING SCREEN', percent, message);
  });

  client.on('authenticated', () => {
    console.log('AUTHENTICATED');
  });

  client.on('auth_failure', (msg) => {
    console.error('AUTHENTICATION FAILURE', msg);
  });

  client.on('ready', async () => {
    console.log('READY');
    bot.sendMessage(teleReciver, "Device is ready!");
    client.pupPage.on('error', function (err) {
      console.log('Page error: ' + err.toString());
    });
  });

  client.on('disconnected', (reason) => {
    console.log('Client was logged out', reason);
    restartClient();
  });

  client.initialize();
}

function restartClient() {
  console.log('Restarting client in 5 seconds...');
  client = null
  setTimeout(() => {
    createClient();
  }, 5000);
}

createClient();

module.exports = client;
