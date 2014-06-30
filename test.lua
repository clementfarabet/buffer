local b = require 'buffer'

print('')
print('creating 2 buffers:')

local test = b'test'
local something = b'something'
print(test,something)

print('')
print('concatenating them:')
local new = test .. something
print(new)

print('')
print('to string:')
local s = new:toString()
print(s)

print('')
print('concatenating lots of them:')
local a1 = b'this is some '
local a2 = b'multipart string '
local a3 = b'that can be sti'
local a4 = b'tched together easily...'
local res = b(a1,a2,a3,a4)
print(res)
print(res:toString())

print('')
print('concatenating from table:')
local parts = {a1,a2,a3,a4}
local res = b(parts)
print(res:toString())

print('')
print('slicing:')
print(res:slice(1,5):toString())
print(res:slice(10,14):toString())

print('')
print('slicing doesnt copy:')
res:slice(1,4):copy(b'that')
print(res:toString())

print('')
print('copy from string:')
res:slice(1,4):copy('lala')
print(res:toString())

print('')
print('easier slicing:')
local test = res[{1,10}]
print(test:toString())

print('')
print('easier copy and slice')
res[{1,4}] = b'THIS'
print(res:toString())
res[{1,4}] = 'THAT'
print(res:toString())

print('')
print('cloning')
local new = res:clone()
new[{1,4}] = 'test'
print(res:toString())
print(new:toString())

print('')
print('creating buffer from raw managed memory')
local ffi = require 'ffi'
local mem = ffi.C.malloc(16)
local buf = b(16, mem)
for i = 1,16 do
   buf[i] = i
end
print(buf)
buf = nil -- forcing clearing of buf
collectgarbage()
ffi.C.free(mem)

print('')
print('creating buffer from raw UN-managed memory')
local ffi = require 'ffi'
local mem = ffi.C.malloc(16)
local buf = b(16, mem, true)
for i = 1,16 do
   buf[i] = i
end
print(buf)
buf = nil -- forcing clearing of buf
collectgarbage()

print('')
print('views on tensors and storages')
local t = torch.range(1,10):resize(2,5)
print(t)
local buf = b(t)
print(buf)

local t = torch.range(1,10):resize(2,5):byte()
print(t)
local buf = b(t)
print(buf)

local s = t:storage()
print(s)
local buf = b(s)
print(buf)

print('')
print('converting a buffer back to a tensor')
local t = torch.range(1,10):resize(2,5)
local buf = b(t)
local s = buf:toDoubleStorage()
local tt = buf:toDoubleTensor(2,5)
print(s)
print(tt)
