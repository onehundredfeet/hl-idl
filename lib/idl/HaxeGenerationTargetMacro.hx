package idl;

import haxe.io.UInt8Array;
import haxe.macro.Printer;
import idl.Data;
import haxe.macro.Expr;

using StringTools;
using idl.macros.MacroTools;

import idl.HaxeGenerationTarget;

class HaxeGenerationTargetMacro extends HaxeGenerationTarget {
	static final PROXY_NEW_NAME = "alloc";
	static final PROXY_DELETE_NAME = "free";
	static final PROXY_STRUCT_MAKE = "make";
	static final REDIRECT_PREFIX = "_r_";

	function getTargetCondition():String {
		return "#if macro";
	}

	function makeVectorType(t:TypeAttr, vt:Type, vdim:Int, isReturn:Bool):ComplexType {
		return switch (vt) {
			case TFloat:
				switch (vdim) {
					case 2: macro :hvector.Vec2;
					case 3: macro :hvector.Vec3;
					case 4: macro :hvector.Vec4;
					default: throw "Unsupported vector dimension" + vdim;
				}
			case TInt:
				switch (vdim) {
					case 2: macro :hvector.Int2;
					case 3: macro :hvector.Int3;
					case 4: macro :hvector.Int4;
					default: throw "Unsupported vector dimension" + vdim;
				}
			case TDouble:
				switch (vdim) {
					case 2: macro :hvector.Float2;
					case 3: macro :hvector.Float3;
					case 4: macro :hvector.Float4;
					default: throw "Unsupported vector dimension" + vdim;
				}

			default: throw "Unsupported vector type " + vt;
		};
	}

	public function makeNativeMeta(iname:String, midfix:String, name:String, argc:Null<Int>, attrs:Array<Attrib>,
			p:haxe.macro.Expr.Position):Array<MetadataEntry> {
		return null;
	}

	function makeType(t:TypeAttr, isReturn:Bool):ComplexType {
		return macro :Void;
	}

	public function getInterfaceTypeDefinitions(iname:String, attrs:Array<Attrib>, pack:Array<String>, dfields:Array<Field>, ikind:InterfaceKind,
			p:Position):Array<TypeDefinition> {
		return [];
	}

	public override function addAttribute(iname:String, haxeName:String, f:idl.Data.Field, t:TypeAttr, p:Position):Array<haxe.macro.Expr.Field> {
		return [];
	}

	public override function makeEnum(name:String, attrs:Array<Attrib>, values:Array<String>, fields:Array<idl.Data.Field>,
			p:haxe.macro.Expr.Position):Array<{def:haxe.macro.Expr.TypeDefinition, path:haxe.macro.Expr.TypePath}> {
		var enumT:TypeDefinition = {
			pos: p,
			pack: _pack,
			name: makeName(name),
			meta: [],
			kind: TDAbstract(macro :Int, [AbEnum]), // implName.asComplexType()
			fields: [],
		};

		return [{def: enumT, path: {pack: _pack, name: enumT.name}},];

	}
}
