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
		var isOut = t.attr != null && t.attr.contains(AOut);

		return switch (t.t) {
			case TVoid: macro :Void;
			case TChar: macro :Int;
			case TInt, TUInt: macro :Int;
			case TInt64: macro :haxe.Int64;
			case TShort: macro :cpp.Char;
			case TFloat: macro :Float;
			case TDouble: macro :Float;
			case TBool: macro:Bool;
			case TDynamic: macro :Dynamic;
			case TType: throw "Unsupported type TType";
			case THString: macro :String;
			case TCString: macro :String;
			case TStdString: macro :String;
			case TAny: macro :idl.Types.Any;
			case TEnum(enumName): isReturn ? enumName.asComplexType() : macro :Int;
			case TStruct: throw "Unsupported type TType";
			case TBytes: macro :Dynamic;
			case TIOBytes: macro :haxe.io.Bytes;
			case TVector(vt, vdim): makeVectorType(t, vt, vdim, isReturn);
			case TPointer(pt):
				switch (pt) {
					case TChar: macro :Array<cpp.Char>;
					case TInt: macro :Array<Int>;
					case TUInt: macro :Array<UInt>;
					case TFloat: macro :Array<Single>;
					case TDouble: macro :Array<Float>;
					case TBool: macro :Array<Bool>;
					case TShort: macro :Array<cpp.UInt16>;
					case TVector(vt, dim):
						switch (vt) {
							case TFloat: macro :Array<Single>;
							case TDouble: macro :Array<Float>;
							case TInt: macro :Array<Int>;
							default: throw "Unsupported array vector type " + vt;
						}
					case TCustom(id):
						// var x : TypeParam;
						// TPath({pack: ["cpp"], name: "Pointer", params: [TPType(TPath(_typeInfos[id].path))]});
						(id + "Ptr").asComplexType();
					default:
						throw 'Unsupported array type. Sorry ${pt}';
				}
			case TArray(at, _):
				switch (at) {
					case TChar: macro :Array<Int>;
					case TInt: macro :Array<Int>;
					case TUInt: macro :Array<UInt>;
					case TFloat: macro :Array<Single>;
					case TDouble: macro :Array<Float>;
					case TBool: macro :Array<Bool>;
					case TShort: macro :Array<Int>;
					case TVector(t, dim): switch (t) {
							case TInt: switch (dim) {
									case 2: macro :hvector.Int2Array;
									case 3: macro :hvector.Int3Array;
									case 4: macro :hvector.Int4Array;
									default: macro :Array<Int>;
								}
							case TFloat:
								switch (dim) {
									case 2: macro :hvector.Vec2Array;
									case 3: macro :hvector.Vec3Array;
									case 4: macro :hvector.Vec4Array;
									default: macro :Array<Single>;
								}
							case TDouble:
								switch (dim) {
									case 2: macro :hvector.Float2Array;
									case 3: macro :hvector.Float3Array;
									case 4: macro :hvector.Float4Array;
									default: macro :Array<Float>;
								}
							default: throw "Unsupported array type. Sorry";
						}
					case TCustom(id):
						if (_typeInfos.exists(id)) TPath({pack: ["cpp"], name: "NativeArray", params: [TPType(TPath(_typeInfos[id].path))]}); else
							TPath({pack: ["cpp"], name: "NativeArray", params: [TPType(TPath({pack: [], name: makeName(id)}))]});

					default:
						throw "Unsupported array type. Sorry";
				}
			//			var tt = makeType({ t : t, attr : [] });
			//			macro : idl.Types.NativePtr<$tt>;
			case TVoidPtr: macro :idl.Types.VoidPtr;
			case TFunction(ret, ta):
				var retT = makeType(ret, false);

				var args = ta.map((x) -> makeType(x, false));
				//			macro : GameControllerPtr -> hl.Bytes -> $retT;
				TFunction(args, retT);
			case TCustom(id):
				if (_typeInfos.exists(id)) {
					var ti:HaxeGenerationTypeInfo = _typeInfos.get(id);
					// trace('custom type ${id} has ${ti}');

					switch (ti.kind) {
						case DInterface(name, attrs, _, _):
							var ict = name.asComplexType();
							macro :$ict;
						default:
							TPath(ti.path);
					}
				} else {
					trace('no info for ${id}');
					TPath({pack: [], name: makeName(id)});
				}
		}
	}

	public function getInterfaceTypeDefinitions(iname:String, attrs:Array<Attrib>, pack:Array<String>, dfields:Array<Field>, ikind:InterfaceKind,
			p:Position):Array<TypeDefinition> {
		var types = [];

		var haxeName = makeName(iname);
		var proxyName = haxeName;
		var fullProxyName = pack.join(".") + "." + proxyName;

		switch (ikind) {
			case IKAbstract(underlaying):
			case IKObject:
				var fields = [];
				for (df in dfields) {
					if (df.name == "new") {
						var structMake = {
							pos: p,
							name: PROXY_STRUCT_MAKE,
							meta: [],
							access: [APublic, AStatic],
							kind: FFun({args: [], ret: fullProxyName.asComplexType(), expr: macro return null}), // macro {return null;}
						};
						fields.push(structMake);
					}
				}

				var objTD:TypeDefinition = {
					pos: p,
					pack: _pack,
					name: makeName(iname),
					meta: [],
					kind: TDClass(),
					fields: fields,
				}
				types.push(objTD);
			case IKNamespace:
		}
		return types;
	}

	public override function addAttribute(iname:String, haxeName:String, f:idl.Data.Field, t:TypeAttr, p:Position):Array<haxe.macro.Expr.Field> {
		return [];
	}

	public override function makeEnum(name:String, attrs:Array<Attrib>, values:Array<String>, fields:Array<idl.Data.Field>,
			p:haxe.macro.Expr.Position):Array<{def:haxe.macro.Expr.TypeDefinition, path:haxe.macro.Expr.TypePath}> {
		var cfields = [];
		for (f in fields) {
			var fname = f.name;
			switch (f.kind) {
				case FMethod(args, ret):
					var attr = ret.attr;
					var isStatic = attr.contains(AStatic);
					if (!isStatic) {
						throw "Unsupported non-static method in enum";
					}

					var retValue = defVal(ret);
					var fieldMethod = {
						pos: p,
						name: fname,
						kind: FFun({args: [], ret: makeType(ret, true), expr: macro return $retValue}),
						meta: [],
						access: [APublic, AStatic],
					};

					cfields.push(fieldMethod);
				// trace('method ${fname} ${args} ${ret}');
				default:
					throw 'Unsupported field kind ${f.kind}';
			}
		}

		var enumT:TypeDefinition = {
			pos: p,
			pack: _pack,
			name: makeName(name),
			meta: [],
			kind: TDAbstract(macro :Int, [AbEnum]), // implName.asComplexType()
			fields: cfields,
		};

		return [{def: enumT, path: {pack: _pack, name: enumT.name}},];
	}
}
