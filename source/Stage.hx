package;
import flixel.FlxBasic;

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
    //var state = FlxG.state;

    public function new(stage:String) {
        super();
        // loads json file
        // right now only works with vslice stage jsons
        // doesnt create sprites
		jsonPath = 'stages/${stage}.json';
		if (Paths.exists(jsonPath)) {
			var content:String = Paths.text(jsonPath);
			var jsonData:Dynamic = TJSON.parse(content);
			json = jsonData;

            zoom = json.cameraZoom;
            //god theres definitly a better way to write this
            bfPos = FlxPoint.get(json.characters.bf.position[0],json.characters.bf.position[1]);
            gfPos = FlxPoint.get(json.characters.gf.position[0],json.characters.gf.position[1]);
            dadPos = FlxPoint.get(json.characters.dad.position[0],json.characters.dad.position[1]);

            bfOffset = FlxPoint.get(json.characters.bf.cameraOffsets[0],json.characters.bf.cameraOffsets[1]);
            gfOffset = FlxPoint.get(json.characters.gf.cameraOffsets[0],json.characters.gf.cameraOffsets[1]);
            dadOffset = FlxPoint.get(json.characters.dad.cameraOffsets[0],json.characters.dad.cameraOffsets[1]);
		}
        
        // loads hscript file
        scriptPath = 'stages/${stage}.hx';
        if (Paths.exists(scriptPath)){
            HScriptBackend.loadFromPaths(scriptPath);
        }else{
            scriptPath = null;
        }
    }
}