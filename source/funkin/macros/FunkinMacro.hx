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
			kind: FieldType.FProp('default', 'set', TPath({name: 'Int', pack: []}), macro $v{0}),
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
}
#end
