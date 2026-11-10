// A tiny stand-in for the Arduino core, so the test suite can compile and RUN the C++ that
// Volt generates on an ordinary computer (g++). Serial prints go to the screen; pins are an
// array you can read back. Only what Volt's output uses is here.
#pragma once
#include <cmath>
#include <cstdio>
#include <cstdlib>
#include <string>

typedef unsigned char byte;
#define HIGH 1
#define LOW 0
#define INPUT 0
#define OUTPUT 1
#define INPUT_PULLUP 2
#define A0 14
#define A1 15
#define A2 16
#define A3 17
#define A4 18
#define A5 19
#define LED_BUILTIN 13

static long __pinValue[64];
static unsigned long __clock = 0;      // fake milliseconds: delay() moves it forward
static int __loopsLeft = 3;            // how many times loop() runs before the test ends

inline void pinMode(int, int) {}
inline void digitalWrite(int p, int v) { __pinValue[p] = v; printf("[pin %d = %d]\n", p, v); }
inline int digitalRead(int p) { return (int)__pinValue[p]; }
inline int analogRead(int p) { return (int)__pinValue[p]; }
inline void analogWrite(int p, int v) { __pinValue[p] = v; printf("[pwm %d = %d]\n", p, v); }
inline unsigned long millis() { return __clock; }
inline unsigned long micros() { return __clock * 1000UL; }
inline void delay(unsigned long ms) { __clock += ms; }
inline void delayMicroseconds(unsigned long us) { __clock += us / 1000UL; }
inline void tone(int, unsigned int, unsigned long = 0) {}
inline void noTone(int) {}
inline void randomSeed(unsigned long s) { srand((unsigned)s); }
inline long random(long lo, long hi) { return hi <= lo ? lo : lo + rand() % (hi - lo); }
inline long random(long hi) { return random(0, hi); }
inline long map(long x, long a, long b, long c, long d) { return (x - a) * (d - c) / (b - a) + c; }

class String {
 public:
  std::string s;
  String() {}
  String(const char *c) : s(c) {}
  String(const std::string &c) : s(c) {}
  String(char c) : s(1, c) {}
  String(int v) : s(std::to_string(v)) {}
  String(long v) : s(std::to_string(v)) {}
  String(unsigned long v) : s(std::to_string(v)) {}
  String(bool v) : s(v ? "1" : "0") {}
  unsigned int length() const { return (unsigned int)s.size(); }
  long toInt() const { return atol(s.c_str()); }
  void toUpperCase() { for (auto &c : s) c = (char)toupper(c); }
  void toLowerCase() { for (auto &c : s) c = (char)tolower(c); }
  void trim() {
    size_t a = s.find_first_not_of(" \t\r\n"), b = s.find_last_not_of(" \t\r\n");
    s = a == std::string::npos ? "" : s.substr(a, b - a + 1);
  }
  void replace(const String &f, const String &t) {
    if (f.s.empty()) return;
    for (size_t p = 0; (p = s.find(f.s, p)) != std::string::npos; p += t.s.size()) s.replace(p, f.s.size(), t.s);
  }
  int indexOf(const String &o) const { size_t p = s.find(o.s); return p == std::string::npos ? -1 : (int)p; }
  bool startsWith(const String &o) const { return s.rfind(o.s, 0) == 0; }
  bool endsWith(const String &o) const { return s.size() >= o.s.size() && s.compare(s.size() - o.s.size(), o.s.size(), o.s) == 0; }
  String substring(unsigned int a, unsigned int b) const { return a >= s.size() ? String("") : String(s.substr(a, b - a)); }
  String operator+(const String &o) const { return String(s + o.s); }
  String &operator+=(const String &o) { s += o.s; return *this; }
  bool operator==(const String &o) const { return s == o.s; }
  bool operator!=(const String &o) const { return s != o.s; }
  bool operator<(const String &o) const { return s < o.s; }
  bool operator>(const String &o) const { return s > o.s; }
  bool operator<=(const String &o) const { return s <= o.s; }
  bool operator>=(const String &o) const { return s >= o.s; }
};

struct SerialStub {
  void begin(long) {}
  void println(const String &v) { printf("%s\n", v.s.c_str()); }
  void println(const char *v) { printf("%s\n", v); }
  void println(long v) { printf("%ld\n", v); }
  void println(int v) { printf("%d\n", v); }
  void println(unsigned long v) { printf("%lu\n", v); }
  void println(bool v) { printf("%d\n", v ? 1 : 0); }
  void println() { printf("\n"); }
  void print(const String &v) { printf("%s", v.s.c_str()); }
  void print(long v) { printf("%ld", v); }
  operator bool() const { return true; }
};
static SerialStub Serial;

struct Servo {
  int pin = -1;
  void attach(int p) { pin = p; }
  void write(int a) { printf("[servo %d = %d]\n", pin, a); }
};

void setup();
void loop();
int main() {
  setup();
  for (int i = 0; i < __loopsLeft; i++) loop();
  return 0;
}
