# Character pack

The characters World Studio can place, and where they came from.

| Models | What they are | Licence |
|---|---|---|
| `coworker_cyan`, `coworker_gold`, `coworker_red`, `hunter`, `raider`, `raider2`, `ninja` | **Kenney** *Blocky Characters*, recoloured for The Nightshift and 99 Nights (see `examples/nightshift/build_assets.py`). Blocky, not realistic. 27 animations each | CC0 |
| `wolf`, `bear`, `deer` | Box animals built in Blender for 99 Nights. No animations | CC0 |

The detailed, realistic-looking models in this project are **scenery, not
characters**: the trees, ferns and rocks in
`examples/ninety-nine-nights/models/forest/` are Quaternius's *Stylized
Nature MegaKit* (its licence file sits beside them). There is no Quaternius
**character** pack in this repo.

## Adding another pack

Drop any `.glb` into this folder. That is the whole step:

- World Studio's **Character** part lists whatever is in here, so a new
  model turns up in the *Who* dropdown next time the panel opens.
- The *Doing* dropdown is read from the model itself, so a pack with its
  own animation names (`Idle`, `Run`, `Attack`...) works without changing
  any code.
- In a program, `model3d name = "yourfile.glb"` finds it here without
  copying it next to your `.volt` file.

Good CC0 sources: [Quaternius](https://quaternius.com) (the *Ultimate
Animated Character Pack* is the realistic-ish one) and
[Kenney](https://kenney.nl). Download the **glTF/.glb** version, unzip it,
and copy the model files in. Keep each pack's licence file next to them.

A model that is far bigger than a person is usually in metres rather than
centimetres - set its **Size** to 100 and check it against a Part that is
170 cm tall.
