module ("murmurhash3", package.seeall)

local ffi = require "ffi"
local ffi_new = ffi.new
local ffi_string = ffi.string

ffi.cdef[[
uint32_t MurmurHash3_x86_32  ( const void * key, int len, uint32_t seed);
void MurmurHash3_x86_128 ( const void * key, int len, uint32_t seed, void * out );
void MurmurHash3_x64_128 ( const void * key, int len, uint32_t seed, void * out );
]]

local mmh = ffi.load(package.cpath .. 'murmurhash3.dll');

function _M.murmurhash3(key, seed)
    return tonumber(mmh.MurmurHash3_x86_32(key, #key, seed or 0))
end;

local out_128bit = ffi_new("unsigned char[?]", 16)

function _M.murmurhash3_128(key, seed)
    seed = seed or 0
    mmh3.MurmurHash3_x64_128(key, #key, seed, out_128bit)
    return ffi_string(out_128bit, 16)
end

function _M.murmurhash3_128_x86(key, seed)
    seed = seed or 0
    mmh3.MurmurHash3_x86_128(key, #key, seed, out_128bit)
    return ffi_string(out_128bit, 16)
end

return _M;
