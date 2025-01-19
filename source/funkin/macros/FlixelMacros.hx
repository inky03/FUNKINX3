package funkin.macros;

#if macro
import haxe.macro.Expr;
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Expr.Access;
import haxe.macro.Expr.FieldType;

class FlixelMacros {
  public static macro function buildZIndex():Array<Field> {
    var pos:Position = Context.currentPos();
    var cls:ClassType = Context.getLocalClass().get();
    var fields:Array<Field> = Context.getBuildFields();
    
    fields = fields.concat([{
        name: "zIndex",
        access: [Access.APublic],
        kind: FieldType.FVar(macro:Int, macro $v{0}),
        pos: pos
    }]);
    
    return fields;
  }
}
#end
