//libraries
import sys.io.File;
import sys.FileSystem;
import openfl.media.Sound;
import openfl.system.System;
import openfl.display.BlendMode;

import tjson.TJSON;
import flxanimate.FlxAnimate;

import flixel.FlxG;
import flixel.FlxState;
import flixel.FlxBasic;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxCamera;
import flixel.FlxSubState;
import flixel.util.FlxSort;
import flixel.text.FlxText;
import flixel.math.FlxMath;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.sound.FlxSound;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.effects.FlxFlicker;
import flixel.graphics.FlxGraphic;
import flixel.group.FlxSpriteGroup;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;

//funkin
import Util;
import Paths;
import Controls;
import Settings;
import FunkinSprite;
import MusicBeatState;
import MusicBeatSubState;

import lib.DiscordRPC;