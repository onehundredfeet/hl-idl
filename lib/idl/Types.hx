package idl;

#if hl
abstract Ref(hl.Bytes) {}
abstract Any(hl.Bytes) {}
abstract VoidPtr(hl.Bytes) from hl.Bytes {}
abstract NativePtr<T>(hl.BytesAccess<T>) {}

#else
abstract Ref(Dynamic) {}
abstract Any(Dynamic) {}
abstract VoidPtr(Dynamic) {}
abstract NativePtr<T>(Dynamic) {}

abstract ReferencableInt64(haxe.Int64) to haxe.Int64 from haxe.Int64{
    public function new(v : haxe.Int64) {
        this = v;
    }
    #if cpp
    @:to
    public inline function toRef() {
        return cpp.Pointer.addressOf(this);
    }

    #end
}


abstract ReferencableInt(Int) to Int from Int{
    public function new(v : Int) {
        this = v;
    }
    public inline function asInt() : Int{
        return this;
    }
    #if cpp
    @:to
    public function toRef() {
        return cpp.Pointer.addressOf(this);
    }

    #end
}
#end

#if cpp

// class StructArray<T> {
    
//     var ptr:cpp.Pointer<T>;
//     var array:Array<T>;

//     public inline function new(capacity:Int) {
//         this.size = 0;
//         this.capacity = capacity;
//         this.array = cpp.NativeArray.create(capacity);
//         this.ptr = cpp.Pointer.ofArray(this.array);
//     }
//     @:op([]) public inline function get(index:Int):T {
//         return this.data[index];
//     }
//     @:op([]) public inline function set(index:Int, value:T):Void {
//         this.data[index] = value;
//     }

//     public var length(get,never):Int;
//     public inline function get_length():Int {
//         return this.size;
//     }
// }

#end
