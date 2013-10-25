Buffer
======

A buffer object for LuaJIT.

Install
-------

```
luarocks install buffer
```

Simple use cases
----------------

Load lib:

```lua
> b = require 'buffer'
```

Create a buffer, from a string, with a size, or from
another buffer:

```lua
> buf = b'some'
> print(buf)
<Buffer 73 6f 6d 65>
> buf = b(10)
> print(buf)
<Buffer 00 00 00 00 00 00 00 00 00 00>
> buf2 = b(buf)
> print(buf2)
<Buffer 00 00 00 00 00 00 00 00 00 00>
> buf[1] = 10
> bug[2] = 20
> print(buf2)
<Buffer 0a 1e 00 00 00 00 00 00 00 00>
```

Creating buffers never makes copies. A buffer created from a string
always references the content of the string. A buffer created from
another buffer references the same buffer.

Concatenating two buffers is done like it's done for strings:

```lua
> a = b'some' .. b'thing'
> str = a:toString()
> print(str)
something
```

The `toString` method simply returns a Lua string from the buffer. 
In this case, the string is a copy, which won't be affected by further
changes of the buffer:

```lua
> a[1] = a[1] + 1
> print(str)
something
> print(a:toString())
tomething
```

A slicing operatora is provided:

```lua
> a = b'testing'
> print(a[{1,4}])
test
> a[{1,4}] = 'sing'
> a[{1,4}] = b'sing'  -- both supported
> print(a)
singing
```

A buffer can be created from a list of buffers, which provides efficient
concatenation:

```lua
> a1 = b'test'
> a2 = b'test'
> a3 = b'again'
> a = b(a1,a2,a3)
> print(a:toString())
testtestagain
> b = b( {a1,a2,a3} )
> print(b:toString())
testtestagain
```

License
-------

Code was originally borrowed from the Luvit folks. I've kept their license:

Copyright 2012 The Luvit Authors. All Rights Reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS-IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

