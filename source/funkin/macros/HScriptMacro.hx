package funkin.macros;

using Lambda;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;

class HScriptMacro {
	static macro function buildInterp():Array<Field> {
		var pos:Position = Context.currentPos();
		var fields:Array<Field> = Context.getBuildFields();
		
		for (field in fields) {
			if (field.name == 'setVar' && field.access != null) // DE-INLINE METHOD
				field.access.remove(Access.AInline);
		}
		
		return fields;
	}
}
#end

// TODO -> MODULE / PACKAGE / TREE MACRO