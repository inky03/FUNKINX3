class FreeplayState extends MusicBeatState {
	public var target:FlxObject;
	public var items:FlxTypedGroup<SongItem>;
	public var inputEnabled:Bool = true;
	public static var selection:Int = 0;
	
	override public function create() {
		super.create();
		
		var bg:FunkinSprite = new FunkinSprite().loadTexture('menuBGBlue');
		bg.setGraphicSize(bg.width * 1.1);
		bg.scrollFactor.set();
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		
		items = new FlxTypedGroup<SongItem>();
		add(items);
		
		var dirList:Array<Array<String>> = [[Paths.sharedPath('levels'), '']];
		dirList.push([Paths.modPath('levels'), '']);
		for (mod in Mods.get()) {
			dirList.push([Paths.modPath('levels', mod.directory), mod.directory]);
		}
		for (dir in dirList) {
			if (FileSystem.exists(dir[0])) {
				Sys.println('loading weeks from ${dir[0]}');
				for (file in FileSystem.readDirectory(dir[0])) {
					loadLevel('${dir[0]}/$file', dir[1]);
				}
			}
		}
		
		FlxG.camera.target = target = new FlxObject();
		FlxG.camera.followLerp = 9 / 60;
		select();
		FlxG.camera.snapToTarget();
		
		Main.showWatermark = true;
		
		DiscordRPC.presence.details = 'Navigating freeplay!';
		DiscordRPC.dirty = true;
	}
	
	override public function update(elapsed:Float) {
		super.update(elapsed);
		DiscordRPC.update();
		if (!inputEnabled) return;
		
		if (FlxG.keys.justPressed.UP) select(-1);
		if (FlxG.keys.justPressed.DOWN) select(1);
		if (FlxG.keys.justPressed.ENTER) {
			FlxG.sound.play(Paths.sound('confirmMenu'), .8);
			Main.showWatermark = false;
			inputEnabled = false;
			
			new FlxTimer().start(1, (timer:FlxTimer) -> {
				var selectedItem:SongItem = items.members[selection];
				Mods.currentMod = selectedItem.mod;
				PlayState.song = Song.loadAutoDetect(selectedItem.songPath, 'hard');
				FlxG.switchState(() -> new PlayState());
			});
		}
		if (FlxG.keys.justPressed.ESCAPE) {
			FlxG.switchState(() -> new MainMenuState());
		}
	}
	
	public function select(mod:Int = 0) {
		if (items.length == 0) return;
		if (mod != 0) FlxG.sound.play(Paths.sound('scrollMenu'), .8);
		
		items.members[selection].highlight(false);
		
		selection = FlxMath.wrap(selection + mod, 0, items.length - 1);
		var selectedItem:SongItem = items.members[selection];
		selectedItem.highlight();
		
		target.setPosition(selectedItem.x + 400, selectedItem.y + selectedItem.height * .5);
	}
	
	public function loadLevel(path:String, mod:String = '') {
		try {
			var content:String = File.getContent(path);
			var levels:LevelsData = TJSON.parse(content);
			for (song in levels.freeplay) {
				var i:Int = items.length - 1;
				var item:SongItem = new SongItem(i * 40, i * 100, song.displayName, song.icon);
				item.difficulties = song.difficulties;
				item.songPath = song.songPath;
				item.mod = mod;
				items.add(item);
			}
			Sys.println('level added! (${levels.freeplay.length} songs)');
		} catch (e:haxe.Exception) {
			Sys.println('error loading level -> ${e.details()}');
		}
	}
}

class SongItem extends FlxSpriteGroup {
	public var mod:String;
	public var text:Alphabet;
	public var icon:HealthIcon;
	public var songPath:String;
	public var difficulties:Array<String> = [];
	public function new(x:Float = 0, y:Float = 0, name:String = 'unknown', icon:String = 'face') {
		super(x, y);
		this.icon = new HealthIcon(0, 0, icon);
		text = new Alphabet(150, 0, name);
		
		text.y = (this.icon.height - text.height) * .5;
		add(this.icon);
		add(text);
		
		highlight(false);
		updateHitbox();
	}
	public function highlight(on:Bool = true) {
		if (on) {
			icon.alpha = 1;
			text.alpha = 1;
			text.color = 0xffcc66;
		} else {
			icon.alpha = .65;
			text.alpha = .65;
			text.color = 0xffffff;
		}
	}
}

typedef LevelsData = {
	var freeplay:Array<FreeplayLevel>;
	var story_mode:Array<StoryLevel>;
}
typedef FreeplayLevel = {
	var difficulties:Array<String>;
	var displayName:String;
	var songPath:String;
	@:optional var icon:String;
}
typedef StoryLevel = {
	var displayName:String;
	var songPath:String;
}