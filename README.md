engine by me. yeah!

# compiling

> [!NOTE]
> the compile setup process takes around 600 to 700mb

this engine runs in the latest libraries!<br>
if you havent, install [haxe](https://haxe.org/download/) first.<br>
if you also havent, [install flixel and all necessary libraries](https://haxeflixel.com/documentation/install-haxeflixel/). you can run the following commands:
```console
haxelib install lime
haxelib install openfl
haxelib install flixel
haxelib run lime setup
lime setup flixel
```
perfect! now you can now proceed to run these silly little commands in your command line to install required libraries!
```console
haxelib install tjson
haxelib install moonchart
haxelib install hxdiscord_rpc
haxelib git flxanimate https://github.com/Dot-Stuff/flxanimate.git dev
haxelib git hscript-iris https://github.com/crowplexus/hscript-iris.git dev
```
(hscript-iris and flxanimate use the in-development versions)

you should now be able to run `lime test <targethere>` to compile! tested targets are `hl` and `windows`(cpp) 
