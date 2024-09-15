//funkin
import Util;
import Paths;
import Controls;
import Settings;
import FunkinSprite;
import MusicBeatState;

//libraries
import openfl.media.Sound;
import openfl.system.System;
#if !flash
	import sys.io.File;
	import sys.FileSystem;
#end

import tjson.TJSON;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;