--[[

Note (C.Farabet): this code was borrowed from the Luvit 
project. License preserved below. New functionality was
added to this buffer class.

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

--]]

local bit = require('bit')
local ffi = require('ffi')
ffi.cdef[[
void *malloc(size_t __size);
void free(void *__ptr);
]]

local Buffer = {
   meta = {}
}

function Buffer:initialize(...)
   local args = {...}
   local arg1,arg2,arg3 = unpack(args)
   if type(arg1) == "number" then
      local length = arg1
      self.length = length
      self.ctype = ffi.gc(ffi.cast("unsigned char*", ffi.C.malloc(length)), ffi.C.free)
   elseif type(arg1) == "string" then
      local string = arg1
      self.length = #string
      self.ctype = ffi.cast("unsigned char*", string)
   elseif type(arg1) == "table" then
      if type(arg2) == 'number' then
         local buffer = arg1
         local start = arg2 or 1
         local last = arg3 or buffer.length
         assert(start>=1 and last<=buffer.length, 'incorrect bounds')
         self.length = last - start + 1
         self.ctype = buffer.ctype - 1 + start
         self.ref = buffer -- keep lua ref for GC
      elseif type(arg2) == "table" then
         -- concat buffers:
         self.length = 0
         for _,buffer in ipairs(args) do
            self.length = self.length + buffer.length
         end
         self.ctype = ffi.gc(ffi.cast("unsigned char*", ffi.C.malloc(self.length)), ffi.C.free)
         local offset = 0
         for _,buffer in ipairs(args) do
            ffi.copy(self.ctype+offset, buffer.ctype, buffer.length)
            offset = offset + buffer.length
         end
      elseif not arg2 and arg1[1] and type(arg1[1]) == 'table' then
         -- concat buffers:
         args = arg1
         self.length = 0
         for _,buffer in ipairs(args) do
            self.length = self.length + buffer.length
         end
         self.ctype = ffi.gc(ffi.cast("unsigned char*", ffi.C.malloc(self.length)), ffi.C.free)
         local offset = 0
         for _,buffer in ipairs(args) do
            ffi.copy(self.ctype+offset, buffer.ctype, buffer.length)
            offset = offset + buffer.length
         end
      end
   else
      error("Input must be a string, a number or a buffer")
   end
end

function Buffer:new(...)
   local b = {}
   setmetatable(b, Buffer.meta)
   Buffer.initialize(b,...)
   return b
end

setmetatable(Buffer, {
   __call = Buffer.new
})

function Buffer.meta:__ipairs()
   local index = 0
   return function (...)
      if index < self.length then
         index = index + 1
         return index, self[index]
      end
   end
end

function Buffer.meta:__tostring()
   local parts = {}
   for i = 1, tonumber(self.length) do
      parts[i] = bit.tohex(self[i], 2)
   end
   return "<Buffer " .. table.concat(parts, " ") .. ">"
end

function Buffer.meta:__concat(other)
   local new = Buffer(self.length + other.length)
   new:slice(1,self.length):copy(self)
   new:slice(self.length+1,new.length):copy(other)
   return new
end

function Buffer.meta:__index(key)
   if type(key) == "number" then
      if key < 1 or key > self.length then error("Index out of bounds") end
      return self.ctype[key - 1]
   elseif type(key) == "table" then
      local start,last = key[1],key[2]
      return self:slice(start,last)
   end
   return Buffer[key]
end

function Buffer.meta:__newindex(key, value)
   if type(key) == "number" then
      if key < 1 or key > self.length then error("Index out of bounds") end
      self.ctype[key - 1] = value
      return
   elseif type(key) == "table" then
      local start,last = key[1],key[2]
      self:slice(start,last):copy(value)
      return
   end
   rawset(self, key, value)
end

function Buffer:slice(start,last)
   return Buffer(self, start, last)
end

function Buffer:copy(src)
   if type(src) == 'string' then
      src = Buffer(src)
   end
   assert(src.length == self.length, 'src and dst must have same length')
   ffi.copy(self.ctype, src.ctype, self.length)
   return self
end

local function compliment8(value)
   return value < 0x80 and value or -0x100 + value
end

function Buffer:readUInt8(offset)
   return self[offset]
end

function Buffer:readInt8(offset)
   return compliment8(self[offset])
end

local function compliment16(value)
   return value < 0x8000 and value or -0x10000 + value
end

function Buffer:readUInt16LE(offset)
   return bit.lshift(self[offset + 1], 8) +
   self[offset]
end

function Buffer:readUInt16BE(offset)
   return bit.lshift(self[offset], 8) +
   self[offset + 1]
end

function Buffer:readInt16LE(offset)
   return compliment16(self:readUInt16LE(offset))
end

function Buffer:readInt16BE(offset)
   return compliment16(self:readUInt16BE(offset))
end

function Buffer:readUInt32LE(offset)
   return self[offset + 3] * 0x1000000 +
   bit.lshift(self[offset + 2], 16) +
   bit.lshift(self[offset + 1], 8) +
   self[offset]
end

function Buffer:readUInt32BE(offset)
   return self[offset] * 0x1000000 +
   bit.lshift(self[offset + 1], 16) +
   bit.lshift(self[offset + 2], 8) +
   self[offset + 3]
end

function Buffer:readInt32LE(offset)
   return bit.tobit(self:readUInt32LE(offset))
end

function Buffer:readInt32BE(offset)
   return bit.tobit(self:readUInt32BE(offset))
end

function Buffer:toString(i, j)
   local offset = i and i - 1 or 0
   return ffi.string(self.ctype + offset, (j or self.length) - offset)
end

local buffer = {
}
setmetatable(buffer, {
   __call = Buffer.new,
   __tostring = function()
      return '<Buffer>'
   end
})

return buffer
