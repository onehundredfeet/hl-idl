package idl;

typedef Data = Array<Definition>;

typedef Position = {
	var file : String;
	var line : Int;
	var pos : Int;
}

typedef Definition = {
	var pos : Position;
	var kind : DefinitionKind;
}
typedef Field = {
	var name : String;
	var kind : FieldKind;
	var pos : Position;
}

enum InterfaceKind {
	IKAbstract(underlaying:Type);
	IKObject;
	IKNamespace;
}
enum DefinitionKind {
	DInterface( name : String, attrs : Array<Attrib>, fields : Array<Field>, kind : InterfaceKind );
	DInclude( name : String );
	DImplements( type : String, interfaceName : String );
	DEnum( name : String, attrs : Array<Attrib>, values : Array<String>, fields : Array<Field> );
	DTypeDef( name : String, attrs : Array<Attrib>, type : String, dtype : Type );
}

enum FieldKind {
	FMethod( args : Array<FArg>, ret : TypeAttr ); // parser doesn't know the difference between method attributes and return attributes, attrs : Array<Attrib> );
	FAttribute( t : TypeAttr );
	DConst( name : String, type : Type, value : String );
}

typedef FArg = { name : String, opt : Bool, t : TypeAttr };
typedef TypeAttrData = { var t : Type; var attr : Array<Attrib>; };

@:forward
abstract TypeAttr( TypeAttrData ) from TypeAttrData to TypeAttrData {
	public function getElementType() {
		return switch (this.t) {
			case TPointer(at), TArray(at, _):{t: at, attr: this.attr};
			default: throw "Not an array type: " + this.t.getName() + " : " + this.t.getParameters();
		}
	}
}

enum Type {
	TVoid;
	TChar;
	TInt;
	TUInt; // 32 bits unsigned int
	TShort;
	TFloat;
	TDouble;
	TBool;
	TAny;
	TVoidPtr;
	THString;
	TCString;
	TStdString;
	TIOBytes;
	TBytes;
	TEnum(name : String );
	TCustom( id : String );
	TArray( t : Type, sizeField : String );
	TPointer( t : Type );
	TInt64;
	TVector( t : Type, dim: Int);
	TDynamic;
	TStruct;
	TType;
	TFunction(ret : TypeAttr, ta : Array<TypeAttr>);
}

enum Attrib {
	// fields
	AValue;
	ARef;
	AAddressOf;
	AClone;
	ADeref;
	ACast( type : String );
	ASetCast( type : String );
	AGetCast( type : String );
	AConst;
	AHString;
	ACStruct;
	AReadOnly;
	AIndexed;
	AOut;
	AOperator( op : String );
	// interfaces
	ANoDelete;
	ANoNamespace;
	AAutoConstructor;
	AEmbed;
	AClass;
	AStatic;
	AAllowArray;
	AInclude( name : String );
	AVirtual;
	ASynthetic;
	AReturn;
	AReplace(match : String, with : String);
	ASubstitute(expression : String);
	AThrow(msg :String);
	AValidate(expression : String);
	ACObject;
	ACObjectRef;
	ASTL;
	ALocal;
	AIgnore;
	AInternal(name:String);
	AGet(name:String);
	ASet(name:String);
	APrefix( prefix : String );
	AJSImplementation( name : String );	
	ARemap(original:String, remapped: String);
	AReturnArray(pointerArg : String, lengthArg : String);
	ADelete( name : String );	
	ADestruct( expression : String);
	ANew( name : String );	
	AConvert( functionName : String );
	AInitialize;
	AUpperCaseFirst;
	AForceCamelCase;
}
