// Spawns a stack of colored, bouncy parts above the spawn point, one every
// half second, forever - a quick way to see real Roblox Luau come out of
// plain Volt. Paste the compiled .luau into a Script in Roblox Studio
// (Workspace or ServerScriptService both work).
//
// The counting/looping/math is ordinary Volt; the Roblox-specific calls -
// Instance.new, Vector3.new, game:GetService(...), BrickColor - are real
// Luau dropped in with '#'/'##' raw-code lines, the same escape hatch the
// #c++ target uses for direct Arduino/register calls Volt has no word for.
#luau

## local Workspace = game:GetService("Workspace")

let colors = ["Bright red", "Bright blue", "New Yeller", "Lime green", "Bright violet"]
let spawned = 0

fn spawnPart(colorName, height) {
  # local p = Instance.new("Part")
  # p.Size = Vector3.new(2, 2, 2)
  # p.Position = Vector3.new(0, height, 0)
  # p.BrickColor = BrickColor.new(colorName)
  # p.Material = Enum.Material.Neon
  # p.Shape = Enum.PartType.Ball
  # p.Parent = Workspace
  print "spawned a part at height " + height
}

forever {
  let colorName = colors[spawned % length(colors)]
  spawnPart(colorName, 5 + spawned * 3)
  spawned = spawned + 1
  wait 500ms
}
