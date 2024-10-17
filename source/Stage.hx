package;

using StringTools;

//THIS IS ALL KINDOF A MESS BUT IT WORKS??? I THINK
class Stage {
    public var name:String;
    public var json:Dynamic;
    public var valid:Bool = false;
    public var stageValid:Bool = false;
    public var format:StageFormat = NONE;
    public var props:Map<String, StageProp> = new Map();

    public var zoom:Float = 1;

    public var bfPosition:FlxPoint = FlxPoint.get(250);
    public var gfPosition:FlxPoint = FlxPoint.get();
    public var dadPosition:FlxPoint = FlxPoint.get(-250);

    public var bfOffset:FlxPoint = FlxPoint.get();
    public var gfOffset:FlxPoint = FlxPoint.get();
    public var dadOffset:FlxPoint = FlxPoint.get();

    var state = FlxG.state;

    public function new(?stageId:String) {
        // loads json file
        // right now only works with vslice stage jsons

        if (stageId == null) return;
		var jsonPath:String = 'stages/$stageId.json';
		if (Paths.exists(jsonPath)) {
            Sys.println('loading stage "$stageId"');
            var time:Float = Sys.time();
            try {
    			var content:String = Paths.text(jsonPath);
    			var jsonData:Dynamic = TJSON.parse(content);
                loadModernStageData(jsonData);
                json = jsonData;
                valid = true;
                format = MODERN;
                stageValid = true;
                Sys.println('stage loaded successfully! (${FlxMath.roundDecimal(Sys.time() - time, 3)}s)');
            } catch (e:haxe.Exception) {
                format = NONE;
                Sys.println('error while loading stage "$stageId"... -> ${e.details()}');
            }
		}
        
        // loads hscript file
        var scriptPath:String = 'stages/${stageId}.hx';
        if (Paths.exists(scriptPath)){
            HScriptBackend.loadFromPaths(scriptPath);
            valid = true;
        }
    }
    public function beatHit(beat:Int) {
        for (prop in props) prop.dance(beat);
    }
    public function destroy() {
        for (prop in props) prop.destroy();
    }
    
    public function getProp(name:String) {
        return props[name];
    }
    public function loadModernStageData(data:ModernStageData) {
        var props:Array<ModernStageProp> = data.props;
        var library:Null<String> = data.library;

        for (prop in props) {
            var propSprite:StageProp = new StageProp();
            propSprite.x = prop.position[0];
            propSprite.y = prop.position[1];
            propSprite.alpha = prop.alpha ?? 1;
            propSprite.smooth = !(prop.isPixel ?? false);
            if (prop.animType == 'sparrow' && (prop?.animations?.length ?? 0) > 0) { // this is stupid
                propSprite.loadAtlas(prop.assetPath, library);
                for (animation in prop.animations) {
                    propSprite.addAnimation(animation.name, animation.prefix, animation.frameRate ?? 24, animation.looped ?? false, animation.frameIndices);
                    propSprite.offsets.set(animation.name, FlxPoint.get(animation.offsets[0], animation.offsets[1]));
                }
            } else {
                if (prop.assetPath.startsWith('#'))
                    propSprite.makeGraphic(1, 1, FlxColor.fromString(prop.assetPath));
                else
                    propSprite.loadTexture(prop.assetPath, library);
            }
            if (prop.scroll != null) propSprite.scrollFactor.set(prop.scroll[0], prop.scroll[1]);
            if (prop.scale != null) propSprite.scale.set(prop.scale[0], prop.scale[1]);
            propSprite.updateHitbox();

            state.add(propSprite); // TODO: IMPLEMENT ZINDEX
        }

        zoom = data.cameraZoom;
        
        var yOffset:Float = 0; // ok buddy
        var bf:ModernStageChar = data.characters.bf;
        var gf:ModernStageChar = data.characters.gf;
        var dad:ModernStageChar = data.characters.dad;

        bfPosition.set(bf.position[0], bf.position[1] + yOffset);
        gfPosition.set(gf.position[0], gf.position[1] + yOffset);
        dadPosition.set(dad.position[0], dad.position[1] + yOffset);

        bfOffset.set(bf.cameraOffsets[0], bf.cameraOffsets[1]);
        gfOffset.set(gf.cameraOffsets[0], gf.cameraOffsets[1]);
        dadOffset.set(dad.cameraOffsets[0], dad.cameraOffsets[1]);
    }
}

class StageProp extends FunkinSprite { // maybe unify character with props?
    public var bopFrequency:Int = 0;
    public var startingAnimation:Null<String> = null;

    public function new(x:Float = 0, y:Float = 0) {
        super(x, y);
    }
    public function dance(beat:Int = 0) {
        if (bopFrequency <= 0) return false;
        if (beat % bopFrequency == 0)
            playAnimation(startingAnimation ?? 'idle');
        return true;
    }
    public function addAnimation(name:String, prefix:String, fps:Float = 24, loop:Bool = false, ?frameIndices:Array<Int>) {
        if (frameIndices == null || frameIndices.length == 0) {
            animation.addByPrefix(name, prefix, fps, loop);
        } else {
            animation.addByIndices(name, prefix, frameIndices, '', fps, loop);
        }
    }
}

enum StageFormat {
    MODERN;
    PSYCH;
    NONE;
}

typedef ModernStageData = {
    var characters:ModernStageChars;
    var props:Array<ModernStageProp>;
    var cameraZoom:Float;
    var name:String;
    @:optional var library:String;
    @:optional var version:String;
}
typedef ModernStageChars = { // idk...
    var bf:ModernStageChar;
    var gf:ModernStageChar;
    var dad:ModernStageChar;
}
typedef ModernStageChar = {
    var zIndex:Float;
    var position:Array<Float>;
    var cameraOffsets:Array<Float>;
}
typedef ModernStageProp = {
    var zIndex:Int;
    var name:String;
    var assetPath:String;
    var position:Array<Float>;
    var animations:Array<Character.ModernCharacterAnim>;
    @:optional var alpha:Float;
    @:optional var isPixel:Bool;
    @:optional var danceEvery:Int;
    @:optional var animType:String;
    @:optional var scale:Array<Float>;
    @:optional var scroll:Array<Float>;
    @:optional var startingAnimation:String;
}