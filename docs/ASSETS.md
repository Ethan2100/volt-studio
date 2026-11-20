# Project asset workflow

Open a Volt project, then choose **Assets** in the right-hand workspace. Use **Import files…** to copy one or more files into the project's `Assets/` folder. Existing names are kept; collisions receive a numeric suffix so an import never silently replaces an asset.

The Asset Browser can search and filter project assets. It previews PNG/JPEG images and supported audio files. Select an asset and choose **Insert Volt declaration** to add a matching top-level declaration at the current editor cursor. Declarations compile in `#html` games:

| Asset | Volt declaration | Supported file types |
| --- | --- | --- |
| 3D model | `model3d model_name = "Assets/model.glb"` | `.glb` |
| Image | `image image_name = "Assets/image.png"` | `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg` |
| Audio | `audio sound_name = "Assets/sound.wav"` | `.wav`, `.mp3`, `.ogg`, `.m4a` |

Volt embeds model, image, and audio assets into a compiled game page. Model textures need to be packed into the GLB. Image and audio previews are limited to 20 MB per file; imports are limited to 100 MB per file and 250 MB per batch.

## Formats not imported yet

OBJ, FBX, and text `.gltf` scenes are not loaded by Volt's game compiler. The Asset Browser identifies these files if they are already in a project and explains the conversion route. Convert them to a self-contained `.glb` with textures packed inside before using `model3d`. Do not rename an unsupported file to `.glb`; that does not convert its contents.

Animation clips embedded in a GLB can be selected by name with `anim3d`. A separate animation-file importer and editor are not available yet. The Asset Browser does not currently preview 3D models; it reports when a GLB is ready to reference from Volt code.
