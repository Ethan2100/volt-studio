// =====================================================================
//  Sends a file to a MicroPython board over USB, using MicroPython's
//  "raw REPL" mode (the same method Thonny and mpremote use):
//
//    Ctrl-C        stop the running program
//    Ctrl-A        enter raw REPL ("raw REPL; CTRL-B to exit\r\n>")
//    <code> Ctrl-D run code; board replies "OK", output, \x04, errors, \x04, ">"
//    Ctrl-B        leave raw REPL
//    Ctrl-D        soft reset, which runs main.py
// =====================================================================

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

class MicroPythonUploader {
  constructor(SerialPort, portPath, log = () => {}) {
    this.SerialPort = SerialPort;
    this.portPath = portPath;
    this.log = log;
    this.buffer = '';
    this.port = null;
  }

  open() {
    return new Promise((resolve, reject) => {
      this.port = new this.SerialPort({ path: this.portPath, baudRate: 115200, autoOpen: false });
      this.port.on('data', (d) => { this.buffer += d.toString('utf8'); });
      this.port.open((err) => (err ? reject(new Error(`Couldn't open ${this.portPath}: ${err.message}`)) : resolve()));
    });
  }

  close() {
    return new Promise((resolve) => {
      if (this.port && this.port.isOpen) this.port.close(() => resolve());
      else resolve();
    });
  }

  write(text) {
    return new Promise((resolve, reject) => {
      this.port.write(Buffer.from(text, 'utf8'), (err) => {
        if (err) return reject(err);
        this.port.drain(() => resolve());
      });
    });
  }

  // Wait until the board has sent `marker`; returns everything before it
  async waitFor(marker, timeout = 4000) {
    const start = Date.now();
    while (!this.buffer.includes(marker)) {
      if (Date.now() - start > timeout) {
        throw new Error(`The board didn't answer (waited for ${JSON.stringify(marker)}). Got: ${JSON.stringify(this.buffer.slice(-120))}`);
      }
      await sleep(10);
    }
    const i = this.buffer.indexOf(marker);
    const before = this.buffer.slice(0, i);
    this.buffer = this.buffer.slice(i + marker.length);
    return before;
  }

  async enterRawRepl() {
    // Stop whatever is running (a while True loop, for example)
    await this.write('\r\x03');
    await sleep(100);
    await this.write('\x03');
    await sleep(200);
    this.buffer = '';
    await this.write('\r\x01');
    try {
      await this.waitFor('raw REPL; CTRL-B to exit\r\n>');
    } catch {
      // Some boards are slow to stop the program; try once more
      await this.write('\x03\x03');
      await sleep(400);
      this.buffer = '';
      await this.write('\r\x01');
      await this.waitFor('raw REPL; CTRL-B to exit\r\n>', 5000);
    }
  }

  // Run one piece of Python on the board and return what it printed
  async exec(code) {
    // Small chunks with short pauses, so the board's input buffer doesn't overflow
    for (let i = 0; i < code.length; i += 256) {
      await this.write(code.slice(i, i + 256));
      await sleep(10);
    }
    await this.write('\x04');
    await this.waitFor('OK');
    const output = await this.waitFor('\x04', 10000);
    const error = await this.waitFor('\x04', 10000);
    await this.waitFor('>');
    if (error.trim()) throw new Error(`Board error: ${error.trim()}`);
    return output;
  }

  async upload(fileName, content) {
    await this.open();
    try {
      this.log('Connecting to MicroPython…\n');
      await this.enterRawRepl();
      this.log(`Writing ${fileName} (${content.length} characters)…\n`);
      await this.exec(`f=open(${JSON.stringify(fileName)},'w')`);
      // JSON strings are also valid Python strings
      for (let i = 0; i < content.length; i += 400) {
        await this.exec(`f.write(${JSON.stringify(content.slice(i, i + 400))})`);
      }
      await this.exec('f.close()');
      const check = await this.exec(`import os;print(os.stat(${JSON.stringify(fileName)})[6])`);
      this.log(`Saved ${fileName} on the board (${check.trim()} bytes).\n`);
      // Leave raw REPL and soft-reset so main.py starts
      await this.write('\x02');
      await sleep(100);
      await this.write('\x04');
      await sleep(300);
    } finally {
      await this.close();
    }
  }
}

module.exports = { MicroPythonUploader };
