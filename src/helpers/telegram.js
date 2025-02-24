const TelegramBot = require('node-telegram-bot-api');
const token = process.env.TELE_TOKEN ?? "7748465738:AAH_BJIQ2UvNq7n-V1s-U2XYfiGMMPJKCeM";
const bot = new TelegramBot(token, { polling: true });
const teleReciver = process.env.TELE_CHAT_RECIVER ?? 6228179193;
bot.sendMessage(teleReciver, "Service is Runnning");

module.exports = { bot, teleReciver }