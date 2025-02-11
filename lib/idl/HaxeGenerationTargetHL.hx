package idl;

import idl.Data;
import haxe.macro.Expr;

using StringTools;
using idl.macros.MacroTools;

class HaxeGenerationTargetHL extends HaxeGenerationTarget {
	function getTargetCondition():String {
		return "#if hl";
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


	function makeNativeMeta(iname : String, midfix : String, name : String, argc : Null<Int>, attrs:Array<Attrib>, p:haxe.macro.Expr.Position):Array<MetadataEntry> {
		if (midfix == null) midfix = "_";
		var nativeName = iname + midfix + name + (name == "delete" || argc == null ? "" : "" + argc);

		
		return [
			{name: ":hlNative", params: [
				{expr: EConst(CString(opts.nativeLib)), pos: p},
				{expr: EConst(CString(nativeName)), pos: p}
			], pos: p}
		];
	}

	function makeType(t:TypeAttr, isReturn:Bool):ComplexType {
		var isOut = t.attr != null && t.attr.contains(AOut);

		return switch (t.t) {
			case TVoid: macro :Void;
			case TChar: macro :hl.UI8;
			case TInt, TUInt: (isOut) ? macro :hl.Ref<Int> : macro :Int;
			// case TInt64 : hl ? macro : hl.I64 : macro : haxe.Int64;
			case TInt64: ((isOut ? (macro :hl.Ref<haxe.Int64>) : (macro :haxe.Int64)));
			case TShort: macro :hl.UI16;
			case TFloat: ((isOut ? (macro :hl.Ref<Single>) : (macro :Single)));
			case TDouble: ((isOut ? (macro :hl.Ref<Float>) : (macro :Float)));
			case TBool: ((isOut ? (macro :hl.Ref<Bool>) : (macro :Bool)));
			case TDynamic: macro :Dynamic;
			case TType: macro :hl.Type;
			case THString: isReturn && false ? macro :hl.Bytes : macro :String;
			case TCString: macro :hl.Bytes;
			case TStdString: macro :hl.Bytes;
			case TAny: macro :idl.Types.Any;
			case TEnum(enumName): isReturn ? enumName.asComplexType() : macro :Int;
			case TStruct: macro :hl.Bytes;
			case TBytes: macro :hl.Bytes;
			case TIOBytes:macro : haxe.io.Bytes;
			case TVector(vt, vdim): makeVectorType(t, vt, vdim, isReturn);
			case TPointer(pt):
				switch (pt) {
					case TChar: macro :hl.BytesAccess<hl.UI8>;
					case TInt: macro :hl.BytesAccess<Int>;
					case TUInt: macro :hl.BytesAccess<UInt>;
					case TFloat: macro :hl.BytesAccess<Single>;
					case TDouble: macro :hl.BytesAccess<Float>;
					case TBool: macro :hl.BytesAccess<Bool>;
					case TShort: macro :hl.BytesAccess<hl.UI16>;
					case TVector(vt, dim):
						switch (vt) {
							case TFloat: macro :hl.BytesAccess<Single>;
							case TDouble: macro :hl.BytesAccess<Float>;
							case TInt: macro :hl.BytesAccess<Int>;
							default: throw "Unsupported array vector type " + vt;
						}
					case TCustom(id):
						id.asComplexType();
					default:
						throw 'Unsupported array type. Sorry ${pt}';
				}
			case TArray(at, _):
				switch (at) {
					case TChar: macro :hl.NativeArray<hl.UI8>;
					case TInt: macro :hl.NativeArray<Int>;
					case TUInt: macro :hl.NativeArray<UInt>;
					case TFloat: macro :hl.NativeArray<Single>;
					case TDouble: macro :hl.NativeArray<Float>;
					case TBool: macro :hl.NativeArray<Bool>;
					case TShort: macro :hl.NativeArray<hl.UI16>;
					case TVector(t, dim): switch (t) {
							case TInt: switch (dim) {
									case 2: macro :hvector.Int2Array;
									case 4: macro :hvector.Int4Array;
									default: macro :hl.NativeArray<Int>;
								}
							case TFloat:
								switch (dim) {
									case 2: macro :hvector.Vec2Array;
									case 4: macro :hvector.Vec4Array;
									default: macro :hl.NativeArray<Single>;
								}
							case TDouble: macro :hl.NativeArray<Float>;
							default: throw "Unsupported array type. Sorry";
						}
					case TCustom(id):
						if (_typeInfos.exists(id)) TPath({pack: ["hl"], name: "NativeArray", params: [TPType(TPath(_typeInfos[id].path))]}); else TPath({pack: ["hl"],
							name: "NativeArray", params: [TPType(TPath({pack: [], name: makeName(id)}))]});

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
					TPath(_typeInfos[id].path);
				} else TPath({pack: [], name: makeName(id)});
		}
	}

	public function getInterfaceTypeDefinitions(iname:String,  attrs:Array<Attrib>,pack:Array<String>, dfields:Array<Field>,  ikind:InterfaceKind, p:Position):Array<TypeDefinition> {
		return [{
			pos: p,
			pack: pack,
			name: makeName(iname),
			meta: [],
			kind: TDAbstract(macro :idl.Types.Ref, [], [macro :idl.Types.Ref], [macro :idl.Types.Ref]),
			fields: dfields,
		}];
	}
	


}
