engine by me. yeah!<br>
this engine is HEAVILY UNFINISHED, expect a lot of missing features...

# compiling

> [!NOTE]
> the compile setup process takes around 600 to 700mb (and more if you want to compile to cpp)

this engine runs with the latest libraries!<br>
if you havent, install [haxe](https://haxe.org/download/) first.<br>
if you also havent, [install haxeflixel and all necessary libraries](https://haxeflixel.com/documentation/install-haxeflixel/). you can run the following commands after installing haxe:
```console
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib run lime setup
lime setup flixel
```
perfect! you can now proceed to run these commands in your terminal to install the rest of the required libraries!
```console
haxelib install tjson
haxelib install moonchart
haxelib install hxdiscord_rpc
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate 24c710fe3d907a624c79474ffe27f57ae8113c33
haxelib git hscript-iris https://github.com/crowplexus/hscript-iris.git dev
```
(hscript-iris and flxanimate use indev versions)

you should now be able to run `lime test <targethere>` to compile! tested targets are `hl` and `windows` (cpp)
