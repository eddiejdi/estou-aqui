class Logger {
  static _instance = null;

  static instance() {
    if (!Logger._instance) {
      Logger._instance = new Logger();
    }
    return Logger._instance;
  }

  info(msg) {
    console.log(`[INFO] ${msg}`);
  }

  error(msg) {
    console.error(`[ERROR] ${msg}`);
  }

  warn(msg) {
    console.warn(`[WARN] ${msg}`);
  }

  debug(msg) {
    console.log(`[DEBUG] ${msg}`);
  }
}

module.exports = Logger;
