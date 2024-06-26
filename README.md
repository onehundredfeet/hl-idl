# Hashlink & Haxe/JS IDL

This library allows to access any C++ library from Haxe/JS (using Emscripten or Web Assembly) and Haxe/HashLink by simply defining an idl file.

Hashlink is currently the primary platform.  Haxe/JS may lag a little bit behind.

For a complete example, see the [sample](https://github.com/onehundredfeet/hl-idl/tree/master/sample)

## Installing

```bash
git clone https://github.com/onehundredfeet/hl-idl.git # Clone the repo
haxelib dev webidl webidl # Set the webidl package install directory to the cloned repo
```

## Usage

Given the following IDL file describing a C++ library:

```java
interface Point {
    attribute long x;
    attribute long y;
    void Point();
    void Point( long x, long y );
    [Operator="*",Ref] Point op_add( [Const,Ref] Point p );
    double length();
};
```

And the following Haxe code (**strictly typed** thanks to IDL definitions):

```haxe
class Sample {

    public static function main() {
	var p1 = new Point();
	p1.x = 4;
	p1.y = 5;
	var p2 = new Point(7,8);
	var p = p1.op_add(p2);
	trace('Result = ${p.x},${p.y} len=${p.length()}');
	p1.delete();
	p2.delete();
	p.delete();
    }
	
}
```

This compiles to the following Javascript:

```js
// Generated by Haxe 4.0.0
(function () { "use strict";
var Sample = function() { };
Sample.main = function() {
    var this1 = _eb_Point_new0();
    var p1 = this1;
    _eb_Point_set_x(p1,4);
    _eb_Point_set_y(p1,5);
    var this2 = _eb_Point_new2(7,8);
    var p2 = this2;
    var p = _eb_Point_op_add1(p1,p2);
    console.log("Result = " + _eb_Point_get_x(p) + "," + _eb_Point_get_y(p) + " len=" + _eb_Point_length0(p));
    _eb_Point_delete(p1);
    _eb_Point_delete(p2);
    _eb_Point_delete(p);
};
Sample.main();
})();
```

Haxe webidl can be used for both Haxe/JS and Haxe/HashLink, the cpp bindings generated are the same for both platforms.


## Extensions
To make writing a broader range of adapters into more usable Haxe, we have added several constructs that extend the webidl spec. Most of these take the form of attributes.  Attributes are specified with a [] around a keyword.

### Strings
Strings are returned as Dynamics as hashlink seems to only support creation of Dynamics from string content. Strings are passed as vstring * which allows you to pass in a string type directly.

### Enums
Enums have an extension function that will return the integer value of the enum specified in C/C++.

```haxe
MyEnum.Value.toValue();
//or
var x = MyEnum.Value;
x.toValue();
```

### \[Internal=NAME\]
This allows you to override the name used to pass to the C functions.  It allows you to clean up the name of things for Haxe.

```
[Internal="LIB_Session"]
interface Session {
    [Internal="LIB_Func"] void Func();
}

```

This will allow you to simply use 'Session' while the translator knows that the class is HAPI_Session for the C/C++ integration.

### \[CObject\]
This tag on a function will tell the translator that the object is passed 'c' style instead of c++ style.


}

```c++

interface MyClass {
    void func();
}

//Generated call - C++ style
obj->func();
```




```c
interface MyClass {
    [CObject] void func();
}

//Generated call - C Style - [CObject]
func(obj);
```

This will automatically add a pointer of the class type as the first argument


### Validate & Throw
\[Validate="Value"\]

This will check to see if the return value of the function equals the value specified.  If so, another action is taken.  Right now, the only action supported is 'Throw'

\[Throw="expression"\]
This will be thrown as is if the validation check is failed
```
interface MyClass {
[Validate="0", Throw="\"Result is non-zero\""] int func();
}
```

### Return
This is a tricky one.  It's intended to simplify C-style out value passing by reference.

Instead of specifying a pointer to a value that is to be set by the function, you can bypass the typical return and return this value instead.  It is used for scenarios where the return value is intended to return an error code. 

This is often used in conjunction with Validate & Throw

```
interface MyClass {
int func([Return] int outCount);
}

```

```haxe
var x = new MyClass();
var y = x.func(); // Now returns directly instead of being passed by reference.  
```

Internally, this will call the C++ function with a pointer. The value will be cached and then returned.

```c++
int tmp;
this->func(&tmp);
return tmp;
```

### Conversion Routines
In order to do tricky translation from an internal type to a more haxe friendly type, sometimes custom routines are needed.

\[Get="c++ function_name"\] will wrap the autogenerated return with a call to this function. This function is expected to return a compatible type with the autogenerated signature.  This also works on attributes.

\[Set="c++ function_name"\] will wrap the autogenerated conversion code before passing or assigning the value to the native code. This also works on attributes.

```haxe
interface MyClass {
    [Set="int_to_int64"] void set_func( int a );
}
```
This will pass 'a' into the conversion before passing it into the C version of set_func.


