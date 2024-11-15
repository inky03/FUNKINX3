package macros;

#if macro
class ZIndexMacro {
  public static macro function build():Array<haxe.macro.Expr.Field> {
    var pos:haxe.macro.Expr.Position = haxe.macro.Context.currentPos();
    var cls:haxe.macro.Type.ClassType = haxe.macro.Context.getLocalClass().get();
    var fields:Array<haxe.macro.Expr.Field> = haxe.macro.Context.getBuildFields();

    fields = fields.concat([{
        name: "zIndex",
        access: [haxe.macro.Expr.Access.APublic],
        kind: haxe.macro.Expr.FieldType.FVar(macro:Int, macro $v{0}),
        pos: pos
    }]);

    return fields;
  }
}
#end