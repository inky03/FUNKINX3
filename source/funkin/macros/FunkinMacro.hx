package funkin.macros; // well now this package may be a little useless. move to backend or something?

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

class FunkinMacro {
	public static macro function buildFlxBasic():Array<Field> {
		var pos:Position = Context.currentPos();
		var cls:ClassType = Context.getLocalClass().get();
		var fields:Array<Field> = Context.getBuildFields();
		
		fields = fields.concat([{
			name: "zIndex",
			access: [Access.APublic],
			kind: FieldType.FProp('default', 'set', macro:Int, macro $v{0}),
			pos: pos
		}, {
			name: "set_zIndex",
			access: [Access.APublic],
			kind: FieldType.FFun({
				args: [{
					name: 'value',
					type: macro:Int
				}],
				ret: macro:Int,
				expr: macro { return zIndex = value; }
			}),
			pos: pos
		}]);
		
		return fields;
	}
	
	public static macro function buildReset(isOverride:Bool = false):Array<Field> {
		var pos:Position = Context.currentPos();
		var cls:ClassType = Context.getLocalClass().get();
		var fields:Array<Field> = Context.getBuildFields();
		
		var resetExpr:Array<Expr> = [];
		var access = [APublic];
		
		if (isOverride) { // just genius bro
			access.push(AOverride); // theres prob a better way to do this, but cant really figure it out
			resetExpr.push(macro { super.resetVars(); });
		}
		
		for (field in fields) {
			if (field.meta == null) continue;
			
			for (meta in field.meta) {
				if (meta.name != 'resetVar') continue;
				
				switch (field.kind) {
					case FVar(type, expr):
						resetExpr.push(macro { $i{field.name} = $expr; });
						
					default: // nothing ...
				}
			}
		}
		
		fields.push({
			name: 'resetVars',
			access: access,
			pos: pos,
			kind: FFun({
				args: [],
				expr: macro $b{resetExpr}
			}),
		});
		
		return fields;
	}
}
#end
