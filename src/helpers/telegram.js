const TelegramBot = require('node-telegram-bot-api');
const token = process.env.TELE_TOKEN
const teleReciver = process.env.TELE_CHAT_RECIVER;
if (!token) {
  throw new Error("TELEGRAM_TOKEN is not defined")
}
if (!teleReciver) {
  throw new Error("TELEGRAM_RECIVER is not defined")
}
const bot = new TelegramBot(token, { polling: true });
bot.sendMessage(teleReciver, "Service is Runnning");

module.exports = { bot, teleReciver }
