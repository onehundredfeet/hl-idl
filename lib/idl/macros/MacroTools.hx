package idl.macros;

import haxe.macro.Compiler;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;

// borrowed from tink_macro
// The MIT License (MIT)
// Copyright (c) 2013 Juraj Kirchheim
// Permission is hereby granted, free of charge, to any person obtaining a copy of
// this software and associated documentation files (the "Software"), to deal in
// the Software without restriction, including without limitation the rights to
// use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
// the Software, and to permit persons to whom the Software is furnished to do so,
// subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
// FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
// COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
// IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
class MacroTools {
	static public function asTypePath(s:String, ?params):TypePath {
		var parts = s.split('.');
		var name = parts.pop(), sub = null;
		if (parts.length > 0 && parts[parts.length - 1].charCodeAt(0) < 0x5B) {
			sub = name;
			name = parts.pop();
			if (sub == name)
				sub = null;
		}
		return {
			name: name,
			pack: parts,
			params: params == null ? [] : params,
			sub: sub
		};
	}

	static public inline function asComplexType(s:String, ?params)
		return TPath(asTypePath(s, params));

	static public inline function sanitize(pos:Position)
		return if (pos == null) Context.currentPos(); else pos;

	static public inline function asConstExpr(s:String, ?p:Position):Expr {
		return {expr: EConst(CString(s)), pos: p}
	}

	static public inline function asIdentExpr(s:String, ?p:Position):Expr {
		return {expr: EConst(CIdent(s)), pos: p}
	}

	static public inline function asFieldAccess(s:String, ?p:Position):Expr {
		var parts = s.split(".");
		if (parts.length == 0) {
			throw "Invalid field access";
		}
		var e = EConst(CIdent(parts.shift()));
		for (part in parts) {
			e = EField({expr: e, pos: p}, part);
		}
		return {expr: e, pos: p};
	}

	static public inline function at(e:ExprDef, ?pos:Position)
		return {
			expr: e,
			pos: sanitize(pos)
		};

	static var idlParse = ~/\$\{([\w]+)_IDL_DIR\}\/([\w]+)\.idl/i;
	public macro static function buildHXCPPIDLType(idlRelPath:String, ?includeFlag : Bool) :Array<Field> {
		var ct = Context.getLocalClass().get();

		var current_file = Context.getPosInfos(Context.currentPos()).file;
		var dir = haxe.io.Path.directory(current_file);
		var module = Context.getLocalModule().split('.').pop();
		var className = ct.name;
		var ma:MetaAccess = ct.meta;
		var md:Metadata = ma.get();

		var IDL_NAME_UPPER = module.toUpperCase();
		var xmlFileName = '${module}.xml';

		if (idlParse.match(idlRelPath)) { 
			IDL_NAME_UPPER = idlParse.matched(1).toUpperCase();
			var idlFileName = idlParse.matched(2);		
			xmlFileName = '${idlFileName}.xml';	
//			trace('IDL_NAME_UPPER: ${IDL_NAME_UPPER} idlFileName: ${idlFileName} xmlFileName: ${xmlFileName}');
		}

		var buildMeta = {name: ":buildXml", params: [asConstExpr('<include name=\"${dir}/${xmlFileName}\"/>', Context.currentPos())], pos: ct.pos};
		var include = {name: ":include", params: [asConstExpr('hxcpp/${module}_hxcpp_idl.h', Context.currentPos())], pos: Context.currentPos()};

		var moduleDefine = '${module.toUpperCase()}_IDL_DIR';

		

		ma.add(buildMeta.name, buildMeta.params, buildMeta.pos);
		if (includeFlag == null || includeFlag)
			ma.add(include.name, include.params, include.pos);		
		//ma.add({name: ":native", params: [asConstExpr("SampleA"), asConstExpr("SampleA")], pos: Context.currentPos()});
		var check = ma.get();

		for (m in check) {
			//trace('Checking ${m}');
		}
//		trace('\n\n\n');
		return null;
	}
#if macro
	public static function hxcppInit(idlRelPath:String) {
		var file = null;
		var pos = Context.currentPos();
		var idlAbsPath : String = try {
			Context.resolvePath(idlRelPath);
		} catch( e : Dynamic ) {
			Context.error("" + e,Context.makePosition({min:0, max:0, file: "MacroTools"}) );
			null;
		}

		var idlAbsDir = haxe.io.Path.directory(idlAbsPath);
		var moduleName = idlRelPath.split('/').pop().split('.').shift();
		var moduleDefine = '${moduleName.toUpperCase()}_IDL_DIR';

		var libDirDef = '${moduleName.toUpperCase()}_LIB_DIR';
		if (!Context.defined(libDirDef)) {
			if (Context.defined("IDL_DEBUG")) 
				Compiler.define(libDirDef, idlAbsDir + "/../../lib/debug");
			else
				Compiler.define(libDirDef, idlAbsDir + "/../../lib/release");
			trace('${libDirDef}= ${Context.definedValue(libDirDef)}');
		}
		if (!Context.defined(moduleDefine)) {
//			trace('Defining ${moduleDefine} as ${idlAbsDir}');
			Compiler.define(moduleDefine, idlAbsDir);
		}
	}
	#end

	public static function asMacroPos(pos:idl.Data.Position):haxe.macro.Expr.Position {
		if (pos == null)
			return Context.makePosition({file: "null", min: 0, max: 0 });
		return Context.makePosition({min: pos.pos, max: pos.pos + 1, file: pos.file});
	}

	public static function asPublicFunctionField(expr : Expr, name:String, args:Array<FunctionArg>, ret:ComplexType, pos:haxe.macro.Expr.Position):Field {
		return {
			name: name,
			kind: FFun({args:args, ret:ret, expr:expr}),
			pos: pos,
			access: [APublic]
		};
	}

	public static function asCallExpr(expr:Expr, args:Array<Expr>, pos:haxe.macro.Expr.Position):Expr {
		return at(ECall(expr, args), pos);
	}

	public static function asPrivateAccessExpr(expr:Expr, pos:haxe.macro.Expr.Position):Expr {
		return at(EMeta( {name:":privateAccess", pos:pos}, expr), pos);
	}
}

