const TelegramBot = require('node-telegram-bot-api');
const token = process.env.TELE_TOKEN ?? "7748465738:AAH_BJIQ2UvNq7n-V1s-U2XYfiGMMPJKCeM";
const bot = new TelegramBot(token, { polling: true });

export const teleReciver = process.env.TELE_CHAT_RECIVER;

bot.onText(/\/echo (.+)/, (msg, match) => {
  const chatId = msg.chat.id;
  const resp = match[1];
  bot.sendMessage(chatId, resp);
});

bot.on('message', (msg) => {
  const chatId = msg.chat.id;
  console.log(msg);
  bot.sendMessage(chatId, 'Received your message');
});
bot.sendMessage(teleReciver, "Service is Runnning");
module.exports = { bot, teleReciver }