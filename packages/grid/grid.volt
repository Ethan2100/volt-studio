// grid - a flat list used as a 2D grid, for tile maps, board games and levels.
//
//   volt add ./packages/grid
//   import "grid"
//
// A grid is one list plus its width. Positions are x across and y down, both starting at 0.
//
//   let map = gridNew(8, 6, 0)
//   gridSet(map, 8, 2, 3, 1)
//   print gridGet(map, 8, 2, 3)

// A new grid, every square set to 'fill'.
fn gridNew(width, height, fill) {
  let cells = []
  repeat width * height {
    add fill to cells
  }
  return cells
}

// Where x, y sits in the flat list, or -1 when it is off the grid.
fn gridAt(cells, width, x, y) {
  if x < 0 or y < 0 or x >= width {
    return 0 - 1
  }
  let i = y * width + x
  if i >= length(cells) {
    return 0 - 1
  }
  return i
}

// What is at x, y. Squares off the grid read as 'outside' so edges need no special case.
fn gridGetOr(cells, width, x, y, outside) {
  let i = gridAt(cells, width, x, y)
  if i < 0 {
    return outside
  }
  return cells[i]
}

fn gridGet(cells, width, x, y) {
  return gridGetOr(cells, width, x, y, 0)
}

// Puts a value at x, y. Off the grid, nothing happens.
fn gridSet(cells, width, x, y, value) {
  let i = gridAt(cells, width, x, y)
  if i >= 0 {
    cells[i] = value
  }
  return 0
}

// How tall a grid is, from its length and width.
fn gridHeight(cells, width) {
  if width <= 0 {
    return 0
  }
  return length(cells) / width
}

// True when x, y is on the grid at all.
fn gridInside(cells, width, x, y) {
  return gridAt(cells, width, x, y) >= 0
}

// The four squares next to x, y, as a list. Squares off the grid read as 'outside'.
fn gridAround(cells, width, x, y, outside) {
  let out = []
  add gridGetOr(cells, width, x, y - 1, outside) to out
  add gridGetOr(cells, width, x + 1, y, outside) to out
  add gridGetOr(cells, width, x, y + 1, outside) to out
  add gridGetOr(cells, width, x - 1, y, outside) to out
  return out
}

// How many squares hold this value.
fn gridCount(cells, width, value) {
  let found = 0
  for each cell in cells {
    if cell == value {
      found += 1
    }
  }
  return found
}

// Turns a row of text into grid values, one per letter: "##..#" with wall "#" gives 1 for a wall.
fn gridRow(cells, width, y, text, wall) {
  for each piece, x in split(text, "") {
    if piece == wall {
      gridSet(cells, width, x, y, 1)
    }
  }
  return 0
}
