// =====================================================================
//  What every Volt built-in is called, what it takes, and what it does.
//
//  One place, used by:
//    - the language service (autocomplete, hover) in Volt Studio and VS Code
//    - the generated part of docs/REFERENCE.md
//
//  Each entry is [signature, what it does, where it works]:
//    signature  the name and its values, exactly as you would type it
//    where      'all'    every target
//                'script' #python #ruby #js #html (not boards)
//                'js'     #js and #html
//                'web'    #html only
//                'game'   #html, and only in a program with a canvas
//                '3d'     #html, and only in a 3D program
//
//  The test suite checks this list covers exactly the built-ins the compiler
//  knows, with the same number of values, so the two can't drift apart.
// =====================================================================

const BUILTIN_DOCS = {
  // ---- numbers ----
  random: ['random(low, high)', 'A whole number from low to high. Both ends can come up.', 'all'],
  abs: ['abs(number)', 'How far a number is from zero, so -7 becomes 7.', 'all'],
  min: ['min(a, b)', 'The smaller of two numbers.', 'all'],
  max: ['max(a, b)', 'The larger of two numbers.', 'all'],
  constrain: ['constrain(value, low, high)', 'Keeps a value between low and high. Same as clamp.', 'all'],
  clamp: ['clamp(value, low, high)', 'Keeps a value between low and high.', 'all'],
  map: ['map(value, fromLow, fromHigh, toLow, toHigh)', 'Rescales a number from one range to another: map(knob, 0, 1023, 0, 100).', 'all'],
  floor: ['floor(number)', 'Rounds down: 2.7 becomes 2.', 'all'],
  ceil: ['ceil(number)', 'Rounds up: 2.1 becomes 3.', 'all'],
  round: ['round(number)', 'Rounds to the nearest whole number; a half rounds up.', 'all'],
  sign: ['sign(number)', '-1 for a negative number, 1 for a positive one, 0 for zero.', 'all'],
  sqrt: ['sqrt(number)', 'The square root, rounded down.', 'all'],
  pow: ['pow(base, exponent)', 'base multiplied by itself exponent times, rounded down.', 'all'],
  sin: ['sin(degrees)', 'The sine of an angle in degrees. Gives a decimal.', 'script'],
  cos: ['cos(degrees)', 'The cosine of an angle in degrees. Gives a decimal.', 'script'],
  chance: ['chance(percent)', 'True about percent times out of a hundred: chance(25).', 'all'],
  now: ['now()', 'The clock, in milliseconds since 1970. For timing and dates.', 'script'],

  // ---- text ----
  text: ['text(value)', 'Turns a number (or anything) into text.', 'all'],
  number: ['number(text)', 'Turns text into a whole number, or 0 if it is not one.', 'all'],
  length: ['length(textOrList)', 'How many letters are in some text, or how many items are in a list.', 'all'],
  upper: ['upper(text)', 'The same text in CAPITALS.', 'all'],
  lower: ['lower(text)', 'The same text in small letters.', 'all'],
  trim: ['trim(text)', 'The same text without spaces at the start and end.', 'all'],
  replace: ['replace(text, find, with)', 'The text with every "find" swapped for "with".', 'all'],
  part: ['part(text, from, count)', 'A piece of the text: part("Hello", 1, 3) is "ell".', 'all'],
  contains: ['contains(textOrList, item)', 'True when the text holds that piece, or the list holds that item.', 'all'],
  startsWith: ['startsWith(text, piece)', 'True when the text begins with that piece.', 'all'],
  endsWith: ['endsWith(text, piece)', 'True when the text ends with that piece.', 'all'],
  indexOf: ['indexOf(textOrList, item)', 'Where it is, counting from 0, or -1 when it is not there.', 'all'],
  repeatText: ['repeatText(text, times)', 'The text over and over: repeatText("ab", 3) is "ababab".', 'all'],
  join: ['join(list, separator)', 'Glues a list into one piece of text with the separator between items.', 'script'],
  split: ['split(text, separator)', 'Cuts text into a list at every separator.', 'script'],

  // ---- lists ----
  first: ['first(list)', 'The first item.', 'script'],
  last: ['last(list)', 'The last item.', 'script'],
  sort: ['sort(list)', 'A new list, smallest first. The original is left alone.', 'script'],
  reverse: ['reverse(list)', 'A new list, back to front.', 'script'],
  slice: ['slice(list, from, count)', 'A new list with count items starting at from (0 is the first).', 'script'],
  sum: ['sum(list)', 'Every number in the list added up.', 'script'],
  pick: ['pick(list)', 'One item, chosen at random.', 'script'],
  shuffle: ['shuffle(list)', 'A new list in a random order.', 'script'],

  // ---- game maths ----
  dist: ['dist(x1, y1, x2, y2)', 'The straight-line distance between two points, rounded down.', 'all'],
  lerp: ['lerp(from, to, percent)', 'A point part way from one number to another: lerp(0, 100, 25) is 25.', 'all'],
  overlaps: ['overlaps(ax, ay, aw, ah, bx, by, bw, bh)', 'True when two rectangles touch. Good for hit detection.', 'all'],

  // ---- files, the network and the outside world ----
  readFile: ['readFile(path)', 'The contents of a file, as text.', 'node'],
  writeFile: ['writeFile(path, text)', 'Saves text to a file. True when it worked.', 'node'],
  envVar: ['envVar(name)', 'An environment variable, or "" when it is not set.', 'node'],
  fetchText: ['fetchText(url)', 'Downloads a web address and gives back its text.', 'js'],
  fetchJson: ['fetchJson(url)', 'Downloads JSON and gives it back ready to use: data.name, data.items[0].', 'js'],

  // ---- keyboard, mouse, gamepad and saving ----
  held: ['held(key)', 'True while a key is held down: held("left"), held("x").', 'game'],
  touchscreen: ['touchscreen()', 'True on a phone or tablet.', 'game'],
  saved: ['saved(name, fallback)', 'Reads back what "save" stored in this browser, or the fallback.', 'game'],
  mousex: ['mousex()', 'Where the pointer is across the screen, in game pixels.', 'game'],
  mousey: ['mousey()', 'Where the pointer is down the screen, in game pixels.', 'game'],
  mousedown: ['mousedown()', 'True while the mouse button (or a finger) is down.', 'game'],
  clicked: ['clicked()', 'True once for each press, so one click does one thing.', 'game'],
  pad: ['pad(button)', 'True while a gamepad button is held: pad("a"), pad("start").', 'game'],
  padx: ['padx()', 'The left stick, left to right, from -100 to 100.', 'game'],
  pady: ['pady()', 'The left stick, up and down, from -100 to 100.', 'game'],
  padx2: ['padx2()', 'The right stick, left to right, from -100 to 100.', 'game'],
  pady2: ['pady2()', 'The right stick, up and down, from -100 to 100.', 'game'],
  crisp: ['crisp(scale)', 'Draws text and shapes at a higher resolution than the game pixels.', 'game'],

  // ---- 3D: making things ----
  block3d: ['block3d(x, y, z, width, height, depth, color)', 'A box, middled on x, y, z. Gives back its number.', '3d'],
  ball3d: ['ball3d(x, y, z, radius, color)', 'A sphere, middled on x, y, z. Gives back its number.', '3d'],
  cyl3d: ['cyl3d(x, y, z, radius, height, color)', 'A cylinder, middled on x, y, z. Gives back its number.', '3d'],
  lamp3d: ['lamp3d(x, y, z, color, power, range)', 'A light that shines in every direction. Gives back its number.', '3d'],
  put3d: ['put3d(model, x, y, z, yaw, scale)', 'Puts a loaded .glb model in the world. Gives back its number.', '3d'],
  sky3d: ['sky3d(level)', 'The time of day, 0 for night and 100 for bright day.', '3d'],

  // ---- 3D: the player and finding things ----
  playerx: ['playerx()', 'Where the player is, left to right.', '3d'],
  playery: ['playery()', "The player's feet, up from the floor.", '3d'],
  playerz: ['playerz()', 'Where the player is, forwards and back.', '3d'],
  playeryaw: ['playeryaw()', 'Which way the player faces, in tenths of a degree.', '3d'],
  playerpitch: ['playerpitch()', 'How far up or down the player looks.', '3d'],
  onground: ['onground()', 'True while the player is standing on something.', '3d'],
  aim3d: ['aim3d(range)', 'The number of whatever the middle of the screen points at, or -1.', '3d'],
  ray3d: ['ray3d(x, y, z, yaw, pitch, range)', 'The number of the first thing in the way, or -1.', '3d'],
  hitdist: ['hitdist()', 'How far away the last aim3d or ray3d hit was.', '3d'],
  hitx: ['hitx()', 'The exact spot the last aim3d or ray3d hit, left to right.', '3d'],
  hity: ['hity()', 'The exact spot the last aim3d or ray3d hit, up and down.', '3d'],
  hitz: ['hitz()', 'The exact spot the last aim3d or ray3d hit, forwards and back.', '3d'],
  touching3d: ['touching3d(a, b)', 'True when two 3D things overlap.', '3d'],
  dist3d: ['dist3d(x1, y1, z1, x2, y2, z2)', 'The straight-line distance between two points in 3D.', 'js'],
  hot3d: ['hot3d(x, y, width, height)', 'Marks a rectangle of the HUD as clickable.', '3d'],
  clicked3d: ['clicked3d()', 'True once when the player clicks the last hot3d rectangle.', '3d'],
  locked3d: ['locked3d()', 'True once the mouse is captured for looking around.', '3d'],
  mousedx: ['mousedx()', 'How far the mouse moved sideways since last asked.', '3d'],
  mousedy: ['mousedy()', 'How far the mouse moved up or down since last asked.', '3d'],

  // ---- 3D maths (tenths of a degree in, thousandths out) ----
  sin3: ['sin3(angle)', 'Sine for 3D maths: the angle is in tenths of a degree, the answer in thousandths.', 'js'],
  cos3: ['cos3(angle)', 'Cosine for 3D maths: the angle is in tenths of a degree, the answer in thousandths.', 'js'],
  atan2: ['atan2(y, x)', 'The angle from one point to another, in tenths of a degree.', 'js'],
};

// Statements, which autocomplete offers as a snippet rather than a call
const STATEMENT_DOCS = {
  'player3d': ['player3d x, y, z speed 420 jump 430 height 170', 'Puts the player in the world. speed, jump and height can be left out.', '3d'],
  'walk3d': ['walk3d', 'Once a frame: moves and looks with the keys, mouse and gamepad, and handles walls, steps and gravity.', '3d'],
  'freeze3d': ['freeze3d', 'Joins every plain block made so far into one shape per colour, so big levels draw fast. They stay solid but can no longer move.', '3d'],
  'solid3d': ['solid3d thing, false', 'Whether the player bumps into something.', '3d'],
  'remove3d': ['remove3d thing', 'Takes something out of the world for good.', '3d'],
  'scale3d': ['scale3d thing, 100, 200, 100', 'Stretches something, as a percent of the size it was made.', '3d'],
  'tilt3d': ['tilt3d thing, pitch, roll', 'Leans something forwards and sideways. turn3d still spins it.', '3d'],
  'color3d': ['color3d thing, "#ff4d6d"', 'Changes the colour of something.', '3d'],
  'attach3d': ['attach3d child, parent', 'Glues one thing to another so it moves with it. Use -1 to let go.', '3d'],
  'far3d': ['far3d 12000', 'How far the camera can see, in cm.', '3d'],
  'ao3d': ['ao3d 60', 'Soft shading in corners and where things meet. 0 turns it off.', '3d'],
  'fx3d': ['fx3d bloom, vignette, grain', 'The cinematic look: glow, darkened edges and film grain, each 0 to 100.', '3d'],
};

module.exports = { BUILTIN_DOCS, STATEMENT_DOCS };
