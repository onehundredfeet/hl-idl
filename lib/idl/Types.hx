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
