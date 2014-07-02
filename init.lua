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

pcall(require,'torch') -- optional Torch interface

local Buffer = {
   meta = {}
}

local function sizeof(obj)
   local tp = torch.typename(obj) or 'void'
   local type2size = {
      ['torch.FloatTensor'] = 4,
      ['torch.DoubleTensor'] = 8,
      ['torch.LongTensor'] = 8,
      ['torch.IntTensor'] = 4,
      ['torch.ShortTensor'] = 2,
      ['torch.ByteTensor'] = 1,
      ['torch.CharTensor'] = 1,
      --
      ['torch.FloatStorage'] = 4,
      ['torch.DoubleStorage'] = 8,
      ['torch.LongStorage'] = 8,
      ['torch.IntStorage'] = 4,
      ['torch.ShortStorage'] = 2,
      ['torch.ByteStorage'] = 1,
      ['torch.CharStorage'] = 1,
   }
   return type2size[tp]
end

function Buffer:initialize(...)
   -- Initialize is called up construction:
   local args = {...}
   local arg1,arg2,arg3 = unpack(args)

   -- Buffer(N) : allocates a buffer of given size:
   -- OR:
   -- Buffer(N, ptr [, manage]) : mounts buffer on existing storage (manage memory or not):
   if type(arg1) == "number" then
      local length = arg1
      self.length = length
      local ptr = arg2 -- optional
      local manage = arg3 -- optional: manage memory on raw pointers
      if ptr then
         if manage then
            self.ctype = ffi.gc(ffi.cast("unsigned char*", ptr), ffi.C.free)
            self.created = false
            self.managed = true
         else
            self.ctype = ffi.cast("unsigned char*", ptr)
            self.created = false
            self.managed = false
         end
      else
         local ptr = ffi.C.malloc(length)
         self.ctype = ffi.gc(ffi.cast("unsigned char*", ptr), ffi.C.free)
         self.created = true
         self.managed = true
      end

   -- Buffer(str) : allocates a buffer from the given string:
   elseif type(arg1) == "string" then
      local string = arg1
      self.length = #string
      self.ctype = ffi.cast("unsigned char*", string)
      self.ref = string -- keep ref for GC
      self.created = false 
      self.managed = false

   elseif type(arg1) == "table" then

      -- Buffer(buffer, start, end) : allocates a buffer from another one, with start/end limits:
      if type(arg2) == 'number' then
         local buffer = arg1
         local start = arg2 or 1
         local last = arg3 or buffer.length
         assert(start>=1 and last<=buffer.length, 'incorrect bounds')
         self.length = last - start + 1
         self.ctype = buffer.ctype - 1 + start
         self.ref = buffer -- keep lua ref for GC
         self.created = false 
         self.managed = false

      -- Buffer(buf1, buf2, buf3, buf4, ...) : allocates buffer from list of buffers
      -- (that's a powerful concatenate method)
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
         self.created = true
         self.managed = true

      -- Buffer(buffers) | Buffer({buf1,buf2,...}) : allocates a buffer from a list of buffers (table)
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
         self.created = true
         self.managed = true

      -- Buffer(buffer) : allocates a buffer from another one (strict replica, sharing memory)
      elseif not arg2 and arg1.length then
         local buffer = arg1
         local start = 1
         local last = arg3 or buffer.length
         assert(start>=1 and last<=buffer.length, 'incorrect bounds')
         self.length = last - start + 1
         self.ctype = buffer.ctype - 1 + start
         self.ref = buffer -- keep lua ref for GC
         self.created = false
         self.managed = false
      end

   -- Buffer(tensor)
   elseif torch and torch.typename(arg1) and torch.typename(arg1):find('Tensor') then
      -- Mount buffer on tensor's raw data:
      local tensor = arg1
      assert(tensor:isContiguous(), 'tensor must be contiguous')
      self.ctype = ffi.cast('unsigned char *', tensor:data())
      self.length = tensor:nElement() * sizeof(tensor)
      self.ref = tensor -- keep ref for GC
      self.created = false
      self.managed = false
   
   -- Buffer(storage)
   elseif torch and torch.typename(arg1) and torch.typename(arg1):find('Storage') then
      -- Mount buffer on tensor's raw data:
      local storage = arg1
      self.ctype = ffi.cast('unsigned char *', storage:data())
      self.length = storage:size() * sizeof(storage)
      self.ref = storage -- keep ref for GC
      self.created = false
      self.managed = false

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
   local info = ''
   if self.created then
      info = info .. 'created:1,'
   else
      info = info .. 'created:0,'
   end
   if self.managed then
      info = info .. 'managed:1,'
   else
      info = info .. 'managed:0,'
   end
   if (self.created and self.managed) or self.ref then
      info = info .. 'safe:1'
   else
      info = info .. 'safe:0'
   end
   return "<Buffer [" .. info .. "] " .. table.concat(parts, " ") .. ">"
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

function Buffer:clone()
   local new = Buffer(self.length)
   new:copy(self)
   return new
end

-- not optimized
function Buffer:find(substr, i1)
   local subbuf = Buffer(substr)
   local subindex = 0
   i1 = i1 or 1

   for i = i1,self.length do
      while ((i + subindex) <= self.length) and self[i + subindex] == subbuf[1 + subindex] do
         subindex = subindex + 1
         if subindex == subbuf.length then
            return i
         end
      end
      subindex = 0
   end
end

function Buffer:split(substr)
   local subbuf = Buffer(substr or " ")
   local start = 1
   local subindex = 0

   local subs = {}

   for i = 1,self.length do
      while ((i + subindex) <= self.length) and self[i + subindex] == subbuf[1 + subindex] do
         subindex = subindex + 1
         if subindex == subbuf.length then
            if(start ~= i) then table.insert(subs, self:slice(start, i - 1)) end
            start = i + subindex
            break
         end
      end
      subindex = 0
   end

   -- give the same behavior as stringx split when given a string
   if(start < self.length) then table.insert(subs, self:slice(start, self.length)) end
   return subs

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

function Buffer:pointer(asnumber)
   if asnumber then
      return tonumber(ffi.cast('long', self.ctype)), self.length
   else
      return self.ctype, self.length
   end
end

if torch then
   -- Additional helpers, to spit out storages rom buffers:
   function Buffer:toDoubleStorage()
      local size = self.length / 8
      local raw = ffi.cast('double *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toFloatStorage()
      local size = self.length / 4
      local raw = ffi.cast('float *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toLongStorage()
      local size = self.length / 8
      local raw = ffi.cast('long *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toIntStorage()
      local size = self.length / 4
      local raw = ffi.cast('int *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toShortStorage()
      local size = self.length / 2
      local raw = ffi.cast('short *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toCharStorage()
      local size = self.length
      local raw = ffi.cast('char *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end
   function Buffer:toByteStorage()
      local size = self.length
      local raw = ffi.cast('unsigned char *', self.ctype)
      local pointer = tonumber(ffi.cast('long', raw))
      return torch.DoubleStorage(size, pointer)
   end

   -- Auto gen tensors from storages:
   for k,toStorage in pairs(Buffer) do
      if k:find('Storage') then
         local kk = k:gsub('Storage','Tensor')
         local _,_,tp = k:find('to(.*)Storage')
         tp = tp..'Tensor'
         Buffer[kk] = function(self, ...)
            local storage = toStorage(self)
            local tensor = torch[tp](storage)
            if select(1,...) then
               tensor:resize(...)
            end
            return tensor
         end
      end
   end
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
