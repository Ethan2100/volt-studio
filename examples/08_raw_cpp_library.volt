// Mix in raw C++ to use any Arduino library (here: an I2C LCD screen).
#c++
// Needs the "LiquidCrystal I2C" library (Arduino IDE -> Library Manager).
//   # code          -> raw C++ right here
//   ## code         -> raw C++ at the top of the file
//   #include <x.h>  -> goes at the top of the file
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
## LiquidCrystal_I2C lcd(0x27, 16, 2);

let seconds = 0

# lcd.init();
# lcd.backlight();
# lcd.print("Volt + LCD!");

every 1s {
  seconds = seconds + 1
  # lcd.setCursor(0, 1);
  # lcd.print(seconds);
}
