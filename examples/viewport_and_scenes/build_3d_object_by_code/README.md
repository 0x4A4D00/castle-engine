# Build 3D Object By Code

Simple example how to build a new 3D object (nodes graph) by ObjectPascal code.
Saves the result using `SaveNode` to `test.x3d` file (open it with
any _Castle Game Engine_ tool, like view3dscene).

Check out https://castle-engine.io/vrml_x3d.php
for a complete list of supported X3D nodes.

Using [Castle Game Engine](https://castle-engine.io/).

## Building

Compile by:

- [CGE editor](https://castle-engine.io/manual_editor.php). Just use menu item _"Compile"_.

- Or use [CGE command-line build tool](https://castle-engine.io/build_tool). Run `castle-engine compile` in this directory.

- Or use [Lazarus](https://www.lazarus-ide.org/). Open in Lazarus `build_3d_object_by_code_standalone.lpi` file and compile / run from Lazarus. Make sure to first register [CGE Lazarus packages](https://castle-engine.io/documentation.php).
