package;

//THIS IS ALL KINDOF A MESS BUT IT WORKS??? I THINK
class Stage extends FlxBasic {
    public var name:String;
    public var json:Dynamic;
    public var jsonPath:String;
    public var scriptPath:String;

    public var zoom:Float = 1;
    public var bfPos:FlxPoint = new FlxPoint(250, 0);
    public var gfPos:FlxPoint = new FlxPoint(0, 0);
    public var dadPos:FlxPoint = new FlxPoint(-250, 0);

    public var bfOffset:FlxPoint = new FlxPoint();
    public var gfOffset:FlxPoint = new FlxPoint();
    public var dadOffset:FlxPoint = new FlxPoint();
    var state = FlxG.state;

    public function new(stageId:String) {
        super();
        // loads json file
        // right now only works with vslice stage jsons
        // doesnt create sprites
		jsonPath = 'stages/${stageId}.json';
		if (Paths.exists(jsonPath)) {
			var content:String = Paths.text(jsonPath);
			var jsonData:Dynamic = TJSON.parse(content);
			json = jsonData;
            var props:Array<Dynamic> = json.props;

            for (propData in props){
                var propSprite:FunkinSprite;
                propSprite = new FunkinSprite();
                propSprite.x = propData.position[0];
                propSprite.y = propData.position[1];
                propSprite.alpha = dataProp.alpha;
                propSprite.loadTexture(propData.assetPath);
                propSprite.updateHitbox();

                state.add(propSprite);
            }

            zoom = json.cameraZoom;
            //god theres definitly a better way to write this
            bfPos.set(json.characters.bf.position[0],json.characters.bf.position[1]);
            gfPos.set(json.characters.gf.position[0],json.characters.gf.position[1]);
            dadPos.set(json.characters.dad.position[0],json.characters.dad.position[1]);

            bfOffset.set(json.characters.bf.cameraOffsets[0],json.characters.bf.cameraOffsets[1]);
            gfOffset.set(json.characters.gf.cameraOffsets[0],json.characters.gf.cameraOffsets[1]);
            dadOffset.set(json.characters.dad.cameraOffsets[0],json.characters.dad.cameraOffsets[1]);
		}
        
        // loads hscript file
        scriptPath = 'stages/${stageId}.hx';
        if (Paths.exists(scriptPath)){
            HScriptBackend.loadFromPaths(scriptPath);
        }else{
            scriptPath = null;
        }
    }
}