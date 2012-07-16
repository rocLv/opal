# Opal

**Opal is a ruby to javascript compiler.** Opal aims to take ruby files
and generate efficient javascript that maintains rubys features. Opal
will, by default, generate fast and efficient code in preference to
keeping all ruby features.

Opal comes with an implementation of the ruby corelib, written in ruby,
that uses a bundled runtime (written in javascript) that tie all the
features together. Whenever possible Opal bridges to native javascript
features under the hood. The Opal gem includes the compiler used to
convert ruby sources into javascript.

Opal is [hosted on github](http://github.com/adambeynon/opal), and there
is a Freenode IRC channel at `#opal`.

## Downloads

The Opal runtime and corelib are distributed here, and are required to
run any code generated by opal.

[Opal version 0.3.21](http://opalrb.org/opal.js) _(13.1kb Minified And Gzipped)_

## Installation

Opal should be added to your Gemfile:

```ruby
gem "opal"
```

## Usage

The easiest way to use opal is to create a rake task using the
`RakeTask` helper class. Assuming you have a single ruby file in
your Opal app called `app.rb`:

```ruby
# app.rb
puts "Hello world"
```

Then create a rake task similar to:

```ruby
# Rakefile
require 'opal/rake_task'

Opal::RakeTask.new do |t|
  t.files = ['app.rb']
end
```

### Building the app

Building the app is as simple as running:

```
rake opal:build
```

This will build all your listed files into `build/app_name.js`. The
output name is based on the directory name. This can be overriden by
setting the `.name` property in the task:

```ruby
Opal::RakeTask.new do |t|
  t.files = ['app.rb']
  t.name  = 'my_awesome_app'
end
```

### Building opal runtime

To run the app in the browser, the opal runtime is required. This can
be built using:

```
rake opal:dependencies
```

Which will build `opal.js` into `./build`.

The output directory can also be overriden inside the rake task:

```ruby
Opal::RakeTask.new do |t|
  t.files = ['app.rb']
  t.build_dir = 'out_dir'
end
```

The output directory will be created if it doesn't exist.

### Running the app

The two compiled files need to be added to a html page so that they
can run in the browser:

```html
<!doctype html>
<html>
<head>
  <title>My awesome Opal app</title>

  <script src="build/opal.js"></script>
  <script src="build/my_awesome_app.js"></script>

  <script>
    // Run opal app
    Opal.require('app')
  </script>
</head>
<body>
</body>
</html>
```

If you open the html file, observe the console and you should see
`"Hello World"` printed to the console.

It is necessary to run `Opal.require('app')` as all files built for
opal are registered so that they can be required inside the ruby
code.

### Adding dependencies

The `opal:dependencies` rake task above can be used to build gems which
are designed to run in the browser. `opal-dom` is a gem that given opal
access to the DOM in the browser.

`opal-dom` first needs to be installed as a gem (currently it is only
available from git):

```ruby
# Gemfile
gem "opal"
gem "opal-dom", :git => 'git://github.com/adambeynon/opal-dom.git'
```

Then add it to the dependencies to build:

```ruby
Opal::RakeTask.new do |t|
  t.files = ['app.rb']
  t.dependencies = ['opal-dom']
end
```

Running `rake opal:dependencies` now will also build
`build/opal-dom.js`.

We can now update our application code:

```ruby
# app.rb
require 'opal-dom'

alert "Hello!"
```

And rebuild:

```
rake opal:build
```

And add `opal-dom` to the html page:

```html
<script src="build/opal.js"></script>
<script src="build/opal-dom.js"></script>
<script src="build/app.js"></script>
```

Now running the app should cause an alert box to display.
 
## Features And Implementation

Opal is a source-to-source compiler, so there is no VM as such and the
compiled code aims to be as fast and efficient as possible, mapping
directly to underlying javascript features and objects where possible.

### Literals

**self** is always compiled to `self`. Any context inside the generated
code is usually a function body; whether it be a method body, a block,
a class/module body or the file itself.

**true** and **false** are compiled directly into their native boolean
equivalents. This makes interaction a lot easier as there is no need
to convert values to opal specific values. It does mean that there is
only a `Boolean` ruby class available, not seperate `TrueClass` and
`FalseClass` classes.

**nil** is compiled into a `nil` reference, which inside all generated
files points to a special object which is just an instance of the ruby
`NilClass` class. This object is available externally to javascript as
`Opal.nil`.

```ruby
nil         # => nil
true        # => true
false       # => false
self        # => self
```

#### Strings

Ruby strings are compiled directly into javascript strings for
performance as well as readability. This has the side effect that Opal
does not support mutable strings - i.e. all strings are immutable.

#### Symbols

For performance reasons, symbols compile directly into strings. Opal
supports all the symbol syntaxes, but does not have a real `Symbol`
class. Symbols and Strings can therefore be used interchangeably.

```ruby
"hello world!"    # => "hello world!"
:foo              # => "foo"
<<-EOS            # => "\nHello there.\n"
Hello there.
EOS
```

#### Numbers

In Opal there is a single class for numbers; `Numeric`. To keep opal
as performant as possible, ruby numbers are mapped to native numbers.
This has the side effect that all numbers must be of the same class.
Most relevant methods from `Integer`, `Float` and `Numeric` are
implemented on this class.

```ruby
42        # => 42
3.142     # => 3.142
```

#### Arrays

Ruby arrays are compiled directly into javascript arrays. Special
ruby syntaxes for word arrays etc are also supported.

```ruby
[1, 2, 3, 4]        # => [1, 2, 3, 4]
%w[foo bar baz]     # => ["foo", "bar", "baz"]
```

#### Hash

Inside a generated ruby script, a function `__hash` is available which
creates a new hash. This is also available in javascript as `Opal.hash`
and simply returns a new instance of the `Hash` class.

```ruby
{ :foo => 100, :baz => 700 }    # => __hash("foo", 100, "baz", 700)
{ foo: 42, bar: [1, 2, 3] }     # => __hash("foo", 42, "bar", [1, 2, 3]) 
```

#### Range

Similar to hash, there is a function `__range` available to create
range instances.

```ruby
1..4        # => __range(1, 4, true)
3...7       # => __range(3, 7, false)
```

#### Optimized Math Operators

In ruby, all math operators are method calls, but compiling this into
javascript would end up being too slow. For this reason, math
operators are optimized to test first if the receiver is a number, and
if so then to just carry out the math call.

```ruby
3 + 4
```

This ruby code will then be compiled into the following javascript:

```javascript
(a = 3, b = 4, typeof(a) === "number" ? a + b : /* method call */)
```

This ternary statement falls back on sending a method to the receiver
so all non-numeric receivers will still have the normal method call
being sent. This optimization makes math operators a **lot faster**.
Currently, the optimized method calls are `+`, `-`, `*` and `/`.

### method_missing

Method missing is fully supported in Opal. It is implemented as
efficiently as possible.

### Logic and conditionals

As per ruby, Opal treats only `false` and `nil` as falsy, everything
else is a truthy value including `""`, `0` and `[]`. This differs from
javascript as these values are also treated as false.

For this reason, most truthy tests must check if values are `false` or
`nil`.

Taking the following test:

```javascript
val = 42

if val
  return 3.142;
end
```

This would be compiled into:

```ruby
val = 42;

if (val !== false && val !== nil) {
  return 3.142;
}
```

This makes the generated truthy tests (`if` statements, `and` checks and
`or` statements) a litle more verbose in the generated code.

### Instance variables

Instance variables in Opal work just as expected. When ivars are set or
retrieved on an object, they are set natively without the `@` prefix.
This allows real javascript identifiers to be used which is more
efficient then accessing variables by string name.

```ruby
@foo = 200
@foo  # => 200

@bar  # => nil
```

This gets compiled into:

```javascript
this.foo = 200;
this.foo;   // => 200

this.bar;   // => nil
```

The only point of warning is that when variables are used for the
first time in ruby, they default to `nil`. In javascript, they default
to `undefined`/`null`.

To keep things working in opal, ivars must be preset to `nil` before
they can be used. In the top scope and other corner cases, this needs
to be done on a per scope basis, which can add overhead.

To improve performance, once a class body is compiled, all ivars used
within methods in that class are preset on the prototype of the class
to be `nil`. This means that all known ivars are already set to nil,
and this is done just once during the lifespan of the app.

```ruby
class Foo
  def bar
    @lol
  end

  def woosh
    @kapow
  end
end
```

This example gets compiled into something similar to:

```javascript
(function() {
  function Foo(){}
  // ...

  Foo.prototype.lol = Foo.prototype.woosh = nil;

  Foo.prototype.$bar = function() {
    return this.lol;
  };

  // etc ...
})()
```

### Interacting with javascript

Opal tries to interact as cleanly with javascript and its api as much
as possible. Ruby arrays, strings, numbers, regexps, blocks and booleans
are just javascript native equivalents. The only boxed core features are
hashes and nil.

As most of the corelib deals with these low level details, opal provides
a special syntax for inlining javascript code. This is done with
x-strings or "backticks", as their ruby use has no useful translation
in the browser.

```ruby
`window.title`
# => "Opal: ruby to javascript compiler"

%x{
  console.log("ruby version is:");
  console.log(#{ OPAL_VERSION });
}

# => ruby version is:
# => 0.3.19
```

Even interpolations are supported, as seen here.

This feature of inlining code is used extensively, for example in
Array#length:

```ruby
class Array
  def length
    `this.length`
  end
end
```

X-Strings also have the ability to automatically return their value,
as used by this example.

### Compiled Files

As described above, a compiled ruby source gets generated into a string
of javascript code that is wrapped inside an anonymous function. This
looks similar to the following:

```javascript
(function() {
  var nil = Opal.nil, self = Opal.top;
  // generated code
})();
```

Inside the function, `nil` is assigned to ensure a local copy is
available, as well as all the helper methods used within the
generated file. There is no return value from these functions as they
are not used anywhere.

As a complete example, assuming the following code:

```ruby
puts "foo"
```

This would compile directly into:

```javascript
(function() {
  var nil = Opal.nil, self = Opal.top;
  self.$puts("foo");
})();
```

Most of the helpers are no longer present as they are not used in this
example.

### Using compiled sources

If you write the generated code as above into a file `app.js` and add
that to your HTML page, then it is obvious that `"foo"` would be
written to the browser's console.

### JSON

The opal corelib includes JSON support instead of treating it as an
external lib. The `JSON` module provides the usual parsing methods.

```ruby
JSON.parse '{"a": 10, "b": [1, 2, 3], "c": null}'
# => { "a" => 10, "b" => [1, 2, 3], "c" => nil }
```

Opal expects `JSON` to be present in the browser, so older browsers
may require a shim (json2.js) to work with opal. Most mobile browsers
and modern desktop browsers include json support natively.

## Debugging and finding errors

Because Opal does not aim to be fully compatible with ruby, there are
some instances where things can break and it may not be entirely
obvious what went wrong.

### Undefined methods

By default, opal aims to be as fast as possible, so `method_missing` is
not turned on by default. Instead, when calling a method that doesn't
exist, a native error will be raised.

```ruby
self.do_something()
```

Might raise an error similar to:

```
Error: 'undefined' is not a function (evaluating 'this.$do_something()')
```

As described above, all ruby methods will have a `$` prefix which gives
a good indication that it is a opal method that doesnt exist, and most
js engines output the missing function name.

### Undefined constants

If trying to access a constant that doesn't exist, there is no runtime
error. Instead, the value of that expression is just `undefined` as
constants are retrieved from objects that hold all constants in the
scope. Trying to send a method to an undefined constant will therefore
just raise an ugly javascript `TypeError`.

If you are using the constant as a reference, it may not be until much
later that the error occurs.

### Using javascript debuggers

As opal just generates javascript, it is useful to use a native
debugger to work through javascript code. To use a debugger, simply
add an x-string similar to the following at the place you wish to
debug:

```ruby
# .. code
`debugger`
# .. more code
```
The x-strings just pass the debugger statement straight through to the
javascript output.

Inside methods and blocks, the current `self` value is always the
native `this` value. You will not see `self` inside debuggers as it is
never used to refer to the actual ruby self value.

All local variables and method/block arguments also keep their ruby
names except in the rare cases when the name is reserved in javascript.
In these cases, a `$` suffix is added to the name (e.g. `try` =>
`try$`).

## License

Opal is released under the MIT license.

## Change Log

**0.3.21** _(16 July 2012)_

* Add `method_missing` support to all objects and classes
* Add `Opal.build_gem()` method to quickly build installed gem
* Add `Opal.build_files()` method to build directories of files

**0.3.20** _(23 June 2012)_

* Merge JSON into core. JSON module and various #to_json methods are
  now included as part of corelib
* Make `Time` class bridge to native `Date` constructor
* Use named functions as class constuctors to make debugging easier
* Classes are now real functions with prototypes. Bridged classes are
  now directly corresponding to the ruby class (e.g. Array === Opal.Array)
* Set ivars used inside methods in class to `nil` inside class definition
  to avoid doing it everytime method is called
* Add debug comments to output for def, class and module stating the file
  and line number the given code was generated from

**0.3.19** _(30 May 2012)_

* Add BasicObject as the root class
* Add `Opal.define` and `Opal.require` for requiring files
* Builder uses a `main` option to dictate which file to require on load
* Completely revamp runtime to reduce helper methods
* Allow native bridges (Array, String, etc) to be subclassed
* Make sure `.js` files can be built with `Opal::Builder`
* Include the current file name when raising parse errors

**0.3.18** _(20 May 2012)_

* Fix various core lib bugs
* Completely remove `require` from corelib
* Improve Builder to detect dependencies in files

**0.3.17** _(19 May 2012)_

* Revamp of Builder and Parser tools
* Remove opal-repl
* Added a lot of specs for core lib

**0.3.16** _(15 January 2012)_

* Added HEREDOCS support in parser
* Parser now handles masgn (mass/multi assignments)
* More useful DependencyBuilder class to build gems dependencies
* Blocks no longer passed as an argument in method calls

**0.3.15**

* Initial Release.