using Lambda;

class FreeplayState extends MusicBeatState {
	public var target:FlxObject;
	public var diffText:FlxText;
	public var items:Array<SongItem> = [];
	public var variationList:Array<Variation> = [];
	public var displayItems:FlxTypedGroup<SongItem>;
	public var inputEnabled:Bool = true;
	public static var selection:Int = 0;
	public static var selectedDifficulty:Int = 0;
	public static var currentVariation:String = 'default';
	
	override public function create() {
		super.create();
		
		playMusic(MainMenuState.menuMusic);
		var bg:FunkinSprite = new FunkinSprite().loadTexture('menuBGBlue');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		diffText = new FlxText(15, 15, FlxG.width - 30);
		diffText.setFormat(Paths.ttf('vcr'), 18, FlxColor.WHITE, RIGHT, OUTLINE, FlxColor.BLACK);
		diffText.scrollFactor.set();
		add(diffText);

		displayItems = new FlxTypedGroup<SongItem>();
		add(displayItems);
		
		var paths:Array<Paths.PathsFile> = Paths.getPaths('data/levels/');
		for (path in paths) {
			var folder:String = Paths.typePath('data/levels', path.type, path.mod);
			if (FileSystem.exists(folder)) {
				Log.minor('loading freeplay levels @ "$folder"');
				for (level in FileSystem.readDirectory(folder))
					loadLevel('$folder/$level', path.mod);
			}
		}
		
		FlxG.camera.target = target = new FlxObject();
		FlxG.camera.followLerp = 9 / 60;

		if (currentVariation == null) currentVariation = variationList[0].internalName;
		displayVariation(findVariation(currentVariation));
		selectDifficulty();
		select();
		FlxG.camera.snapToTarget();
		
		Main.showWatermark = true;
		
		DiscordRPC.presence.details = 'Navigating freeplay!';
		DiscordRPC.dirty = true;
	}
	
	override public function update(elapsed:Float) {
		elapsed = getRealElapsed();
		
		super.update(elapsed);
		DiscordRPC.update();
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.LEFT) selectDifficulty(-1);
		if (FlxG.keys.justPressed.RIGHT) selectDifficulty(1);
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ENTER) {
			FlxG.sound.playMusic(Paths.music('titleShoot'), 1, false);
			FlxG.sound.play(Paths.sound('confirmMenu'), .8);
			Main.showWatermark = false;
			inputEnabled = false;
			
			new FlxTimer().start(2, (timer:FlxTimer) -> {
				var selectedItem:SongItem = displayItems.members[selection];
				var variation:Variation = findVariation(currentVariation);
				Mods.currentMod = selectedItem.mod;
				PlayState.song = Song.loadAutoDetect(selectedItem.songPath, variation.difficulties[selectedDifficulty], variation.suffix);
				FlxG.switchState(() -> new PlayState());
			});
		}
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new MainMenuState());
		}
	}
	
	// TODO: this doesn't work like how i wanted it to...
	public function selectDifficulty(mod:Int = 0) {
		var variation:Variation = findVariation(currentVariation);
		var difficulties:Array<String> = variation.difficulties;
		var nextVariation:Variation = variation;
		
		selectedDifficulty += mod;
		
		var pos:Int = variationList.indexOf(variation);
		if (selectedDifficulty < 0) {
			pos = FlxMath.wrap(pos - 1, 0, variationList.length - 1);
			nextVariation = variationList[pos];
			selectedDifficulty = nextVariation.difficulties.length - 1;
		} else if (selectedDifficulty >= difficulties.length) {
			pos = FlxMath.wrap(pos + 1, 0, variationList.length - 1);
			nextVariation = variationList[pos];
			selectedDifficulty = 0;
		}

		if (variation != nextVariation) {
			currentVariation = nextVariation.internalName;
			difficulties = nextVariation.difficulties;
			displayVariation(nextVariation);
			select();
		}

		diffText.text = 'VARIATION: ${nextVariation.name}\n${difficulties[selectedDifficulty].toUpperCase()}';
	}
	public function select(mod:Int = 0) {
		if (items.length == 0) return;
		if (mod != 0) FlxG.sound.play(Paths.sound('scrollMenu'), .8);
		
		displayItems.members[selection]?.highlight(false);
		
		selection = FlxMath.wrap(selection + mod, 0, displayItems.members.length - 1);
		var selectedItem:SongItem = displayItems.members[selection];
		if (selectedItem == null) return;
		selectedItem.highlight();
		
		target.setPosition(selectedItem.x + 400, selectedItem.y + selectedItem.height * .5);
	}
	public function displayVariation(variation:Variation) {
		displayItems.clear();
		var i = 0;
		for (item in items) {
			if (item.variations.contains(variation)) {
				item.setPosition(i * 25, i * 100);
				displayItems.add(item);
				item.highlight(false);
				i ++;
			}
		}
	}
	public function findVariation(name:String):Variation
		return variationList.find((v:Variation) -> v.internalName == name);
	
	public function loadLevel(path:String, ?mod:String) {
		try {
			var content:String = File.getContent(path);
			var levels:LevelsData = TJSON.parse(content);
			for (song in levels.songList) {
				if (song.showOnFreeplay != null && !song.showOnFreeplay) continue;
				var i:Int = items.length - 1;
				var item:SongItem = new SongItem(0, 0, song.displayName, song.icon);
				item.songPath = song.songPath;
				item.mod = mod ?? '';
				items.push(item);
				for (variationName in (song.variations ?? levels.variations)) {
					loadVariation(variationName, mod);
					var variation:Variation = findVariation(variationName);
					if (variation != null)
						item.variations.push(variation);
				}

				var songPath:String = 'data/songs/${song.songPath}';
				var modSongPath:String = Paths.modPath(songPath, mod);
				if (!FileSystem.exists(modSongPath) && (mod != '' || !Paths.exists(songPath)))
					item.itsBad();
			}
			Log.info('level @ "$path" added! (${levels.songList.length} songs)');
		} catch (e:haxe.Exception) {
			Log.error('error loading level @ "$path" -> ${e.details()}');
		}
	}
	public function loadVariation(name:String, ?mod:String) {
		try {
			for (variation in variationList) {
				if (variation.internalName == name)
					return;
			}

			var variationPath:String = Paths.modPath('data/variations/$name.json', mod);
			if (!FileSystem.exists(variationPath))
				variationPath = Paths.sharedPath('data/variations/$name.json');
			if (!FileSystem.exists(variationPath)) {
				Log.warning('variation "$name" not found...');
				Log.minor('verify:');
				Log.minor('- data/variations/$name.json');
				return;
			}
			var content:String = File.getContent(variationPath);
			var variation:Variation = new Variation(name, TJSON.parse(content));
			variation.path = variationPath;
			variation.mod = mod;
			variationList.push(variation);
			Log.info('variation "$name" added!');
		} catch (e:haxe.Exception) {
			Log.error('error loading variation "$name" -> ${e.details()}');
		}
	}
}

class SongItem extends FlxSpriteGroup {
	var bad:Bool;
	public var mod:String;

	public var text:Alphabet;
	public var icon:HealthIcon;
	public var songPath:String;
	public var variations:Array<Variation> = [];

	public function new(x:Float = 0, y:Float = 0, name:String = 'unknown', icon:String = 'face') {
		super(x, y);
		this.icon = new HealthIcon(0, 0, icon);
		text = new Alphabet(150, 0, name);
		
		this.icon.y = (text.height - this.icon.height) * .5;
		add(this.icon);
		add(text);
		
		highlight(false);
		updateHitbox();
	}
	public function highlight(on:Bool = true) {
		if (on) {
			icon.alpha = 1;
			text.alpha = 1;
			text.color = (bad ? 0xff8080 : 0xffcc66);
		} else {
			icon.alpha = .65;
			text.alpha = .65;
			text.color = (bad ? 0xff8080 : 0xffffff);
		}
	}
	public function itsBad() {
		bad = true;
		icon.color = 0xff8080;
		highlight(text.alpha == 1);
	}
	public function hasVariation(name:String)
		return variations.exists((v:Variation) -> v.internalName == name);
}

// TODO: move this to its own class!
typedef LevelsData = {
	var songList:Array<LevelSong>;
	var variations:Array<String>;
}
typedef LevelSong = {
	var ?variations:Array<String>;
	var ?showOnStorymode:Bool;
	var ?showOnFreeplay:Bool;
	var displayName:String;
	var songPath:String;
	var ?icon:String;
}
typedef VariationData = {
	var difficulties:Array<String>;
	var suffix:String;
	var name:String;
}
class Variation {
	public var mod:String;
	public var path:String;
	public var internalName:String;

	public var name:String;
	public var suffix:String;
	public var difficulties:Array<String>;

	public function new(name:String, data:VariationData) {
		internalName = name;
		this.name = data.name;
		this.suffix = data.suffix;
		this.difficulties = data.difficulties;
	}
}