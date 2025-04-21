package funkin.backend.scripting;

import crowplexus.hscript.Expr;
import crowplexus.hscript.Parser;

class ModParser extends Parser {
	override function parseFunctionArgs() {
		var args:Array<Argument> = [];
		var tk = token();
		
		if (tk != TPClose) {
			var done = false;
			while (!done) {
				var name:String = null, opt:Bool = false;
				
				switch (tk) {
					case TQuestion:
						opt = true;
						tk = token();
					default:
				}
				switch (tk) {
					case TId(id):
						name = id;
					default:
						unexpected(tk);
						break;
				}
				
				var arg:Argument = {name: name, opt: opt};
				
				if (allowTypes) {
					if (maybe(TDoubleDot))
						arg.t = parseType();
					if (maybe(TOp("="))) {
						arg.value = parseExpr();
						arg.opt = true;
					}
				}
				
				tk = token();
				switch (tk) {
					case TComma:
						tk = token();
					case TPClose:
						done = true;
					default:
						unexpected(tk);
						break;
				}
				
				args.push(arg);
			}
		}
		
		return args;
	}
}