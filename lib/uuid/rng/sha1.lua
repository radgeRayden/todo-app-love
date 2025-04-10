-- Imported as-is. Minor changes in locals, debug code, etc. No functional changes.


-- -----------------------------------------------------------------------------
-- $Revision: 1.5 $
-- $Date: 2014-09-10 16:54:25 $

-- This module was originally taken from http://cube3d.de/uploads/Main/sha1.txt.

-- -----------------------------------------------------------------------------
-- SHA-1 secure hash computation, and HMAC-SHA1 signature computation,
-- in pure Lua (tested on Lua 5.1)
-- License: MIT
--
-- Usage:
-- local hashAsHex = sha1.hex(message) -- returns a hex string
-- local hashAsData = sha1.bin(message) -- returns raw bytes
--
-- local hmacAsHex = sha1.hmacHex(key, message) -- hex string
-- local hmacAsData = sha1.hmacBin(key, message) -- raw bytes
--
--
-- Pass sha1.hex() a string, and it returns a hash as a 40-character hex string.
-- For example, the call
--
-- local hash = sha1.hex("iNTERFACEWARE")
--
-- puts the 40-character string
--
-- "e76705ffb88a291a0d2f9710a5471936791b4819"
--
-- into the variable 'hash'
--
-- Pass sha1.hmacHex() a key and a message, and it returns the signature as a
-- 40-byte hex string.
--
--
-- The two "bin" versions do the same, but return the 20-byte string of raw
-- data that the 40-byte hex strings represent.
--
-- -----------------------------------------------------------------------------
--
-- Description
-- Due to the lack of bitwise operations in 5.1, this version uses numbers to
-- represents the 32bit words that we combine with binary operations. The basic
-- operations of byte based "xor", "or", "and" are all cached in a combination
-- table (several 64k large tables are built on startup, which
-- consumes some memory and time). The caching can be switched off through
-- setting the local cfg_caching variable to false.
-- For all binary operations, the 32 bit numbers are split into 8 bit values
-- that are combined and then merged again.
--
-- Algorithm: http://www.itl.nist.gov/fipspubs/fip180-1.htm
--
-- -----------------------------------------------------------------------------

local sha1 = {}

-- set this to false if you don't want to build several 64k sized tables when
-- loading this file (takes a while but grants a boost of factor 13)
local cfg_caching = false -- as part of the uuid lib we only use it once to seed, so no caching is needed

-- local storing of global functions (minor speedup)
local floor,modf = math.floor,math.modf
local char,format,rep = string.char,string.format,string.rep

-- merge 4 bytes to an 32 bit word
local function bytes_to_w32 (a,b,c,d) return a*0x1000000+b*0x10000+c*0x100+d end
-- split a 32 bit word into four 8 bit numbers
local function w32_to_bytes (i)
    return floor(i/0x1000000)%0x100,floor(i/0x10000)%0x100,floor(i/0x100)%0x100,i%0x100
end

-- shift the bits of a 32 bit word. Don't use negative values for "bits"
local function w32_rot (bits,a)
    local b2 = 2^(32-bits)
    local a,b = modf(a/b2)
    return a+b*b2*(2^(bits))
end

-- caching function for functions that accept 2 arguments, both of values between
-- 0 and 255. The function to be cached is passed, all values are calculated
-- during loading and a function is returned that returns the cached values (only)
local function cache2arg(fn)
    if not cfg_caching then return fn end
    local lut = {}
    for i=0,0xffff do
      local a,b = floor(i/0x100),i%0x100
      lut[i] = fn(a,b)
    end
    return function (a,b)
      return lut[a*0x100+b]
    end
end

-- splits an 8-bit number into 8 bits, returning all 8 bits as booleans
local function byte_to_bits (b)
    local b = function (n)
      local b = floor(b/n)
      return b%2==1
    end
    return b(1),b(2),b(4),b(8),b(16),b(32),b(64),b(128)
end

-- builds an 8bit number from 8 booleans
local function bits_to_byte (a,b,c,d,e,f,g,h)
    local function n(b,x) return b and x or 0 end
    return n(a,1)+n(b,2)+n(c,4)+n(d,8)+n(e,16)+n(f,32)+n(g,64)+n(h,128)
end

-- -- debug function for visualizing bits in a string
-- local function bits_to_string (a,b,c,d,e,f,g,h)
--     local function x(b) return b and "1" or "0" end
--     return ("%s%s%s%s %s%s%s%s"):format(x(a),x(b),x(c),x(d),x(e),x(f),x(g),x(h))
-- end

-- -- debug function for converting a 8-bit number as bit string
-- local function byte_to_bit_string (b)
--     return bits_to_string(byte_to_bits(b))
-- end

-- -- debug function for converting a 32 bit number as bit string
-- local function w32_to_bit_string(a)
--     if type(a) == "string" then return a end
--     local aa,ab,ac,ad = w32_to_bytes(a)
--     local s = byte_to_bit_string
--     return ("%s %s %s %s"):format(s(aa):reverse(),s(ab):reverse(),s(ac):reverse(),s(ad):reverse()):reverse()
-- end

-- bitwise "and" function for 2 8bit number
local band = cache2arg (function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
          A and a, B and b, C and c, D and d,
          E and e, F and f, G and g, H and h)
    end)

-- bitwise "or" function for 2 8bit numbers
local bor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
          A or a, B or b, C or c, D or d,
          E or e, F or f, G or g, H or h)
    end)

-- bitwise "xor" function for 2 8bit numbers
local bxor = cache2arg(function(a,b)
      local A,B,C,D,E,F,G,H = byte_to_bits(b)
      local a,b,c,d,e,f,g,h = byte_to_bits(a)
      return bits_to_byte(
          A ~= a, B ~= b, C ~= c, D ~= d,
          E ~= e, F ~= f, G ~= g, H ~= h)
    end)

-- bitwise complement for one 8bit number
-- local function bnot(x)
--     return 255-(x % 256)
-- end

-- creates a function to combine to 32bit numbers using an 8bit combination function
local function w32_comb(fn)
    return function (a,b)
      local aa,ab,ac,ad = w32_to_bytes(a)
      local ba,bb,bc,bd = w32_to_bytes(b)
      return bytes_to_w32(fn(aa,ba),fn(ab,bb),fn(ac,bc),fn(ad,bd))
    end
end

-- create functions for and, xor and or, all for 2 32bit numbers
local w32_and = w32_comb(band)
-- local w32_xor = w32_comb(bxor)
local w32_or = w32_comb(bor)

-- xor function that may receive a variable number of arguments
local function w32_xor_n (a,...)
    local aa,ab,ac,ad = w32_to_bytes(a)
    for i=1,select('#',...) do
      local ba,bb,bc,bd = w32_to_bytes(select(i,...))
      aa,ab,ac,ad = bxor(aa,ba),bxor(ab,bb),bxor(ac,bc),bxor(ad,bd)
    end
    return bytes_to_w32(aa,ab,ac,ad)
end

-- combining 3 32bit numbers through binary "or" operation
local function w32_or3 (a,b,c)
    local aa,ab,ac,ad = w32_to_bytes(a)
    local ba,bb,bc,bd = w32_to_bytes(b)
    local ca,cb,cc,cd = w32_to_bytes(c)
    return bytes_to_w32(
      bor(aa,bor(ba,ca)), bor(ab,bor(bb,cb)), bor(ac,bor(bc,cc)), bor(ad,bor(bd,cd))
    )
end

-- binary complement for 32bit numbers
local function w32_not (a)
    return 4294967295-(a % 4294967296)
end

-- adding 2 32bit numbers, cutting off the remainder on 33th bit
local function w32_add (a,b) return (a+b) % 4294967296 end

-- adding n 32bit numbers, cutting off the remainder (again)
local function w32_add_n (a,...)
    for i=1,select('#',...) do
      a = (a+select(i,...)) % 4294967296
    end
    return a
end
-- converting the number to a hexadecimal string
local function w32_to_hexstring (w) return format("%08x",w) end

-- calculating the SHA1 for some text
function sha1.hex(msg)
    local H0,H1,H2,H3,H4 = 0x67452301,0xEFCDAB89,0x98BADCFE,0x10325476,0xC3D2E1F0
    local msg_len_in_bits = #msg * 8

    local first_append = char(0x80) -- append a '1' bit plus seven '0' bits

    local non_zero_message_bytes = #msg +1 +8 -- the +1 is the appended bit 1, the +8 are for the final appended length
    local current_mod = non_zero_message_bytes % 64
    local second_append = current_mod>0 and rep(char(0), 64 - current_mod) or ""

    -- now to append the length as a 64-bit number.
    local B1, R1 = modf(msg_len_in_bits / 0x01000000)
    local B2, R2 = modf( 0x01000000 * R1 / 0x00010000)
    local B3, R3 = modf( 0x00010000 * R2 / 0x00000100)
    local B4 = 0x00000100 * R3

    local L64 = char( 0) .. char( 0) .. char( 0) .. char( 0) -- high 32 bits
    .. char(B1) .. char(B2) .. char(B3) .. char(B4) -- low 32 bits

    msg = msg .. first_append .. second_append .. L64

    assert(#msg % 64 == 0)

    local chunks = #msg / 64

    local W = { }
    local start, A, B, C, D, E, f, K
    local chunk = 0

    while chunk < chunks do
      --
      -- break chunk up into W[0] through W[15]
      --
      start,chunk = chunk * 64 + 1,chunk + 1

      for t = 0, 15 do
          W[t] = bytes_to_w32(msg:byte(start, start + 3))
          start = start + 4
      end

      --
      -- build W[16] through W[79]
      --
      for t = 16, 79 do
          -- For t = 16 to 79 let Wt = S1(Wt-3 XOR Wt-8 XOR Wt-14 XOR Wt-16).
          W[t] = w32_rot(1, w32_xor_n(W[t-3], W[t-8], W[t-14], W[t-16]))
      end

      A,B,C,D,E = H0,H1,H2,H3,H4

      for t = 0, 79 do
          if t <= 19 then
            -- (B AND C) OR ((NOT B) AND D)
            f = w32_or(w32_and(B, C), w32_and(w32_not(B), D))
            K = 0x5A827999
          elseif t <= 39 then
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0x6ED9EBA1
          elseif t <= 59 then
            -- (B AND C) OR (B AND D) OR (C AND D
            f = w32_or3(w32_and(B, C), w32_and(B, D), w32_and(C, D))
            K = 0x8F1BBCDC
          else
            -- B XOR C XOR D
            f = w32_xor_n(B, C, D)
            K = 0xCA62C1D6
          end

          -- TEMP = S5(A) + ft(B,C,D) + E + Wt + Kt;
          A,B,C,D,E = w32_add_n(w32_rot(5, A), f, E, W[t], K),
          A, w32_rot(30, B), C, D
      end
      -- Let H0 = H0 + A, H1 = H1 + B, H2 = H2 + C, H3 = H3 + D, H4 = H4 + E.
      H0,H1,H2,H3,H4 = w32_add(H0, A),w32_add(H1, B),w32_add(H2, C),w32_add(H3, D),w32_add(H4, E)
    end
    local f = w32_to_hexstring
    return f(H0) .. f(H1) .. f(H2) .. f(H3) .. f(H4)
end

local function hex_to_binary(hex)
    return hex:gsub('..', function(hexval)
          return string.char(tonumber(hexval, 16))
      end)
end

function sha1.bin(msg)
    return hex_to_binary(sha1.hex(msg))
end

local xor_with_0x5c = {}
local xor_with_0x36 = {}
-- building the lookuptables ahead of time (instead of littering the source code
-- with precalculated values)
for i=0,0xff do
    xor_with_0x5c[char(i)] = char(bxor(i,0x5c))
    xor_with_0x36[char(i)] = char(bxor(i,0x36))
end

local blocksize = 64 -- 512 bits

function sha1.hmacHex(key, text)
    assert(type(key) == 'string', "key passed to hmacHex should be a string")
    assert(type(text) == 'string', "text passed to hmacHex should be a string")

    if #key > blocksize then
      key = sha1.bin(key)
    end

    local key_xord_with_0x36 = key:gsub('.', xor_with_0x36) .. string.rep(string.char(0x36), blocksize - #key)
    local key_xord_with_0x5c = key:gsub('.', xor_with_0x5c) .. string.rep(string.char(0x5c), blocksize - #key)

    return sha1.hex(key_xord_with_0x5c .. sha1.bin(key_xord_with_0x36 .. text))
end

function sha1.hmacBin(key, text)
    return hex_to_binary(sha1.hmacHex(key, text))
end



-- Uncomment below to run tests
--[[------------ VALIDATION TESTS -- define _G._TEST_SHA1 to execute  ------------------------------------

setmetatable(sha1, {__call = function(_, ...) return sha1.hex(...) end})
local hmac_sha1 = sha1.hmacHex

print(1) assert(sha1 "http://regex.info/blog/"                                  == "7f103bf600de51dfe91062300c14738b32725db5", 1)
print(2) assert(sha1(string.rep("a", 10000))                                    == "a080cbda64850abb7b7f67ee875ba068074ff6fe", 2)
print(3) assert(sha1 "abc"                                                      == "a9993e364706816aba3e25717850c26c9cd0d89d", 3)
print(4) assert(sha1 "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" == "84983e441c3bd26ebaae4aa1f95129e5e54670f1", 4)
print(5) assert(sha1 "The quick brown fox jumps over the lazy dog"              == "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12", 5)
print(6) assert(sha1 "The quick brown fox jumps over the lazy cog"              == "de9f2c7fd25e1b3afad3e85a0bd17d9b100db4b3", 6)

-- a few randomly generated tests

print(7) assert("efb750130b6cc9adf4be219435e575442ec68b7c" == sha1(string.char(136,43,218,202,158,86,64,140,154,173,20,184,170,125,37,54,208,68,171,24,164,89,142,111,148,235,187,181,122):rep(76)), 7)
print(8) assert("432dff9d4023e13194170287103d0377ed182d96" == sha1(string.char(20,174):rep(407)), 8)
print(9) assert("ccba5c47946530726bb86034dbee1dbf0c203e99" == sha1(string.char(20,54,149,252,176,4,96,100,223):rep(753)), 9)
print(10) assert("4d6fea4f8576cd6648ae2d2ee4dc5df0a8309115" == sha1(string.char(118,171,221,33,54,209,223,152,35,67,88,50):rep(985)), 10)
print(11) assert("f560412aabf813d01f15fdc6650489584aabd266" == sha1(string.char(23,85,29,13,146,55,164,14,206,196,109,183,53,92,97,123,242,220,112,15,43,113,22,246,114,29,209,219,190):rep(177)), 11)
print(12) assert("b56795e12f3857b3ba1cbbcedb4d92dd9c419328" == sha1(string.char(21,216):rep(131)), 12)
print(13) assert("54f292ecb7561e8ce27984685b427234c9465095" == sha1(string.char(15,205,12,181,4,114,128,118,219):rep(818)), 13)
print(14) assert("fe265c1b5a848e5f3ada94a7e1bb98a8ce319835" == sha1(string.char(136,165,10,46,167,184,86,255,58,206,237,21,255,15,198,211,145,112,228,146,26,69,92,158,182,165,244,39,152):rep(605)), 14)
print(15) assert("96f186998825075d528646059edadb55fdd96659" == sha1(string.char(100,226,28,248,132,70,221,54,92,181,82,128,191,12,250,244):rep(94)), 15)
print(16) assert("e29c68e4d6ffd3998b2180015be9caee59dd8c8a" == sha1(string.char(247,14,15,163,0,53,50,113,84,121):rep(967)), 16)
print(17) assert("6d2332a82b3600cbc5d2417f944c38be9f1081ae" == sha1(string.char(93,98,119,201,41,27,89,144,25,141,117,26,111,132):rep(632)), 17)
print(18) assert("d84a91da8fb3aa7cd59b99f347113939406ef8eb" == sha1(string.char(28,252,0,4,150,164,91):rep(568)), 18)
print(19) assert("8edf1b92ad5a90ed762def9a873a799b4bda97f9" == sha1(string.char(166,67,113,111,161,253,169,195,158,97,96,150,49,219,103,16,186,184,37,109,228,111):rep(135)), 19)
print(20) assert("d5b2c7019f9ff2f75c38dc040c827ab9d1a42157" == sha1(string.char(38,252,110,224,168,60,2,133,8,153,200,0,199,104,191,62,28,168,73,48,199,217,83):rep(168)), 20)
print(21) assert("5aeb57041bfada3b72e3514f493d7b9f4ca96620" == sha1(string.char(57):rep(738)), 21)
print(22) assert("4548238c8c2124c6398427ed447ae8abbb8ead27" == sha1(string.char(221,131,171):rep(230)), 22)
print(23) assert("ed0960b87a790a24eb2890d8ea8b18043f1a87d5" == sha1(string.char(151,113,144,19,249,148,75,51,164,233,102,232,3,58,81,99,101,255,93,231,147,150,212,216,109,62):rep(110)), 23)
print(24) assert("d7ac6233298783af55901907bb99c13b2afbca99" == sha1(string.char(44,239,189,203,196,79,82,143,99,21,125,75,167,26,108,161,9,193,72):rep(919)), 24)
print(25) assert("43600b41a3c5267e625bbdfde95027429c330c60" == sha1(string.char(122,70,129,24,192,213,205,224,62,79,81,129,22,171):rep(578)), 25)
print(26) assert("5816df09a78e4594c1b02b170aa57333162def38" == sha1(string.char(76,103,48,150,115,161,86,42,247,82,197,213,155,108,215,18,119):rep(480)), 26)
print(27) assert("ef7903b1e811a086a9a5a5142242132e1367ae1d" == sha1(string.char(143,70):rep(65)), 27)
print(28) assert("6e16b2dac71e338a4bd26f182fdd5a2de3c30e6c" == sha1(string.char(130,114,144,219,245,72,205,44,149,68,150,169,243):rep(197)), 28)
print(29) assert("6cc772f978ca5ef257273f046030f84b170f90c9" == sha1(string.char(26,49,141,64,30,61,12):rep(362)), 29)
print(30) assert("54231fc19a04a64fc1aa3dce0882678b04062012" == sha1(string.char(76,252,160,253,253,167,27,179,237,15,219,46,141,255,23,53,184,190,233,125,211,11):rep(741)), 30)
print(31) assert("5511a993b808e572999e508c3ce27d5f12bb4730" == sha1(string.char(197,139,184,188,200,31,171,236,252,147,123,75,7,138,111,167,68,114,73,80,51,233,241,233,91):rep(528)), 31)
print(32) assert("64c4577d4763c95f47ac5d21a292836a34b8b124" == sha1(string.char(177,114,100,216,18,57,2,110,108,60,81,80,253,144,179,47,228,42,105,72,86,18,30,167):rep(901)), 32)
print(33) assert("bb0467117e3b630c2b3d9cdf063a7e6766a3eae1" == sha1(string.char(249,99,174,228,15,211,121,152,203,115,197,198,66,17,196,6,159,170,116):rep(800)), 33)
print(34) assert("1f9c66fca93bc33a071eef7d25cf0b492861e679" == sha1(string.char(205,64,237,65,171,0,176,17,104,6,101,29,128,200,214,24,32,91,115,71,26,11,226,69,141,83,249,129):rep(288)), 34)
print(35) assert("55d228d9bfd522105fe1e1f1b5b09a1e8ee9f782" == sha1(string.char(96,37,252,185,137,194,215,191,190,235,73,224,125,18,146,74,32,82,58,95,49,102,85,57,241,54,55):rep(352)), 35)
print(36) assert("58c3167e666bf3b4062315a84a72172688ad08b1" == sha1(string.char(65,91,96,147,212,18,32,144,138,187,70,26,105,42,71,13,229,137,185,10,86,124,171,204,104,42,2,172):rep(413)), 36)
print(37) assert("f97936ca990d1c11a9967fd12fc717dcd10b8e9e" == sha1(string.char(253,159,59,76,230,153,22,198,15,9,223,3,31):rep(518)), 37)
print(38) assert("5d15229ad10d2276d45c54b83fc0879579c2828e" == sha1(string.char(149,20,176,144,39,216,82,80,56,38,152,49,167,120,222,20,26,51,157,131,160,52,6):rep(895)), 38)
print(39) assert("3757d3e98d46205a6b129e09b0beefaa0e453e64" == sha1(string.char(120,131,113,78,7,19,59,120,210,220,73,118,36,240,64,46,149,3,120,223,80,232,255,212,250,76,109,108,133):rep(724)), 39)
print(40) assert("5e62539caa6c16752739f4f9fd33ca9032fff7e1" == sha1(string.char(216,240,166,165,2,203,2,189,137,219,231,229):rep(61)), 40)
print(41) assert("3ff1c031417e7e9a34ce21be6d26033f66cb72c9" == sha1(string.char(4,178,215,183,17,198,184,253,137,108,178,74,244,126,32):rep(942)), 41)
print(42) assert("8c20831fc3c652e5ce53b9612878e0478ab11ee6" == sha1(string.char(115,157,59,188,221,67,52,151,147,233,84,30,243,250,109,103,101,0,219,13,176,38,21):rep(767)), 42)
print(43) assert("09c7c977cb39893c096449770e1ed75eebb9e5a1" == sha1(string.char(184,131,17,61,201,164,19,25,36,141,173,74,134,132,104,23,104,136,121,232,12,203,115,111,54,114,251,223,61,126):rep(458)), 43)
print(44) assert("9534d690768bc85d2919a059b05561ec94547fc2" == sha1(string.char(49,93,136,112,92,42,117,28,31):rep(187)), 44)
print(45) assert("7dfca0671de92a62de78f63c0921ff087f2ba61d" == sha1(string.char(194,78,252,112,175,6,26,103,4,47,195,99,78,130,40,58,84,175,240,180,255,108,3,42,51,111,35,49,217,160):rep(72)), 45)
print(46) assert("62bf20c51473c6a0f23752e369cabd6c167c9415" == sha1(string.char(28,126,243,196,155,31,158,50):rep(166)), 46)
print(47) assert("2ece95e43aba523cdbf248d07c05f569ecd0bd12" == sha1(string.char(76,230,117,248,231,228):rep(294)), 47)
print(48) assert("722752e863386b737f29a08f23a0ec21c4313519" == sha1(string.char(61,102,1,118):rep(470)), 48)
print(49) assert("a638db01b5af10a828c6e5b73f4ca881974124a0" == sha1(string.char(130,8,4):rep(768)), 49)
print(50) assert("54c7f932548703cc75877195276bc2aa9643cf9b" == sha1(string.char(193,232,122,142,213,243,224,29,201,6,127,45,4,36,92,200,148,111,106,110,221,235,197,51,66,221,123,155,222,186):rep(290)), 50)
print(51) assert("ecfc29397445d85c0f6dd6dc50a1272accba0920" == sha1(string.char(221,76,21,148,12,109,232,113,230,110,96,82,36):rep(196)), 51)
print(52) assert("31d966d9540f77b49598fa22be4b599c3ba307aa" == sha1(string.char(148,237,212,223,44,133,153):rep(53)), 52)
print(53) assert("9f97c8ace98db9f61d173bf2b705404eb2e9e283" == sha1(string.char(190,233,29,208,161,231,248,214,210):rep(451)), 53)
print(54) assert("63449cfce29849d882d9552947ebf82920392aea" == sha1(string.char(216,12,113,137,33,99,200,140,6,222,170,2,115,50,138,134,211,244,176,250,42,95):rep(721)), 54)
print(55) assert("15dc62f4469fb9eae76cd86a84d576905c4bbfe7" == sha1(string.char(50,194,13,88,156,226,39,135,165,204):rep(417)), 55)
print(56) assert("abbc342bcfdb67944466e7086d284500e25aa103" == sha1(string.char(35,39,227,31,206,163,148,163,172,253,98,21,215,43,226,227,130,151,236,177,176,63,30,47,74):rep(960)), 56)
print(57) assert("77ae3a7d3948eaa2c60d6bc165ba2812122f0cce" == sha1(string.char(166,83,82,49,153,89,58,79,131,163,125,18,43,135,120,17,48,94,136):rep(599)), 57)
print(58) assert("d62e1c4395c8657ab1b1c776b924b29a8e009de1" == sha1(string.char(196,199,71,80,10,233,9,229,91,72,73,205,75,77,122,243,219,152):rep(964)), 58)
print(59) assert("15d98d5279651f4a2566eda6eec573812d050ff7" == sha1(string.char(78,70,7,229,21,78,164,158,114,232,100,102,92,18,133,160,56,177,160,49,168,149,13,39,249,214,54,41):rep(618)), 59)
print(60) assert("c3d9bc6535736f09fbb018427c994e58bbcb98f6" == sha1(string.char(129,208,110,40,135,3):rep(618)), 60)
print(61) assert("7dc6b3f309cbe9fa3b2947c2526870a39bf96dc4" == sha1(string.char(126,184,110,39,55,177,108,179,214,200,175,118,125,212,19,147,137,133,89,209,89,189,233,164,71,81,156,215,152):rep(908)), 61)
print(62) assert("b2d4ca3e787a1e475f6608136e89134ae279be57" == sha1(string.char(182,80,145,53,128,194,228,155,53):rep(475)), 62)
print(63) assert("fbe6b9c3a7442806c5b9491642c69f8e56fdd576" == sha1(string.char(9,208,72,179,222,245,140,143,123,111,236,241,40,36,49,68,61,16,169,124,104,42,136,82,172):rep(189)), 63)
print(64) assert("f87d96380201954801004f6b82af1953427dfdcb" == sha1(string.char(153,133,37,2,24,150,93,242,223,68,202,54,118,141,76,35,100,137,13):rep(307)), 64)
print(65) assert("a953e2d054dd77f75337dd9dfa58ec4d3978cfb4" == sha1(string.char(112,215,41,50,221,94):rep(155)), 65)
print(66) assert("e5c3047f9abfdd60f0c386b9a820f11d7028bc70" == sha1(string.char(247,177,124,213,47,175,139,203,81,21,85):rep(766)), 66)
print(67) assert("ee6fe88911a13abfc0006f8809f51b9de7f5920f" == sha1(string.char(81,84,151,242,186,133,39,245,175,79,66,170,246,216,0,88,100,190,137,2,146,58):rep(10)), 67)
print(68) assert("091db84d93bb68349eecf6bfa9378251ecd85500" == sha1(string.char(180,71,122,187):rep(129)), 68)
print(69) assert("d8041c7d65201cc5a77056a5c7eb94a524494754" == sha1(string.char(188,99,87,126,152,214,159,151,234,223,199,247,213,107,63,59,12,146,175,57,79,200,132,202):rep(81)), 69)
print(70) assert("cca1d77faf56f70c82fcb7bc2c0ac9daf553adff" == sha1(string.char(199,1,184,22,113,25,95,87,169,114,130,205,125,159,170,99):rep(865)), 70)
print(71) assert("c009245d9767d4f56464a7b3d6b8ad62eba5ddeb" == sha1(string.char(39,168,16,191,95,82,184,102,242,224,15,108):rep(175)), 71)
print(72) assert("8ce115679600324b58dc8745e38d9bea0a9fb4d6" == sha1(string.char(164,247,250,142,139,131,158,241,27,36,81,239,26,233,105,64,38,249,151,75,142,17,56,217,125,74,132,213,213):rep(426)), 72)
print(73) assert("75f1e55718fd7a3c27792634e70760c6a390d40f" == sha1(string.char(32,145,170,90,188,97,251,159,244,153,21,126,2,67,36,110,31,251,66):rep(659)), 73)
print(74) assert("615722261d6ec8cef4a4e7698200582958193f26" == sha1(string.char(51,24,1,69,81,157,34,185,26,159,231,119):rep(994)), 74)
print(75) assert("4f61d2c1b60d342c51bc47641e0993d42e89c0f9" == sha1(string.char(175,25,99,122,247,217,204,100,0,35,57,65,150,182,51,79,169,99,9,33,113,113,113):rep(211)), 75)
print(76) assert("7d9842e115fc2af17a90a6d85416dbadb663cef3" == sha1(string.char(136,42,39,219,103,95,119,125,205,72,174,15,210,213,23,75,120,56,104,31,63,255,253,100,61,55):rep(668)), 76)
print(77) assert("3eccab72b375de3ba95a9f0fa715ae13cae82c08" == sha1(string.char(190,254,173,227,195,41,49,122,135,57,100):rep(729)), 77)
print(78) assert("7dd68f741731211e0442ce7251e56950e0d05f96" == sha1(string.char(101,155,117,8,143,40,192,100,162,121,142,191,92):rep(250)), 78)
print(79) assert("5e98cdb7f6d7e4e2466f9be23ec20d9177c5ddff" == sha1(string.char(84,67,182,136,89):rep(551)), 79)
print(80) assert("dba1c76e22e2c391bde336c50319fbff2d66c3bb" == sha1(string.char(99,226,185,1,192):rep(702)), 80)
print(81) assert("4b160b8bfe24147b01a247bfdc7a5296b6354e38" == sha1(string.char(144,141,254,1,166,144,129,232,203,31,192,75,145,12):rep(724)), 81)
print(82) assert("27625ad9833144f6b818ef1cf54245dd4897d8aa" == sha1(string.char(31,187,82,156,224,133,116,251,180,165,246,8):rep(661)), 82)
print(83) assert("0ce5e059d22a7ba5e2af9f0c6551d010b08ba197" == sha1(string.char(228):rep(672)), 83)
print(84) assert("290982513a7f67a876c043d3c7819facb9082ea6" == sha1(string.char(150,44,52,144,68,76,207,114,106,153,99,39,219,81,73,140,71,4,228,220,55,244,210,225,221,32):rep(881)), 84)
print(85) assert("14cf924aafceea393a8eb5dd06616c1fe1ccd735" == sha1(string.char(140,194,247,253,117,121,184,216,249,84,41,12,199):rep(738)), 85)
print(86) assert("91e9cc620573db9a692bb0171c5c11b5946ad5c3" == sha1(string.char(48,77,182,152,26,145,231,116,179,95,21,248,120,55,73,66):rep(971)), 86)
print(87) assert("3eb85ec3db474d01acafcbc5ec6e942b3a04a382" == sha1(string.char(68,211):rep(184)), 87)
print(88) assert("f9bd0e886c74d730cb2457c484d30ce6a47f7afa" == sha1(string.char(168,73,19,144,110,93,7,216,40,111,212,192,33,9,136,28,210,175,140,47,125,243,206,157,151,252,26):rep(511)), 88)
print(89) assert("64461476eb8bba70e322e4b83db2beaee5b495d4" == sha1(string.char(33,141):rep(359)), 89)
print(90) assert("761e44ffa4df3b4e28ca22020dee1e0018107d21" == sha1(string.char(254,172,185,30,245,135,14,5,186,42,47,22):rep(715)), 90)
print(91) assert("41161168b99104087bae0f5287b10a15c805596f" == sha1(string.char(79):rep(625)), 91)
print(92) assert("7088f4d88146e6e7784172c2ad1f59ec39fa7768" == sha1(string.char(20,138,80,102,138,182,54,210,38,214,125,123,157,209,215,37):rep(315)), 92)
print(93) assert("2e498e938cb3126ac1291cee8c483a91479900c1" == sha1(string.char(140,197,97,112,205,97,134,190):rep(552)), 93)
print(94) assert("81a2491b727ef2b46fb84e4da2ced84d43587f4e" == sha1(string.char(109,44,17,199,17,107,170,54,113,153,212,161,174):rep(136)), 94)
print(95) assert("0e4f8a07072968fbc4fe32deccbb95f113b32df7" == sha1(string.char(181,247,203,166,34,61,180,48,46,77,98,251,72,210,217,242,135,133,38,12,177,163,249,31,1,162):rep(282)), 95)
print(96) assert("8d15dddd48575a1a0330976b57e2104629afe559" == sha1(string.char(15,60,105,249,158,45,14,208,202,232,255,181,234,217):rep(769)), 96)
print(97) assert("98a9dd7b57418937cbd42f758baac4754d5a4a4b" == sha1(string.char(115,121,91,76,175,110,149,190,56,178,191,157,101,220,190,251,62,41,190,37):rep(879)), 97)
print(98) assert("578487979de082f69e657d165df5031f1fa84030" == sha1(string.char(189,240,198,207,102,142,241,154):rep(684)), 98)
print(99) assert("3e6667b40afb6bcc052654dd64a653ad4b4f9689" == sha1(string.char(85,82,55,80,43,17,57,20,157,10,148,85,154,58,254,254,221,132,53,105,43,234,251,110,111):rep(712)), 99)



--
-- now tests for the HMAC-SHA1 computation
--


assert("31285f3fa3c6a086d030cf0f06b07e7a96b5cbd0" == hmac_sha1("63xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",   "data"), 100)
assert("2d183212abc09247e21282d366eeb14d0bc41fb4" == hmac_sha1("64xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",  "data"), 101)
assert("ff825333e64e696fc13d82c19071fa46dc94a066" == hmac_sha1("65xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx", "data"),  102)


print(103) assert("ecc8b5d3abb5182d3d570a6f060fef2ee6c11a44" == hmac_sha1(string.char(220,58,17,206,77,234,240,187,69,25,179,182,186,38,57,83,120,107,198,148,234,246,46,96,83,28,231,89,3,169,42,62,125,235,137), string.char(1,225,98,83,100,71,237,241,239,170,244,215,3,254,14,24,216,66,69,30,124,126,96,177,241,20,44,3,92,111,243,169,100,119,198,167,146,242,30,124,7,22,251,52,235,95,211,145,56,204,236,37,107,139,17,184,65,207,245,101,241,12,50,149,19,118,208,133,198,33,80,94,87,133,146,202,27,89,201,218,171,206,21,191,43,77,127,30,187,194,166,39,191,208,42,167,77,202,186,225,4,86,218,237,157,117,175,106,63,166,132,136,153,243,187)), 103)

print(104) assert("bd1577a9417d804ee2969636fa9dde838beb967d" == hmac_sha1(string.char(216,76,38,50,235,99,92,110,245,5,134,195,113,7), string.char(144,3,250,84,145,227,206,87,188,42,169,182,106,31,207,205,33,76,52,158,255,49,129,169,9,145,203,225,90,228,163,33,49,99,29,135,60,112,152,5,200,121,35,77,56,116,68,109,190,136,184,248,144,172,47,107,30,16,105,232,146,137,24,81,245,94,28,76,27,82,105,146,252,219,119,164,21,14,74,192,209,208,156,56,172,124,89,218,51,108,44,174,193,161,228,147,219,129,172,210,248,239,22,11,62,128,1,50,98,233,141,224,102,152,44,68,66,46,210,114,138,113,121,90,7,70,125,191,192,222,225,200,217,48,22,10,132,29,236,71,108,140,102,96,51,142,51,220,4)), 104)

print(105) assert("e8ddf90f0c117ee61b33db4df49d7fc31beca7f7" == hmac_sha1(string.char(189,213,184,86,24,160,198,82,138,223,71,149,249,70,183,47,0,106,27,39,85,102,57,190,237,182,2,10,21,253,252,3,68,73,154,75,79,247,28,132,229,50,2,197,204,213,170,213,255,83,100,213,60,67,202,61,137,125,16,215,254,157,106,5), string.char(78,103,249,15,43,214,87,62,52,57,135,84,44,92,142,209,120,139,76,216,33,223,203,96,218,12,6,126,241,195,47,203,196,22,113,138,228,44,122,37,215,166,184,195,91,97,175,153,115,243,37,225,82,250,54,240,20,237,149,183,5,43,142,113,214,130,100,149,83,232,70,106,152,110,25,74,46,60,159,239,193,173,235,146,173,142,110,71,1,97,54,217,52,228,250,42,223,53,105,24,87,98,117,245,101,189,147,238,48,111,68,52,169,78,151,38,21,249)), 105)

print(106) assert("e33c987c31bb45b842868d49e7636bd840a1ffd3" == hmac_sha1(string.char(154,60,91,199,157,45,32,99,248,5,163,234,114,223,234,48,238,82,43,242,52,176,243,5,135,26,141,49,105,120,220,135,192,96,219,152,126,74,58,110,200,56,108,1,68,175,82,235,149,191,67,72,195,46,35,131,237,188,177,223,145,122,26,234,136,93,34,96,71,214,55,27,13,116,235,109,58,83,175,226,59,13,218,93,5,132,43,235), string.char(182,10,154)), 106)

print(107) assert("f6039d217c16afadfcfae7c5e3d1859801a0fe22" == hmac_sha1(string.char(73,120,173,165,190,159,174,100,255,56,217,98,249,11,166,25,66,95,96,99,70,73,223,132,231,147,220,151,79,102,111,98), string.char(134,93,229,103)), 107)

print(108) assert("f6056b19cf6b070e62a0917a46f4b3aefcf6262d" == hmac_sha1(string.char(49,40,62,214,208,180,147,74,162,196,193,9,118,47,100,9,235,94,3,122,226,163,145,175,233,148,251,88,49,216,208,110,13,97,255,189,120,252,223,241,55,210,77,4), string.char(92,185,37,240,36,97,21,132,188,80,103,36,162,245,63,104,19,106,242,44,96,28,197,26,46,168,73,46,76,105,30,167,101,64,67,119,65,140,177,226,223,108,206,60,59,0,182,125,42,200,101,159,109,6,62,85,67,66,88,137,92,234,61,19,22,177,144,127,129,129,195,230,180,149,128,148,45,18,94,163,196,55,70,184,251,3,200,162,16,210,188,61,186,218,173,227,212,8,125,20,138,82,68,170,24,158,90,98,228,166,246,96,74,24,217,93,91,102,246,221,121,115,157,243,45,158,45,90,186,11,127,179,59,72,37,71,148,123,62,150,114,167,248,197,18,251,92,164,158,83,129,58,127,162,181,92,85,121,13,118,250,221,220,150,231,5,230,28,213,25,251,17,71,68,234,173,10,206,111,72,123,205,49,73,62,209,173,46,94,91,151,122)), 108)

print(109) assert("15ddfa1baa0a3723d8aff00aeefa27b5b02ede95" == hmac_sha1(string.char(91,117,129,150,117,169,221,182,193,130,126,206,129,177,184,171,174,224,91,234,60,197,243,158,59,0,122,240,145,106,192,179,96,84,46,239,170,123,120,51,142,101,45,34), string.char(27,71,38,183,232,93,23,174,151,181,121,91,142,138,180,125,75,243,160,220,225,205,205,72,13,162,104,218,47,162,77,23,16,154,31,156,122,67,227,25,190,102,200,57,116,190,131,8,208,76,174,53,204,88,227,239,71,67,208,32,57,72,165,121,80,139,80,29,90,32,229,208,115,169,238,189,206,82,180,68,157,124,119,1,75,27,122,246,197,178,90,225,138,244,73,12,226,104,191,70,53,210,245,250,239,238,3,229,196,22,28,199,122,158,9,33,109,182,109,87,25,159,159,146,217,77,37,25,173,211,38,173,70,252,18,193,7,167,160,135,63,190,149,14,221,143,173,152,184,143,157,245,137,219,74,239,185,40,14,0,29,87,169,84,67,75,255,252,201,131,75,108,43,129,210,193,108,139,60,228,29,36,150,15,86)), 109)

print(110) assert("d7cba04970a79f5d04c772fbe74bcc0951ff9c67" == hmac_sha1(string.char(159,179,206,236,86,25,53,102,163,243,239,139,134,14,243), string.char(106,160,249,31,114,205,9,66,139,182,209,218,31,151,57,132,182,85,218,220,103,15,210,218,101,244,240,227,12,184,127,137,40,127,232,195,234,182,0,214,125,122,141,207,61,244,143,202,159,229,100,76,165,44,226,137,100,61,1,107,132,142,144,158,223,249,151,78,186,194,189,83,45,66,178,41,23,172,195,137,170,216,208,27,149,112,68,188,0)), 110)

print(111) assert("84625a20dc9ada78ec9de910d37734a299f01c5d" == hmac_sha1(string.char(85,239,250,237,210,126,142,84,119,107,100,163,15,179,132,206,112,85,119,101,44,163,240,10,14,69,169,158,170,190,95,66,129,69,218,229), string.char(210,103,131,185,91,224,115,108,129,11,50,16,90,98,64,124,157,177,50,21,30,201,244,101,136,104,149,102,34,166,25,62,1,79,216,4,221,113,168,169,5,151,172,22,166,28,130,137,251,164,220,189,253,45,149,80,247,84,130,208,69,49,120,8,90,154,100,191,121,81,230,207,23,189,7,164,112,123,158,192,224,255,218,200,70,238,211,161,35,251,150,125,24,10,131,220,57,178,196,38,231,196,206,94,118,32,56,197,136,148,145,247,188,64,56,53,195,140,92,202,22,122,229,105,115,14,42,27,107,223,105)), 111)

print(112) assert("c463318ac1878cd770ec93b2710b706296316894" == hmac_sha1(string.char(162,21,153,195,254,135,203,75,152,144,200,187,226,4,248,93,161,180,219,181,99,130,122,28,179,140,152,9,21,115,34,140,162,45,88,4,33,238,179,125,58,23,108,194,158,48,191,40,3,50,81,247,114,241,0,88,147,93,57,178,73,187,11,195,254,171,106,167,245,190,117,160,1,219,200,249,107,233,58,19,122), string.char(246,179,198,163,52,106,45,38,131,22,142,185,149,121,79,211,0,16,102,52,46,176,83,7,32,42,103,184,234,107,180,128,128,130,21,27,236)), 112)

print(113) assert("e2d37df980593b3e52aadb0d99d61114fb2c1182" == hmac_sha1(string.char(43,84,125,158,182,211,26,238,222,247,6,171,184,54,70,44,169,4,74,34,98,71,118,189,138,53,8,164,117,22,76,171,57,255,122,230,110,122,228,22,252,123,174,218,222,77,80,150,159,43,236,137,234,48,122,138,100,137,112), string.char(249,234,226,86,109,2,157,76,229,42,178,223,196,247,42,194,17,17,117,3,45,6,80,202,22,105,44,242,84,25,21,189,5,216,35,200,220,192,110,81,215,145,109,179,48,44,40,35,216,240,48,240,33,210,79,35,64,189,81,15,135,228,83,14,254,32,211,229,158,79,188,230,84,106,78,126,226,106,203,59,67,134,186,52,21,48,2,142,231,116,241,167,177,175,74,188,232,234,56,41,181,118,232,190,184,76,64,109,167,178,123,118,3,50,46,254,253,83,156,116,220,247,69,27,160,167,210,205,79,60,28,253,17,219,32,44,217,223,77,153,229,55,113,75,234,154,247,13,133,49,220,200,241,111,136,205,14,78,222,55,181,250,160,143,224,37,63,227,155,12,39,173,209,45,171,93,93,70,36,129,111,173,183,112,31,231,22,146,129,171,75,128,45)), 113)

print(114) assert("666f9c282cf544c9c28006713a7461c7efbbdbda" == hmac_sha1(string.char(71,33,203,83,173,199,175,245,206,13,237,187,54,61,85,15,153,125,168,223,231,56,46,250,173,192,247,189,45,166,225,223,109,254,15,79,144,188,71,201,70,25,218,205,13,184,204,219,221,82,133,189,144,179,242,125,211,108,100,1,132,110,231,87,107,91,169,101,241,105,30), string.char(98,122,51,157,136,38,149,9,82,27,218,155,76,61,254,154,43,172,59,105,123,45,97,146,191,58,50,153,139,40,37,116)), 114)

print(115) assert("6904a4ce463002b03923c71cdac6c38f57315b63" == hmac_sha1(string.char(15,40,41,76,105,201,153,223,174,12,100,114,234,95,204,95,84,31,26,28,69,85,48,111,40,173,162,6,198,36,252,179,244,9,112,213,64,87,58,186,4,147,229,211,161,30,226,159,75,38,91,89,224,245,156,110,229,50,210), string.char(213,155,72,86,75,185,138,211,199,57,75,9,1,141,184,89,82,180,105,17,193,63,161,202,25,60,16,201,72,179,74,129,73,172,84,39,140,33,25,122,136,143,116,100,100,234,246,108,135,180,85,12,85,151,176,154,172,147,249,242,180,207,126,126,235,203,55,8,251,29,135,134,166,152,80,76,242,15,69,225,199,221,133,118,194,227,9,185,190,125,120,116,182,15,241,209,113,253,241,58,145,106,136,25,60,47,174,209,251,54,159,98,103,88,245,61,108,91,12,245,119,191,232,36)), 115)

print(116) assert("c57c742c772f92cce60cf3a1ddc263b8df0950f3" == hmac_sha1(string.char(193,178,151,175,44,234,140,18,10,183,92,17,232,95,94,198,229,188,188,131,247,236,215,129,243,171,223,83,42,173,88,157,29,46,221,57,80,179,139,80), string.char(214,95,30,179,51,95,183,198,185,9,76,215,255,122,91,103,133,117,42,33,0,145,60,129,129,237,203,59,141,214,108,79,247,244,187,250,157,177,245,72,191,63,176,211)), 116)

print(117) assert("092336f7f1767874098a54d5f27092fbb92b7c94" == hmac_sha1(string.char(208,10,217,108,72,232,56,67,6,179,160,172,29,67,115,171,118,82,124,118,61,111,21,132,209,92,212,166,181,129,43,55,198,96,169,112,86,212,68,214,81,239,122,216,104,73,114,209,60,182,248,118,74,100,26,1,176,3,166,188), string.char(42,4,235,56,198,119,175,244,93,77)), 117)

print(118) assert("c1d58ad2b611c4d9d59e339da7952bdae4a70737" == hmac_sha1(string.char(100,129,37,207,188,116,232,140,204,90,90,93,124,132,140,81,102,156,67,254,228,192,150,161,10,62,143,218,237,111,151,98,78,168,188,87,170,190,35,228,169,228,143,252,213,85,11,124,92,91,18,27,122,141,98,6,77,106,205,209,2,185,249), string.char(58,190,56,255,176,80,220,228,0,251,108,108,220,197,51,131,164,162,60,181,21,54,122,174,31,13,4,84,198,203,105,11,64,230,1,30,218,208,252,219,44,147,2,108,227,66,49,71,21,95,248,93,193,180,165,240,224,226,13,9,208,186,12,118,243,28,113,49,122,192,212,164,43,41,151,183,187,126,115,85,174,40,125,9,54,193,164,95,21,77,200,226,50,115,187,122,34,141,255,224,239,12,132,191,48,102,205,248,128,164,116,48,39,191,98,53,169,230,249,215,231,152,45,27,226,10,143,15,209,157,208,181,15,210,195,5,29,48,29,125,62,59,191,216,170,179,226,110,40,46,32,130,235,48,234,233,17)), 118)

print(119) assert("3de84c915278a7d5e7d5629ec88193fb5bbadd15" == hmac_sha1(string.char(89,175,111,33,154,12,173,230,28,117), string.char(188,233,41,180,142,157,96,76,105,212,92,202,155,167,179,28,12,156,64,73,32,253,253,166,9,240,7,0,248,43,101,135,226,231,173,221,180,43,160,217,6,38,183,186,214,217,137,83,148,148,40,141,217,98,209,12,167,102,95,166,136,231,232,84,59,112,148,201,166,104,135,124,189,85,160,183,143,122,200,190,144,205,25,254,180,188,108,225,171,131,240,185,86,243,192,173,130,50,150,57,242,180,132,193,11,110,247,121,25,24,110,199,156,121,233,149,79,103,15,173,184,143,45,125,164,242,125,10,183,189,189,135,121,59,148,106,77,9,16,123,176,100,142,246,156,180,202,87,43,102,113,123)), 119)

print(120) assert("e8cc5a50f80e7d52edd7ae4ec037414b70798598" == hmac_sha1(string.char(139,243,17,238,11,156,138,122,212,86,201,213,100,167,65,199,92,182,255,36,221,82,192,213,199,162,69,42,222,95,65,170,146,48,39,185,147,18,140,122,168,141), string.char(141,216,25,29,235,207,123,188,85,53,131,180,125,226,97,244,250,138,64,39,30,250,146,101,219,171,213,158,164,172,137,22,136,86,46,77,95,213,66,198,15,24,164,148,29,166,169,195,196,111,122,147,247,215,148,9,129,40,133,178,69,242,171,235,181,83,241,208,237,17,37,30,188,152,47,214,69,229,114,225,75,172,163,184,38,158,230,177,187,124,33,240,238,148,197,235,237,98,33,237,59,205,147,128,108,254,95,5,6,49,10,224,78,139,164,235,220,78,224,15,213,136,198,217,114,156,130,247,167,64,36,10,183,221,193,220,195,80,125,143,248,228,254,6,221,137,170,211,66)), 120)

print(121) assert("80d9a0bc9600e6a0130681158a1787ef6b9c91d6" == hmac_sha1(string.char(152,28,190,131,179,120,137,63,214,85,213,89,116,246,171,92,0,47,44,102,120,206,185,116,71,106,195), string.char(250,9,181,163,46,88,166,238,164,40,207,236,152,104,201,42,14,255,125,57,173,176,230,171,63,6,254,130,140,201,45,152,164,216,171,27,172,105,19,103,128,33,255,93,64,155,55,210,140,2,94,168,168,164,5,218,249,227,221,133,72,112,97,243,140,149,193,80)), 121)

print(122) assert("cb4182de586a30d606a057c948fe33733145790a" == hmac_sha1(string.char(193,229,65,81,159,93,162,173,74,64,195,41,80,189,104,238,119,67,255,63,209,247,146,247,210,208,86,14,102,153,246,175,242,209,42,4,243,138,217,58,206,147,19,163,152,239,154,78,5,1,175,97,251,24,185,10,67,107,174,145,178,121,36,238,108,85,214,162,78,195,107,135,114,76,180,37,99,103,78,232,29,244,11,60,236,112,18,241,39,164,107,18), string.char(222,85,11,36,12,191,252,103,180,161,84,168,21,125,50,76,4,148,195,230,210,114,35,116,225,176,16,64,44,20,17,224,227,243,175,251,204,177,41,223,76,216,228,221,54,226,150,209,145,175,142,137,140,25,196,99,252,175,125,15,39,76,47,127,188,51,88,227,194,171,249,141,12,249,225,199,241,112,153,26,107,204,191,23,241,46,223,143,9,9,46,64,197,209,23,18,208,139,148,45,146,94,80,86,49,12,122,218,14,210,133,164,39,227,102,60,129,6,43)), 122)

print(123) assert("864e291ec69124c3a43976bae4ba1788f181f027" == hmac_sha1(string.char(231,211,73,154,64,125,224,253,200,234,208,210,83,9), string.char(33,248,155,139,159,173,90,40,200,95,96,12,81,103,8,139,211,189,87,75,8,6,36,103,116,204,137,181,81,233,97,171,47,27,143,164,63,3,223,107,80,232,182,154,7,255,190,171,209,115,219,6,34,109,1,254,214,73,2)), 123)

print(124) assert("bee434914e65818f81bd07e4e0bbb58328be3ca1" == hmac_sha1(string.char(222,123,148,175,157,117,104,212,169,13,252,113,231,104,37,8,147,119,92,27,100,132,250,105,63,13,195,90,251,122,185,97,159,68,36,7,75,163,179,3,6,170,164,152,86,30,49,239,201,245,43,220,78,62,154,206,95,24,149,138,138,15,24,68,58,255,99,88,143,192,12), string.char(97,76,73,171,140,99,57,217,56,73,182,189,58,19,177,104,85,85,45,31,170,132,53,51,155,143,70,169,189,5,41,231,34,132,235,228,114,58,100,105,146,27,67,89,32,34,78,133,155,222,88,26,83,198,128,183,19,243,27,186,192,77,184,54,142,57,24)), 124)

print(125) assert("0268f79ef55c3651a66a64a21f47495c5beeb212" == hmac_sha1(string.char(181,166,229,31,47,25,64,129,95,242,221,96,73,42,243,170,15,33,14,198,78,194,235,139,177,112,191,190,52,224,93,95,107,125,245,17,170,161,53,148,19,180,83,154,45,98,76,170,51,178,114,71,34,242,184,75,1,130,199,40,197,88,203,86,169,109,206,67,86,175,201,135,101,76,130,144,248,80,212,14,119,186), string.char(53,208,22,216,93,88,59,64,135,112,49,253,34,11,210,160,117,40,219,36,226,45,207,163,134,133,199,101)), 125)

print(126) assert("bcb2473c745d7dee1ec17207d1d804d401828035" == hmac_sha1(string.char(143,117,182,35), string.char(110,95,240,139,124,96,238,255,165,146,205,18,155,244,252,176,24,19,253,39,33,248,90,95,34,115,70,63,195,91,124,144,243,91,110,80,173,47,46,231,73,228,207,37,183,28,42,144,66,248,178,255,129,52,55,232,1,33,193,185,184,237,8)), 126)

print(127) assert("402ed75be595f59519e3dd52323817a65e9ff95b" == hmac_sha1(string.char(247,77,247,124,27,156,148,227,12,21,17,94,56,14,118,47,140,239,200,249,216,139,7,172,16,211,237,94,62,201,227,42,250,8,179,21,39,85,186,145,147,106,127,67,111,250,163,89,152,115,166,254,8,246,141,238,43,45,194,131,191,202), string.char(138,227,90,40,221,37,181,54,26,20,24,125,19,101,12,120,111,20,104,10,225,140,64,218,8,33,179,95,215,142,203,127,243,231,166,76,234,159,59,160,132,56,215,143,103,75,155,158,56,126,71,252,229,54,34,240,30,133,110,67,146,213,116,73,14,160,186,169,155,196,84,132,171,200,171,56,92,38,136,90,57,155,145,67,190,198,235,112,242,120,150,191,216,41,21,36,205,42,68,145,226,246,178,70,60,157,254,206,70,84,189,36,197,48,208,249,144,223,6,72,17,253,236,106,205,245,30,1,80,121,165,103,12,202,115,227,192,64,42,223,113,200,195,156,120,202,110,131,130,39,64,217,108,23,133,140,56,144,167,77,45,236,145,161,150,229,85,231,203,159,203,85,125,221,226)), 127)

print(128) assert("20231b6abcdd7e5d5e22f83706652acf1ae5255e" == hmac_sha1(string.char(132,122,252,170,107,28,195,210,121,194,245,252,42,64,42,103,220,18,61,68,19,78,182,234,93,130,175,20,4,199,66,91,247,247,87,107,89,205,68,125,19,254,59,47,228,134,200,145,148,78,52,236,51,255,152,231,47,168,213,124,228,34,48), string.char(61,232,69,199,207,49,72,159,37,230,105,207,63,141,245,127,142,77,168,111,126,92,145,26,202,215,116,19,125,81,203,11,86,36,19,218,90,255,4,10,21,185,151,111,188,125,123,2,137,151,171,178,195,199,106,55,42,42,20,164,35,177,237,41,207,24,102,218,213,223,204,186,212,30,59,121,52,34,84,76,142,179,75,6,84,8,72,210,72,177,45,103,218,70,165,69,36,152,50,228,147,192,61,104,209,76,155,147,169,162,151,178,72,109,241,41,76,0,60,251,107,99,92,37,95,215,172,154,172,93,254,65,176,43,99,242,151,78,48,58,35,49,23,174,115,224,227,106,49,30,9)), 128)

print(129) assert("b5a24d7aadc1e8fb71f914e1fa581085a8114b27" == hmac_sha1(string.char(233,21,254,12,70,129,236,10,187,36,119,197,152,242,131,11,10,243,169,217,128,247,196,111,183,109,146,155,92,91,71,83,0,136,109,1,130,143,0,8,6,22,160,153,190,164,199,56,152,229), string.char(152,112,218,132,38,125,94,106,64,9,137,105)), 129)

print(130) assert("7fd9169b441711bef04ea08ed87b1cd8f245aeb2" == hmac_sha1(string.char(108,226,105,159), string.char(103,218,254,85,50,58,111,74,108,60,174,27,113,65,100,217,97,208,125,38,170,151,72,125,82,114,185,58,4,143,39,223,250,168,66,182,37,216,130,111,103,157,59,0,245,222,8,65,240)), 130)

print(131) assert("98038102f8476b28dd11b535b6c1b93eb8089360" == hmac_sha1(string.char(77,121,52,138,71,149,161,87,106,75,232,247,8,148,175,24,23,60,151,104,176,208,148,227,226,191,73,123,164,36,177,235,101,190,128,202,139,116,201,125,61,41,204,187,48,107,63,231,12,137,11,228,93,136,178,243,90), string.char(90,6,232,110,12,66,45,86,141,121,2,6,177,135,64,208,45,178,129,37,253,246,74,48,71,211,243,121,31,209,138,147,185,141,65,185,245,9,137,134,148,123,181,128,204,74,222,150,239,169,179,36,236,104,147,255,251,204,5,191,198,185,153,195,26,112,179,170,232,101,238,143,143)), 131)

print(132) assert("ba43c9b8e98b4b7176a1bb63fcbed5b004dc4fcd" == hmac_sha1(string.char(133,107,178,183,204,2,203,106,242,180,87,58,134), string.char(211,208,255,34,198,99,119,185,171,52,118,94,65,241,45,24,40,6,2,203,126,216,21,51,245,154,92,198,201,220,190,135,182,137,113,68,250,94,126,233,140,94,118,244,244,98,252,97,217,204,239,218,178,240,65,150,246,217,231,142,157,33,113,135,135,214,137,103,211,213,48,132,171,43,96,51,241,45,42,237,53,247,134,102,163,214,96,147,131,74,180,19,7,12,174,60,37,60,78,85,92,186,121,27,234,128,132,64,47,106,127,218,52,30,59,230,85,240,164,54,168,232,131,110,145,125,255,238,145,237,134,196,197,138,105,74,34,134,29,249,222,119,194,104,230)), 132)

print(133) assert("0c1ad0332f0c6c1f61e6cc86f0a343065635ecb3" == hmac_sha1(string.char(230,111,251,74,216,102,12,134,90,44,121,175,56,221,225,235,180,246,56,12,236,119,119,109,97,59,224,121,27,37,72,219,138,193,50,219,193,152,1,229,224,197,233,76,188,62,120,17,63,158,186,198,87,135,34,60,164,139,3,200,20,188,203,110,212,137,91,70,35,255,146,213,216,71,73,143,55,219,54,142,105,83,175,193,32,226,150,51,59), string.char(185,250,11,8,121,214,91,27,1,50,67,204,219,252,212,198,117,234,57,127,214,12,220,104,44,177,225,238,103,138,144,162,28,69,143,108,192,4,160,63,175,185,123,46,151,221,127,145,55,32,85,245,251,178,125,223,107,192,206,207,232,231,190,44,221,173,1,59,12,178,112,22,253,222,14,40,18,141,128,144,196,6,112,206,183,144,215,156,159,79,132,152,170,22,68,106,137,248,12,242,231,98,96,144,148,20,212,30,242,109,36,112,50,51,57,212,181,191,80,73,215,119,244,209,57,108,147,182,67,204,154,48,216,116)), 133)

print(134) assert("466442888b6989fd380f918d0476a16ae26279cf" == hmac_sha1(string.char(250,60,248,215,154,159,2,121), string.char(236,249,8,10,180,146,36,144,83,196,49,166,17,81,51,72,28)), 134)

print(135) assert("f9febfeda402b930ec1b95c1325788305cb9fde8" == hmac_sha1(string.char(124,195,165,216,158,253,119,86,162,36,185,72,162,141,160,225,183,25,54,123,73,61,40,165,101,154,157,200,113,14,117,144,185,64,236,219,3,87,90,49), string.char(73,1,223,35,5,159,39,85,95,170,227,61,14,227,142,222,255,253,152,123,104,35,229,6,195,106,30,59,5,36,2,173,71,161,217,189,47,193,3,216,34,10,25,30,212,255,141,94,25,72,52,58,50,56,180,99,173,155)), 135)

print(136) assert("53fe70b7e825d017ef0bdecbacdda4e8a76cbc6f" == hmac_sha1(string.char(144,144,130,150,207,183,143,100,188,177,90,5,4,95,116,105,252,118,187,251,35,113,251,86,36,234,176,165,55,165,158,4,182,85,62,255,18,146,128,67,221,183,78,71,158,184,140,14,84,44,36,79,244,158,37,1,122,43,103,228,217,253,72,113,228,121,160,29,87,5,158,64,38,253,179,122,187,157,106,99,161,79,97,176,119,86,101,40,142,241,217,85), string.char(12,89,157,112,207,206,171,254,87,106,42,113,70,72,222,239,88,94,14,41,14,175,206,56,219,244,230,40,33,154,107,249,45,70,55,104,151,193,246,133,99,59,244,179,8,145,225,100,146,142,128,74,40,155,99,93,204,253,249,222,64,99,156,121,142,49,166,62,171,223,135,55,212,183,144,218,56,12,211,99,254,58,249,219,197,189,173,141,60,196,241,157,67,151,251,172,49,105,200,88,224,175,9,79,65,40,5,255,222,14,152,149,228,83,154,207,104,132,106,96,40,229,182,120,100,207,223,81,171,141,1,171)), 136)

print(137) assert("81b1df7265954a8aee4e119800169660ff9e75c8" == hmac_sha1(string.char(232,167,4,53,90,111,79,91,163,125,230,202,52,242,160,135,66,211,246,17,131,109,109,235,91), string.char(111,177,251,180,63,13,33,205,231,130,203,167,177,156,87,70,33,148,229,163,158,224,123,37,18,204,185,89,235,2,30,252,229,202,170,157,175,157,208,254,135,190,34,14,42,211,154,243,31,100,71,53,169,76,36)), 137)

print(138) assert("caf986508402b3feb70c5b44d902f4a9428a44d2" == hmac_sha1(string.char(127,2,162,53,6,172,189,169,176,254,107,46,57,207,23,25,182,72,34,228,164,113,12,179,149,45,169,19,3,204,202,10,126,153,130,41,143,200,198,47,215,15,58,124,225,60,171,98,8,211,72,235,211,187,172,37,119,96,55,243,98,198,225,191,79,207,94,215,255,21,101,128,153,233,88,101,57,195,70,194), string.char(97,24,129,203,10,176,242,39,165,95,51,30,187,106,207,160,18,154,16,130,178,80,206,128,148,56,213,55,46,85,76,100,50,131,41,167,130,12,81,161,158,55,181,12,12,38,89,193,136,220,81,114,191,157,20,221,171,245)), 138)

print(139) assert("83bd91a9e8072010f3b54d215c56ada0cd810bb6" == hmac_sha1(string.char(215,33,57,193,51,126,38,114,7,29,93,101,78,152,222,121,42,0,236,169,48,137,202,48,90,249,235,46,44,126,78,251,15,84,200,235,43,108,8,196,210,57,152,86,254), string.char(153,35,68,230,52,95,243,220,32,101,148,76,80,168,187,172,170,254,10,70,31,117,40,131,61,155,200,189,25,198,120,41,181,53,14,175,64,89,126,94,242,61,52,1,188,255,121,254,74,88,19,10,126,225,89,31,21,104,199,82,149,60,110,194,123,236,13,38,7,213,176,182,202,211,178,185,99,8,173,220,168,166,108,208,71,152,174,5,134,167,220,47,74,177,231,90,114,208,168,47,112,74,58,73,94,224,101,64,128,255,186,179,119,159,117,110,2,188,38,73,230,39,50,73,162,22,117,185,182,168,70,252,11,242,243,165,32,104,220,211)), 139)

print(140) assert("c123d92ee67689922dfb3b68a45584e7e5dc5dc3" == hmac_sha1(string.char(167,32,181,181,249,210), string.char(249,7,96,196,48,157,109,129,192,227,82,84,196,167,224,145,61,177,60,74,217,117,199,147,147,54,198,138,5,51,135,112,29,184,49,16,0,240,172,21,214,114,146,57,2,154,205,60,113,32,113,255,165,5,178,15,159)), 140)

print(141) assert("454d9ba00ac4e0e90a2866ba2abefba40dac9aab" == hmac_sha1(string.char(116,2,170,84,236,37), string.char(219,144,86,39,237,166,110,90,213,70)), 141)

print(142) assert("e919cce3908786205511fee0283e1eb41c0c45a1" == hmac_sha1(string.char(180,76,140,201,56,232,48,183,173,36,111,94,208,153,234,255,52,18,121,118,117,77,92,74,241,103,193,164,169,1,60,46,101,73,61,221,26,253,209,124,99,154,177,218,59,238,159,191,0,65,117,78,15,12,92,35,254,40,11,112,112,91,49,248,198,229,161,247,130,170,76,146,8,220,134,96,155,68,50,168,186,135,188,186,36), string.char(26,47,201,201,197,232,196,239,204,197,162,14,53,254,88,75,43,254,11,20,52,61,136,206,162,29,223,55,125,50,200,239,135,51,154,54,78,191,188,0,137,191,149,162,191,103,0,168,52,178,147,251,253,86,98,17,15,202,231,0,122,10,131,25,15,129,48,190,60,205,185,114,193,122,19,47,52,142,124,107,45,174,221,196,18,32,79,12,129,84,40)), 142)

print(143) assert("fa770f6b76984edb0f7fa514a19d3c7ef9c82c51" == hmac_sha1(string.char(70,55,200,82,238,241,84,180,129,122,103,199,170,177), string.char(88,236,14,60,249,2,197,242,76,152,248,241,158,232,113,242,209,93,232,113,147,210,80,180,44,124,186,150,172,177,138,131,117,151,174,231,93,248,244,200,191,169,159,206,232,246,2,121,106,183,107,79,210,73,145,244,254,248,85,217,156,221,238,120,224,176,31,56,246,26,3,186,189,86,41,17,34,8,208,58,46,130,226,139,209,194,3,34,55,213,154,12,250,229,201,122,89,47,177,229,80,165,183,77,178,139,3,241,165,196,239,93,98,101,99,210,99,5,135,132,151,197,4,154,87,130,145,175,243,238,132,0,146,14,6,205,227,78,150,59,191,223,74,145,57,82,30,223,90,205,248,47,195,220,215,167,112,216,20,130,26,88,170,101,26,14,216,62,169,217,1,135,193,147,218)), 143)

print(144) assert("d3418e6e6d0a96f8ea7c511273423651a63590c8" == hmac_sha1(string.char(61,175,211,89,77,91,143,76,18,30,252,16,181,45,211,37,207,204,174,174,60,208,36,85,23,106,141,215,62,8,158,98,209,49,96,143,129,99,11,159,79,116,98,244,51,237,227,250,73,196,36,216,181,157,159,87,248,108,29,22,181,175,72,92,160,127,46,204,202,175,61,108,172,50,225,48,84,167,116,67,183), string.char(174,62,218,81,85,89,4,35,26)), 144)

print(145) assert("f2fbe13b442bff3c09dcdaeaf375cb2f5214f821" == hmac_sha1(string.char(188,80,129,208,85,53,8,122,92,99,56,251,59,108,97,145,1,97,157,181,156,243,30,204,227,88,205,151), string.char(137,30,19,71,50,239,11,212,91,234,79,248,244,118,108,245,251,78,53,136,249,55,210,231,109,207,153,83,10,63,98,225,79,113,124,64,100,16,195,9,136,28,50,215,93,93,153,25,97,77,4,13,46,34,164,59,33,206,62,125,8,79,219,42,155,39,241,96,18)), 145)

print(146) assert("aeacb03e8284a01b93e51e483df58a9492035668" == hmac_sha1(string.char(62,67,97,44,112,68,107,91,105,4,183,154,9,14,164,180,87,140,195,231,62,49,250,154,193,186,219,18,100,156,176,124,223,164,68,64,105,214,144,200,65), string.char(221,20,36,192,59,234,90,174,232,184,75,15,92,229,59,191,36,51,4,190,226,35,237,189,21,100,135,138,171,202,163,227,176,231,72,185,43,197,134,157,44,86,26,42,230,251,2,124,220,245,242,116,77,35,197,154,237,73,117,131,126,242,167,242,8,72,163,171,60,29,77,152,142,69,25,234,195,2,159,49,178,63,48,56,131,143,165,22,142,116,109,11,57,71,101,99,84,204,56,233,173,65,180,228,211,10,197,204,26,70,198,81,217,83,130,70,79,54,93,96,116,32,21,219,193,70,55,84,161,89,47,206,13,167,46,104,205,218)), 146)

print(147) assert("e163c334e08bd3fa537c1ea309ce99cfbcd97930" == hmac_sha1(string.char(238,187,29,13,100,125,10,129,46,251,49,62,207,74,243,25,25,73,196,100,114,64,141,173,143,144,70,13,162,227,33,255,83,58,254,138,23,146,90,86,17,33,152,227,15,100,200,147,81,114,166,234,47,60,70,190,208,28,16,44,71,150,101,197,182,57,143,79,29,135,45,211,194,62,234,28,244,74,56,104,187,94,146,174,190,198,55,143,134,60,186,144,190,100,102,0,171,151), string.char(177,90,20,162,64,145,130,87,137,70,153,237,51,138,248,29,166,134,168,68,133,121,161,26,228,137,145,116,243,224,201,229,61,107,250,198,214,208,72,169,248,155,247,54,163,167,71,248,69,106,105,139,224,138,85,94,31,143,4,215,83,239,21,198,28,1,120,83,91,92,58,150,110,77,111,166,222,236,170,129,2,121,86,66,42,129,146,232,46,248,136,175,130,118,126,205,184,136,6,35,180,174,194,59,89,243,199,38,97,48,80,98,45,111)), 147)

print(148) assert("6a82b3a54ed409f612a934caf96e6c4799286f19" == hmac_sha1(string.char(11,59,108,100,113,56,239,211,2,138,219,101,50,50,111,31,171,212,228,55,89,196,44,158,77,252,212,134,106,7,250,223,219,46,231,87,9,62,213,104,169,49,1,75,3,10,50,238,5,150,47,14,47,45,171,183,40,245,194,249,228,216,85), string.char(97,131,91,189,9,52,88,203,250,245,46,96,7,95,176,61,57,192,91,231,193,32,41,169,96,101,39,240,29,143,24,56,57,177,70,135,225,90,42,192,134,103,239,175,243,246,76,137,14,237,82,215,7,76,246,219,132,50,175,25,164,4,216,65,102,0,114,216,159,80,58,32,4,100,22,35,71,140,49,16,216,182,91,80,181,129,151,55,130,7,77,84,211,111,45,51,192,123,213,192,11,81,138,60,225,21,37,182,180,223,170,163,110,9,47,214,200,249,164,98,215)), 148)

print(149) assert("79caa9946fcf0ccdd882bc409abe77d3470d28f7" == hmac_sha1(string.char(202,142,21,201,45,72,11,211,67,134,42,192,96,255,210,211,252,6,101,131,25,195,101,76,250,161,148,242,30,129,241,85,68,173,236,140,120,80,71,62,55,4,33,104,52,160,143,118,252,72), string.char(100,188,93,165,75,34,224,223,6,130,52,160,83,157,253,27,200,125,117,249,41,203,19,242,4,188,209,213,211,20,162,252,215,238,221,30,219,252,246,110,117,77,89,204,221,246,69,62,160,186,37,144,43,151,39,133,254,134,24,223)), 149)

print(150) assert("bd1e60a3df42e2687746766d7d67d57e262f3c9b" == hmac_sha1(string.char(57,212,172,224,206,230,13,50,80,54,19,87,147,166,245,67,118,37,101,214,207,60,66,29,197,236,146,140,192,15,36,155,108,121,215,211,210,118,22,20,56,245,42,153,150,32,224,201,171,2,238,41,70,140,73,60,215,243,86,20,169,152,220,104,95,215,187), string.char(245,123,43,109,29,108,197,27,55,167,255,177,226,205,111,126,146,75,93,70,180,90,139,218,243,232,221,247,129,77,115,101,144,42,13,249,223,127,200,213,140,113,23,10,149,107,244,86,41,133,147,26,167,85,189,76,176,12,190,52,90,54,78,29,97,204,161,224,59,243,128,64,133,95,192,19,137,220,96,228,97,161,51,21,157,172,127,76,53,38,83,126,178,26,203,206,165,241,101,130,79,122,75,29,205,240,1,68,222,48,101,7,29,6,82,240,133,112)), 150)

print(151) assert("fe249fa66eb1e6228e1e5166d7862d119ffa0dcf" == hmac_sha1(string.char(152,13,170,129,7,65,32,194,85,196,85,12,170,227,139,215,70,137,246,105,100,111,252,221,54,174,90,169,59,11,198,33,110,94,246,195,174,13,212,47,18,94,17,67,68,56,251,213,92,67,243,114,181,166,24,182,238,146,48,196,11,238,91,213,46,184,187,199,15,221,193,36,73,244,30,222,175,132,165,177,162,54,215,130,171,58,26,144,218,62,172,120,188,20,182,242,47,178,120,175), string.char(129,126,32,58,251,104,186,25,18,204,5,240,65,194,32,205,194,18,151,173,185,249,237,55,145,8,41,18,171,28,59,234,62,163,32,173,197,176,206,224,95,176,218,168,183,82,53,172,205,6,223,190,189,16,3,34,212,201,54,152,89,231,194,95,8,238,133,56,139,157,115,35,74,58,21,162,111,36,105,135,151,30,207,33,198,186,122,221,98,36,196,251,27)), 151)

print(152) assert("88aef9bb450b75bf96e8b5fd7831ed0d16d7fe7a" == hmac_sha1(string.char(162,225,9,204,87,95,132,152,211,133,93,120,105,156,131,55,245,224,33,115,182,10,28,49,80,175,241,67,66,52,21,55,174,108,66,100,77,20), string.char(55,61,250,187,157,98,212,245,5,54,170,60,235,228,197,182,230,24,195,215,202,55,56,153,9,94,164,107,67,93,143,1,235,195,133,201,103,57,130,177,71,73,169,80,21,251,130,247,21,61,228,39,166,173,211,203,149,55,11,224,70,52,248,118,112,219,39,188,147,5,203,101,158,134,53,250,103,73,154,249,71,181,53,171,227,26,79,200,145,178,24,80,102,26,90,101,70,143,233,17,150,181,170)), 152)

print(153) assert("a057dd823478540bbe9a6fcdf2d4dcfcac663545" == hmac_sha1(string.char(83,17,204,150,211,96,88,52,225,90,61,59,28,127,135), string.char(49,226,129,162,111,75,221,186,24,219,219,178,226,132,19,126,192,69,124,114,214,31,7,127,194,134,202,147,45,176,215,141,41,94,69,38,199,231,185,223,10,104,108,50,237,20,76,194,33,43,117,117,176,3,117,117,55,68,112,207,74,72,163)), 153)

print(154) assert("b11757ccfafc8feadc4e9402c820f4903f20032b" == hmac_sha1(string.char(34,11,53,219), string.char(225,194,251,106,223,229,212,105,164,172,25,25,224,199,225,172,197,42,167,1,227,165,17,247,75,250,10,208,99,124,254,158,103,74,89,60,78,141,201,44,253,87,248,239,74,86,75,64,249,189,21,170,249,18,139,21,130,226,66,200,231,35,227,147,95,213,133,35,47,236,52,64,122,115,80,170,27,50,182,151,180,106,120,85,103,255,143,27,233,43,217,152,70,82,8,229,103,42,153,38,130,184,108,160,199,69,38,184)), 154)

print(155) assert("bfd0994350b2e1e0d6a1faed059f67f1dd8b361f" == hmac_sha1(string.char(221,156,128,63,215,109,55,123,41,27,110,127,209,144,178,143,120,12,226,47,56,212,131,228,3,40,186,208,233,135,33,206,92,214,153,77,12,220,72,240,176,53,22,37,130,58,180,4,111,124,135,31,192,71,117,87,11,41,231,101,37,164,112,3,55,141,250,131,191,117,90,159,224,244,9,251,154), string.char(35,88,113,69,231,5,150,40,123,13,197,27,49,72,161,1,212,222,252,74,197,170,137,72,231,245,117,236,29,12,36,59,225,103,44,119,136,34,241,17,142,239,46,152,129,163,107,17,165,112,187,15,122,217,67,13,215,157,212,26,103,226,237,161,213,3,152,88,247,236,130,133,84,200,132,191,166,8,96,247,4,142,14,81,179,64,88,202,156,242,181,95,162,19,97,223,51,76,176,218,22,116,24,238,204,128,241,236,204,2,56,86,77,211,4,52,221,82,94,76,9,21,182,112,199,161,29,39,183,120,13,0,124,136,95,182,241,3,73,167,51,237,152,149,84,147,41,42,241,174,12,30,226,245,139,230,127,34,205,41,166,228,242,105,251,4,150,29,106,42,27,239,89,249,230,246,242,149,4,60,240,93,13,166,102,239,81,216,137,196)), 155)

print(156) assert("15c4527be05987a9b5c33b920be4a4402f7cf941" == hmac_sha1(string.char(132,158,227,135,167,32,19,192,144,48,232,68,79,78,135,122,136,140,97,67,34,91,225,48,126,67,77,115,154,189,13,45,8,234,59,233,245,77,34,76,95,78,3,250,179,224,20,25,6,202,214,115,165,230,85,115,250,236,135,34,32,158,196,45,207,61,71,51,93,27,187,232,175,233,147,68,231,110,12,198,233,165,24,209,206,25,16,252,127,72), string.char(210,162,121,23,181,21,75,54,110,47,15,166,133,206,100,217,57,133,228,32,112,208,186,28,140,8,207,74,185,17,128,29,181,172,20,156,64,192,112,8,207,131,53,10,182,147,224,71,218,94,71,86,215,2,133,46,160,27,51,189,38,130,224,120,185,144,253,117,193,24,154,229,247,132,62,103,65,163,106,172,22,5,2,32,129,38,213,118,110,125,156,14,48,240,170,225,158,89,92,190,254,231,51,220,8,174,188,233,226,106,224,99,218,82,64,219,206,75,166,111,25,7,87,248,145,251,109,106,243,241,89,200,85,184,155,183,249,61,70,87,115,182,81,80,155,24,245,123,184,102,214,255,122,83,61,214,88,235,169,28,147,196,247,97,28,82,193,72,71,96,243,176,35,189,236,44,184,52,151,249,186,189,150,184,142,238,88,113,120,68,234,50,136,104,80,145,179,57,6,186)), 156)

print(157) assert("b9f87f5f23583bdd21b1ea18e7e647513b7b0596" == hmac_sha1(string.char(216,79,247,98,215,219,128,232,135,111,179,168,80,76,36,250,224,157,229,209,238,186,212,188,200,52,208,200,210,79,182,186,22,22,37,34,86,107,89,238,168,90,53,30,151,191,89,163,253,24,204,152,118,1,158,25,168,2,123,91,111,39,101,239,247,37,200,51,215,31,146,211,163,136,208), string.char(153,134,211,81,255,219,50,91,67,48,102,63,244,170,129,66,3,151,110,167,142,150,153,95,89,90,23,87,12,85,42,209,197,36,41,189,199,136,196,159,125,53,253,192,135,234,94,34,87,79,143,213,237,149,212,170,231,181,22,72,81,233,151,243,134,71,160,155,121,32,233,251,187,179,139,48,254,206,172,165,202,105,222,31,223,95,203,87,114,52,218,59,187,41,43,135,200,108,102,201,85,199,8,176,249,44,96,104,160,85,149,177,25,88,55,231,85,120,227,6,180,24)), 157)

print(158) assert("0b586895674ab11d3b395c07ddb01151a6e562f5" == hmac_sha1(string.char(26,110,222,147,168,18,74,206,186,238,154,250,229,207,138,175,126,82,236,148,74,180,27,168,159,89,211,34,39,115,227,239,22,199,252,96,100,16,193,117,111,102,75,70,2,114,214,196,29,26,43,189,183,0,194,217,204), string.char(90,15,17,198,223,30,20,138,203,132,6,170,107,40,167,58,194,212,244,49,174,60,209,164,26,87,174,177,41,166,95,173,40,61,47,136,147,239,125,167,146,180,97,167,33,185,5,110,128,36,61,52,140,20,189,16,216,83,164,46,74,16,251,250,72,50,47,5,86,60,56,77,101,64,11,120,124,194,212,199,136,87,157,160,90,172,101,222,235,23,111,11,36,11,68,20,43,251,65,212,206,150,0,50,146,170,183,93,89,142,161,50,110,237,95,191,22,184,62,194,81)), 158)

print(159) assert("38b25a1d9d927ba5e6b294d2aa69c0ab8ab0a0c5" == hmac_sha1(string.char(93,218,103,160,235,71,107,150,18,170,193,9,63,245,77,150,71,242,137,52,243,12,207,183,222,252,20,215,210,194,241,79), string.char(87,97,35,201,134,196,180)), 159)

print(160) assert("a72ce76565c2876e78f86ce9e137a9881328fddc" == hmac_sha1(string.char(48,215,222,182,164,136,31,53,160,28,61,171,220,159,243,154,169,101,191,193,99,28,140,59,60,215,77,170,51,136,50,145,159,135,237,149,83,154,219,223,29,200,85,193,173,201,66,142,100,21,89,144,111,5,24,229,228,154,160,32,210,71,19,63,244,230,61,185,221,158,151,51), string.char(196,237,178,172,24,232,144,251,253,31,8,63,69,58,202,88,120,219,39,34,223,173,196,164,135,93,188,69,126,58,153,37,72,219,50,152,76,235,244,223,205,60,74,12,109,203,134,239,40,181,207,99,118,149,179,84,14,53,189,201,55,110,67,81,116,140,31,247,163,135,53,254,82,230,55,162,255,230,149,144,217,62,164,59,124,59,78,177,115,47,26,169,228,18,167,232,89,161,56,105,127,111,230,93,230,181,222,212,254,85,32,117,140,80,246,117,21,140,221,198,11,196,112,69,122,125,156)), 160)

print(161) assert("cd324faf8204be01296bea85a22d991533fd353e" == hmac_sha1(string.char(25,136,140,2,222,149,164,20,148,15,90,33,106,111,10,252,67,120,57,49,251,171,99,173,114,16,102,240,206,188,231,174,51,124,38,1,217,142,4,15,78,4,5,128,207,82), string.char(84,0,42,233,157,150,105,1,216,32,170,11,100,98,103,220,137,102,32,185,55,211,207,179,252,190,248,117,253,189,196,71,112,32,4,198,87,5,133,125,238,107,210,227,149,206,12,124,31,59,213,66,105,100,240,237,149,232,174,140,127,9,65,204,162,243,100,120,6,229,71,56,140,128,228,102,121,14,43,166,252,230,172,93,96,25,214,174,151,2,50,64,152,164,132,115,109,176,25,144,171,252,231,72)), 161)

print(162) assert("fb6e40ddbf3df49d4b44ccecf9e9bc74567df49e" == hmac_sha1(string.char(31,41,38,118,207,197,83,231,45,187,105,1,246,6,34,16,214,148,97,64,139,27,73,129,71,129,183,182,228,12,74,242,94,43,121,163,188,242,92,43,154,103,20,208,89,213,63,46,81,60,69,217,238,237,97,18), string.char(126,99,64,121,143,219,76,227,119,32,135,246,48,55,214,38,179,255,33,43,32,140,228,44,218,40,187,117,172,131,225,222,72,61,213,132,167,121,190,167,66,213,199,59,212,61,69,242,46,169,89,191,74,0,228,208,46,112,7,81,88,203,95,180,179,75,116,222,115,239,1,132,178,73,139,252,77,1,151,222,108,84,196,161,79,220,80,44,223,44,131,252,58,28,201,3,77,211,33,208,237,47,251,79,134,223,48,8,0,236,139,11,232,186,188,134,249,29,208,154,137,169,218,228,203,254,106,88,35,252,155,111,119,14,147,161,19,60,145,157,120,236,108,122,218,168,105,59,10,44,99,208,86)), 162)

print(163) assert("373f21bf8fe4e855f882cc976ebed31717f4c791" == hmac_sha1(string.char(198,41,45,129,159,48,37,183,170,144,24,223,108,176,68,60,197,245,254,165,24,152,14,25,243,46,6,25,142,99,64,10,145,229,74,232,162,201,72,215,116,26,179,127,107,45,193,232,96,170,168,153,79,47), string.char(79,250,224,177,254,56,111,120,135,79,55,200,199,71,65,132,222,7,106,170,26,179,235,237,47,172,88,28,244,88,137,177,92,178,147,129,147,85,88,157,30,207,235,246,132,98,232,18,201,57,151,90,174,148,126,22,38,118,133,49,83,156,56,195,10,95,180,250,215,220,251,5,131,243,70,2,162,239,197,153,196,28,181,167,26,14,247,86,244,69,190,100,255,158,217,222,58,116,126,245,240,139,255,213,7,28,222,99,12,127,57,2,212,33,136,220,203,251,87,205,213,160,146,162,73,55,112,203,60,243,139,167,45,91,68,62,204,245,206,221,52,253,5,193,69,19,190,131,64,250,12,127,77,212,53,83,102,212,11,215,253,143,111,201)), 163)

print(164) assert("df709285c8a1917aaa6d570bd1d4225ca916b110" == hmac_sha1(string.char(193,124,34,185,160,71,134,56,178,152,165,219,223,89,174,116,11,237), string.char(47,110,24,9,42,187,179,71,114,43,155,129,158,24,130,32,208,3,46,63,16,1,192,210,72,220,200,89,120,80,82,65,199,119,167,86,57,33,105,118,215,60,18,155,17,154,63,59,189,153,236,78,219,89,4,116,208,122,56,65,253,220,57,147,162,242,193,86,45,145,151,61,30,138,105,139,99,89)), 164)

print(165) assert("66be81c24c87feeecfd805872c6cde41cb1dd732" == hmac_sha1(string.char(128,186,31,231,128,48,206,237,59), string.char(56,228,42,58,98,45,202,132,30,78,80,52,36,128,7,55,209,148,181,52,185,220,137,85,111,128,220,109,55,70,185,242,253,155,165,193,240,63,144,253,240,147,18,161,7,46,40,148,201,0,127,1,33,145,180,247,90,206,178,96,62,137,130,99,248,248,227,135,213,21,230,40,88,162,106,240,218,93,226,108,9,121,173,70,255,106,137,222,135,206,104,153,171,1,52,156,166,27,98,7,74,180,206,11,193,129,77,194,86,224,175,79,77,95,134,62,58,252,180,100,191,53,28,59,121,123,146,107,121,249,168,51,204,170,141,26,84,126,38,77,203,11,58,123,155,167,60,176,151,7,39,75,217,254,32,110,79,123,188,133,158,178,132,198,169,23,5,104,124,44,206,191,239,139,152,110,207,42)), 165)

print(166) assert("2d1dd80c3f0fc323ca46ebd0f73c628caa03f88b" == hmac_sha1(string.char(142,87,50,47,146,180,251,164,35,75,53,50,101,115,90,97,66,12), string.char(174,244,41,143,173,27,117,79,53,73,0,189,83,91,13,71,117,85,96,32,199,168,244,72,218,249,207,107,244,1,113,203,160,156,89,244,132,5,4,220,254,112,77,156,158,105,180,98,40,99,198,236,134,209,13,237,93,220,177,70,97,76,178,106,60,60,92,248)), 166)

print(167) assert("444ef9725523ad1aac3d1c20f4954cdf1550d706" == hmac_sha1(string.char(242,169,63,243,133,158,118,205,250,154,66,127,178,170,214,241,96,22,173,138,6,189,90,45,108,70,236,108,93,58,54,204,85,241,194,55,55,184), string.char(30,52,200,164,245,80,75)), 167)

print(168) assert("2170bcfb79e4ab2164287a30ee26535681e34505" == hmac_sha1(string.char(121,111,11,221,34,216,169,179,73,247,222,122,96,168,61,168,201,230,139,158,110,154,74,83,118,254,237,255,99,212,46,218,83,69,185,10,249,78,46,76,206,206,137,133,118,57,241,114,228,54,51,68,71,224,188,188,0,119,173,94,120,1,25,13,237,4,181,170,222,92,106,28,9,111,128,137,228,2,110,4,137,171,219,70), string.char(108,95,232,156,70,235,149,211,52,84,86,25,251,127,119,231,109,144,54,177,96,118,213,3,8,119,95,192,187,221,115,83,67,39,207,82,215,85,156,198,179,246,177,202,115,103,79,97,222,133,113,201,27,92,185,48,227,223,142,96,143,181,175,238,115,112,29,30,126,59,109,252,136,153,28,112,50,138,155,249,223,114,93,107,122,114,163,226,53,219,44,15,172,233,76,98,175,107,246,181,249,112,230,173,152,211,183,120,227,165,187,10,240,94)), 168)

print(169) assert("2bcd1eb6df83aed8bcdfbb36474651f466b1fb22" == hmac_sha1(string.char(178,135,218,237,192,188,60,157,46,65,76,100,66,248,152,23,200,194,67,107,95,127,67,111,149,64,60,158,199,115,159,64,45,192,212,179,46,13,171,104,139,49,185,254,235,183,65,52,140,30,89), string.char(106,32,155,133,229,130,33,200,31,51,242)), 169)

print(170) assert("505910401632c487cd9482ecd6ad16928f21d6f4" == hmac_sha1(string.char(170,34,244,62,31,230,158,102,235,63,93,33,111,253,232,211,132,160,120,156,107), string.char(43,16,194,149,208,76,252,14,73,11,1,172,79,41,132,217,125,96,221,110,199,248,129,122,45,63,77,145,21,98,40,149,154,9,127,27,168,224,204,167,203,74,218,196,236,230,47,29,122,138,65,239,123,120,29,68,236,137,130,95,114,230,185,146,32,69,201,48,251,233,103,61,132,167,245,42,68,249,145,166,137,204,186)), 170)

print(171) assert("6d5f9ae7e8a51f2e615ae3aa8525a41b0bf77282" == hmac_sha1(string.char(166,8,119,187,177,166,23,183,147,37,177,162,102,16,93,204,247,119,248,179,23,89,48,145,188,37,197,176,238,218,173,6,216,229,224,108,58,78,40,199,9,241,191,154,88,124,237,142,228,7,235,102,142,123,4,124,38,46,170,229,116,243,104,106,26,163,94,2,118,71,173,171,104), string.char(41,12,123,197,199,117,129,177,132,149,175,83,168,79,76,58,236,204,99,121,155,207,228,89,236,154,103,137,183,221,208,93,22,222,28,237,140,21,25,149,188,111,6,85,251,31,73,79,239,246,66,46,215,157,184,5,207,4)), 171)

print(172) assert("8c20120cd131e07d9fa46467602d57c9017ca22d" == hmac_sha1(string.char(12,24,169,75,70,190,156,115,112,233,245,216,85,248,62,24,91,179,204,185,0,129,209,137,116,97,242,183,35,151,91,170,41,4,81,12,120,47,78,145,193,50,237,224,62,203,171,169,6,141,126,75,29,40), string.char(47,165,0,107,170,77,37,219,45,135,102,68,144,218,213,74,35,58,246,179,171,3,148,55,216,32,29,102,83,58,29,11,166,75,243,60,21,9,202,179,236,129,212,62,217,203,6,193,18,176,156,198,86,140,135,222,109,48,195,112,167,218,92,76,71,40,128,221,235,43,81,109,198,51,77,122,183,111,173,195,8,249,40,159,212,136,180,215,171,70,60,108,26,185,11,222,67,47,142,179,158,131,135,153,168,251,199,21,44,7,164,68,212,209,54,75,18,200,117,213,16,175,152,29,146,154,151,236,143,173,86,70,224,138,71,33,33,151,122,205,128,223,166,51,149,125,178,225,234,164,180)), 172)

print(173) assert("1ef2a94a2e620a164e07590f006c5a46b722fe7e" == hmac_sha1(string.char(78,109,133,245,198,165,112,63,135,53,124,251,110,183,41,34,153,68,22,253,66,201,9,41,15,99,105,14,252,172,212,39,100,14,128,16,64,47,104,37,33,27,203,120,163,182,52,37,27,224,212,40,134,81,70,29,155,101,246,141,238,41,253,124,222,216,49,49,85,46,51,51,122,39,221,156,104,7,14,52,71,93,31,219), string.char(191,94,78,159,209,12,118,97,214,190,238,108,175,252,192,244,8,104,145,30,236,242,45,49,215,185,251,73,46,101,156,221,136,245,45,240,138,174,187,151,0,122,113,154,195,94,245,186,218,211,203,189,37,251,21,33,225,66,168,152,102,200,245,101,102,217,193,215,194,214,48,131,153,140,75,100,237,240,32,89,113,17,125,177,189,188,212,101,211,212,102,57,251,213,216,14,86,204,198,147,122,97,203,127,100,107,126,107,116,34,220,122,154,130,135,199,9,243,9,194,214)), 173)

print(174) assert("ad924bedf84061c998029fb2f168877f0b3939bb" == hmac_sha1(string.char(174,37,249,22,190,230,152,74,215,14,1,180,201,164,238,160,59,157,213,35,36,43,116,160,158,144,131,30,213,232,29,183,205,87,35,85,252,120,126,5,54,113,176), string.char(25,233,197,224,170,150,207,83,58,255,63,236,20,13,179,143,48,248,212,16,220,143,14,123,207,59,28,124,19)), 174)

print(175) assert("75a6cfbedde0f1b196209a282b25f5f8b9fef3d1" == hmac_sha1(string.char(131,192,35,70,146,214,224,190,220,240,195,81,129,33,207,253,47,230,111,169,187,136,52,244,217,178,143,140,225,154,105,95,112,201,136,90,221,255,44,31,48,178,90,178,218,122,228,165,90,189,107,45,217,249,89,213,136,139,91,187,202,204,26,250,112), string.char(41,13,202,37,1,104,116,166,245,50,221,59,115,68,187,115,80,93,202,147,10,96,209,213,76,103,143,237,217,21,124,152,82,54,147,207,164,43,89,83,118,67,43,179,79,64,127,252,9,26,125,101,80,192,111,224,104,243,45,67,54,251,238,146,154,212,193,181,138,168,231,171,203,62,93,97,46,55,109,253,214,79,60,62,126,183,235,63,121,46,99,3,223,174,223,2,208,78,7,15,161,56,160,59,205,122,138,77,47,250,107,136,65,199,98,86,131,217,96,226,11,166,185,131,231,76,28,83,140,7,146,87,158,20,102,224,86,5,232,96,34,129,172,236,146,1,139,63,252,1,48,196,242,41,145,97,254,174,88,107,169,70,158,165,246,160,4,16,212,109,236)), 175)

print(176) assert("c6f51cc53b0a341dafa4607ee834cffaa8c7c2a2" == hmac_sha1(string.char(85,193,15,80,156,124,171,95,40,75,229,181,147,237,153,83,232,67,210,131,57,69,7,226,226,195,164,46,185,83,120,177,67,77,119,201,9,123,117,111,148,176,12,145,14,80,225,95,71,136,179,94,136,6,78,230,149,135,176,131,19,125,185,48,200,244,111,8,28,170,82,121,242,200,208,145,73,59,234,19,87,61,79,137,245,148,212,94,96,253,227,60,162,170,49,102), string.char(200,235,229,185,225,227,209,209,199,11,112,58,19,202,246,237,94,60,90,176,145,87,191,138,171,88,242,239,21,146,3,92,255,188,99,146,74,134,252,19,201,111,239,76,249,231,71,109,230,240,192,234,253,52,58,173,153,24,131,161,97,222,0,203,177,179,186,160,46,206,73,176,154,39,248,22,66,164,232,120,188,5,73,245,68,8,40,157,155,93,50,207)), 176)

print(177) assert("a07ef6f8799ef46062ffea5a43bb3edd30c1fdde" == hmac_sha1(string.char(81,90,37,124,211,22,19,34,50,56,90,45,17,230,233,38,76,24,250), string.char(142,185,46,191,103,207,110,48,71,10,217,115,193,52,131,87,106,39,9,80,216,15,235,169,30,143,3,7,188,78,34,136,18,200,181,140,22,253,141,59,235,25,59,204,147,80,162,108,237,101,167,249,7,168,24,123,215,220,198,38,133,253,72,168,10,139,84,22,195,36,241,128,70,132,28,242,56,40,159,113,184,187,89,38,198,255,176,88,112,125,68,12,57,207,3,251,72,198,135,48,118,244,199,192,205,164,181,243,40,33,195,204,9,78,108,253,114,211,173,121,245,104,13,116,143,160,241,139,210,162,78,62,69,232,40,248,254,177,6,148,177,168,51,253,177,84,152,29,107,91,186,68,118,30,125,62,196,24,14,87,158,83,39,240,192,79,78,61,133,109,106,98,120,232,144,18,49,96,17,202,208,189,152,171,219,19,41,132,179,219,83,220,201,36,191)), 177)

print(178) assert("63585793821f635534879a8576194f385f4a551a" == hmac_sha1(string.char(78,213,189,105,102,116,246,215), string.char(162,53,102,158,78,125,120,189,186,214,237,16,219,220,44,24,30,62,32,177,104,217,225,27,92,128,95,202,50,177,239,152,151,161,31,152,93,108,29,125,23,63,55,243,160,169,99,102,15,188,196,129,217,239,132,180,177,251,132,173,62,172,21,139,16,137,231,6,243,185,218,60,60,156,166,153,99,149,144,192,151,249,141,165,222,254,4,111,58,46,106,78,160,215,49,128,252,4,114,236,132,108,114,189,143,45,42,84,134,81,47,140,247,146,247,179,63,14,92,136,120,139)), 178)

print(179) assert("95bb1229d26df63839ba4846a41505d48ff98290" == hmac_sha1(string.char(121,190,21,20,39,101,53,249,44,132,19,132,4,114,199,22,32,143,38,33,184,181,66,55,183,240,31,204,225,230,125,186,87,25,90,229,11,55,239,62,101,67,238,1,104,178,191,144,148,105,6,26,127,154,135,247,248,171,41,44,57,83,186,220,42,40,68,153,189,221), string.char(99,150,114,100,37,53,229,202,20,171,246,91,188,188,46,232,70,26,151,35,223,28,97,132,9,242,55,238,98,75,108,91,226,48,236,209,133,92,68,194,241,199,188,86,59,255,230,128,252,193,94,113,134,27,32,50,191,176,159,185,89,209,255,192,9,214,252,63,147,8,92,162,114,72,50,101,136,180,95,39,55,143,137,118,40,14,104,3,149,153,230,135,98,93,72,180,72,86,185,80,107,69,68,20,73)), 179)

print(180) assert("9e7c9a258a32e6b3667549cef7a61f307f49b4b9" == hmac_sha1(string.char(105,200,69,23,156,169,151,107,30,139,196,145,128,108,52,7,181,248,255,83,176,169,152,51,158,236,49,191,65,208,155,204,105,179,148,226,142,194,63,253,217,184,69,11,135,185,203,150,146,57,129,80,87,84,231,168,63,186,149,85,128,236,135,217,246,255,121,70,251,68,139,215,199,143,87,13,196,20,50,92,55,116,34,141,117,89,228,94,63,142,250,182,58,91,68,214), string.char(38,52,86,63,109,91,84,11,33,250,194,192,178,94,37,17,65,111,173,17,37,54,163,168,142,91,191,197,161,229,44,163,163,125,81,204,167,185,244,119,75,28,211,87,159)), 180)

print(181) assert("7fb01c88e7e519265c18e714efd38bc66f831071" == hmac_sha1(string.char(138,214,212,108,83,152,165,123), string.char(148,223,186,162,237,166,230,68,59,78,220,164,231,42,46,211,239,38,39,150,174,50,58,4,0,135,87,123,123,5,33,252,197,6,53,83,27,178,189,228,166,252,91,141,67,44,68,106,222,17,46,84,214,252,110,181,216,132,14,246,209,57,183,155,238,64,215,121,8,169,157,175,182,191,169,94,116,105,91,49,203,30,155,202,39,140,146,6,115,162,112,130,175,86,143,128,126,249,148,185,39,174,63,83,19,76,164,34,228,97,198,250,65,3,168,158,61,130,167,166,144,185,146,184,160,39,189,11,243,125,255,60,217,46)), 181)

print(182) assert("15ab3da2a97592c5f2e22586b4c8a8653411e756" == hmac_sha1(string.char(6,242,91,101,37,118,105,53,170,56,114,144,117,49,53,203,169,216,9,232,9,170,204,129,82,41,210,45,86,176,139,80,152,168,1,154,32,111,89,165,143,205,21,236,105,62,231,106,232,205,7,189,245,52,145,100,78,140,200,183,209,232,196,88,109,175,70,153,150,231,252,7,189,119,97,176,216,201,186,245,24,128,33,57,113,188,184,0,146,248,69,255,77,144,101), string.char(186,246,72,178,189,127,22,42,22,217,81,156,253,142,152,86,42,41,164,77,150,11,208,155,154,185,18,81,156,185,140,224,215,98,1,97,33,194,137,206,144,219,207,210,52,203,198,1,109,182,65,138,122,227,168,207,213,110,206,102,12,181,198,195,133,218,23,187,117,190,56,140,154,239,105,62,96,148,126,187,47,24,139,194,18,211,225,252,195,49,102,138,165,160,90,153,100,140,105,154,242,59,133,226,19,68,125,59,83,140,48,240,226,129,151,79,130,59,96,111,27,73,198)), 182)

print(183) assert("7b06792805f4e8062ee9dfbbaffccd787c6f98e1" == hmac_sha1(string.char(83,132,152,16,245,136,91,241,37,158,80,92,65,223,79,3,189,213,89,253,159,93,194,52,218), string.char(212,242,37,98,229,190,238,23,210,197,147,253,82,105,146,168,198,253,2,160,165,188,165,221,179,112,136,72,149,79,138,70,101,95,210,73,157,14,211,92,27,230,177,84,170,183,15,40,0,92,222,252,166,48,1,139,40,16,186,178,231,109,100,125,253,125,123,94,115,94,150,157,186,230,115,163,194,164,30,131,162,90,28,61,44,248,137,8,246,173,31,177,236,39,8,10,192,148,211,36,215,57)), 183)

print(184) assert("a28fe22ba0845ae3d57273febbbf1d13e8fde928" == hmac_sha1(string.char(149), string.char(11,139,249,120,214,252,67,75)), 184)

print(185) assert("87a9daa85402f6c4b02f1e9fd6edd7e5d178bb88" == hmac_sha1(string.char(114,92,75,169,228,153,182,206,125,139,162,232,77,38,72,129,132,81,11,153,91,92,152,253,10,79,138,142,17,191,161,194,147,213,43,214,39,32,146,46,132,40,77,192,82,54,55,239,50,47), string.char(114,8,110,153,77,155,178,113,203,30,21,41,136,111,176,255,74,214,117,12,189,194,198,37,73,152,196,108,207,188,187,31,227,237,17,1,66,200,73,83,31,61,161,61,31,149,1,152,140,202,163,175,140,136,51,59,121,28,125,192,238,96,192,65,33,177,136,135,173,13,52,101,42,55,189,201,157,244,104,235,148,114,84,154,10,99,153,41,208,213,41,83,193,129,216,46,4,226,81,184,1,249,70,93,183,173,9,29,57,75,209,67,227,49,253,132,129,13,157,55,66,191,136,67,95,108,155,116,17,125,151,217,242,204,110,143,189,201,118)), 185)

print(186) assert("6300b2f6236b83de0c84ff1816d246231a5d3b79" == hmac_sha1(string.char(215,10,19,7,73,236,63,23,34,49,11,240,186,195,32,171,67,85,7,95,190,237,77,216,115,36,230,204,139,95,229,37,201,115,81,96,217,205,49,22,169,32,90,2,90,93,137,247,83,229,39,88,235,175,191,246,80,40,228,114,188,115,14,252,35,40,130,240,20,25,202,80,184,27,227,175,149,64,110,223,25,64,57,189,153,176,143,30,76,2,68), string.char(13,245,250,139,223,128,3,6,189,59,12,139,38,153,215,76,250,198,91,117,242,118,34,26,133,244,143,5,56,182,213,167,144,71,250,40,202,81,22,14,72,201,143,10,177,4,166,75,160,156,100,5,147,138,104,98,9,125,81,202,44,120,241,221,181,0,169,155,96,1,4,205,145,105,150,122,135,231,42,165,179,83,39,122,159,193,139,28,4,201,178,41,168,11,177,61,39,14,196,60,29,131,201,91,46,35,128,63,167,48,132,134,105,224,246,244,81,144,209,123,222,190,167,138,76,194,42,152,23,125,52,156,18,217,101,207,239,63,235,3,3,49,147,172,158,97,179,86,233,85,155,245,206,205,165,195,180,223,20,62,197,143,149,126,152)), 186)

print(187) assert("35fe4e0cf2417a783d5bdbc17bbc0ab77d2699e7" == hmac_sha1(string.char(15,157,117,128,204,42,12,183,229,129,132,234,228,150,235,100,100,77,160,26,154,230,246,138,150,120,252,20,188,138,171,189,208,62,201,58,158,152,167,165,98,249,52,143,7,26,109,227,144,81,213,157,31,155,26,12,206,103,193,29,142,126,205,123,83,111,179,166,31,32,183,183,100,54,51,205,180,186,160,220,176,233,42,94,62,241,88,74,31,24,22,115,179,124,136,206,78,83), string.char(248,157,191,249,76,86,187,243,10,116,1,227,141,21,104,154,167,72,30,245,6,57,40,170,253,15,4,192,237,237,142,141,196,243,231,245,121,219,150,237,212,118,78,25,201,249,174,21,76,98,187,155,82,243,218,142,239,101,235,240,134,70,212,205,136,165,170,71,121,137,44,8,110,14,167,162,233,92,51,191,178,227,85,134,168,222,121,62,35,127,57,92,80,142,91,112,9,248,129,127,236,2,190,165,125,236,188,117,158,241,181,134,54,133,16,64,100,156,59,83,249,105,235,187,160,186,158,173,52,25,129,20,156,209,102,170,209,10,3,233,12,228,205,138,16,140,108,74,75,65,238,155,251,129,73,236,118,93,202,217,46,180,165,27,84,120,61,186,173,148,131,161,187,30,175,21,249,12,245,145,89,93,61,151,254,29,247,51,198,238,111,52,30,254)), 187)

print(188) assert("83c2a380e55ecbc6190b9817bb291a00c36de5e8" == hmac_sha1(string.char(61,128,92,30,94,101,187,67,197,177,98,100,191,221,190,196,86,62,8,238,225,3,93,127,28,126,217,206,56,192,90,9,74,34,43,228,190,162,57,99,170,238,230,196,99,213,31,6,184,11,79,82,100,68,255,40,63), string.char(78,173,248,128,215,226,77,57,233,135,163,11,241,74,59,78,169,219,125,37,182,56,139,89,32,52,80,165,233,52,179,54,216,45,205,209,173,33,12,148,231,66,126,155,191,91,155,174,23,15,14,28,77,186,139,113,48,141,153,177,252,194,23,61,181,189,66,151,45,11,119,74,236,107,206,244,41,117,161,182,233,138,57,196,90,118,28,99,186,150,54,180,105,230,2,41,246,19,80,211,173,102,72,78,82,253,5,183,248,101,173,204,2,145,105,4,160,44,110,211,63,45,46,78)), 188)

print(189) assert("bd59d0dcf812107a613a2d892322f532c16ec210" == hmac_sha1(string.char(161,183,101,160,169,208,82,58,88,198,190,85,53,240,56,6,20,136,86,18,216,63,190), string.char(39,227,142,194,37,34,121,168,239,99,70,39,179,128,26,113,47,95,70,129,255,219,63,233,44,33,19,127,22,24,208,50,19,141,185,19,54,82,147,138,44,69)), 189)

print(190) assert("6aa92cb64b2e390fbf04dc7edfe3af068109ffba" == hmac_sha1(string.char(202,230,55,100,136,80,156,240,98,73,97,72,191,195,185,105,150,97,148,33,167,140,212,100,247,154,5,152,117,24,128,221,150,49,143,86,12,211,161,75,177,75,145,46,112,143,37,181,84,50,230,81), string.char(131,200,0,161,117,217,5,10,64,79,178,147,64,248,35,147,135,103,157,181,194,123,76,13,150,118,204,63,32,203,155,222,227,148,31,28,218,83,245,17,208,200,104,78,85,31,114,194,67,159,184,167,42,199,241,6,182,195,3,79,22,236,124)), 190)

print(191) assert("a42cf08fa6d8ad6ae00251aeed0357dca80645c7" == hmac_sha1(string.char(170,52,245,172,122,225,164,248,23,35,54,243,118,35,165,16,6), string.char(245,115,59,162,179,146,39,213,64,240,80,108,190,127,116,16,154,211,33,171,150,46,77,213,99,88,160,101,236,202,70,26,61,83,79,110,127,74,97,34,18,243,140,34,244,249,225,88,132,102,7,99,220,140,46,111,96,48,93,44,47,186,86,246,244,127,236,150,35,69,111,238,54,24,71,157,254,21,2,194,69,47,190,87,72,235,60,243,40,153,111,55,220,25,91,17,156,195,57,207,107,145,6,82,104,232,209)), 191)

print(192) assert("8dd62dcf68ef2d193005921161341839b8cac487" == hmac_sha1(string.char(136,5,195,241,18,208,11,46,252,182,96,183,164,87,248,13), string.char(78,49,162,9,47,79,26,139,66,194,248,90,171,207,167,43,201,223,102,192,49,145,83,42,1,52,250,116,216,133,224,224,17,143,41,153,65,214,231,109,160,5,31,85,17,186,199,226,214,92,21,194,148,98,68,209,50,74,26,150,97,59,223,8,131,173,145,6,31,126,248,86,226,2,94,15,3,202,239,99,177,237,61,99,14,253,26,246,0,151,2,7,159,40,249,166)), 192)

print(193) assert("eff66e7a69ae7d2a90b2d80c64ce7c41fe560a19" == hmac_sha1(string.char(123,54,89,205,103,116,21,97,164,41,23,224,151,195,22,196,90,52,253,92), string.char(141,12,168,171,49,30,165,57,107,214,157,224,36,163,182,184,103,186,133,22,2,215,52,220,95,205,231,180,221,139,67,184,21,46,172,95,183,220,31,27,227,122,183,196,114,206,132,162,51,164,84,212,172,63,218,236,127,215,218,77,119,105,14,19,164,53,149,11,13,1,29,246,69,200,208,239,154,60,245,31,172,82,158,165,197,250,151,83,12,156,215,201,66,45,238,228,77,125,157,35,235,162,78,220,132,14,137,168,238,127,10,24,41,132,181,43,95,73,33,32,129,149,145,55,80,156,171,73,90,183,166,182,163,154,31,104,14,56,59,102,72,210,121,191,251,239,1,5,76,116,158,89,40,69,220,107,23,168,106,93,92,95,21,91,118,118,71,29,64,142,84,15,153,193,47,214,30,117,236,217)), 193)

print(194) assert("0f1adc518afcca2ed7ad0adaaedd544835ddb76e" == hmac_sha1(string.char(142,36,199,16,52,54,62,146,153,25,162,85,251,247), string.char(110,70,53,237,120,53,50,196,24,82,199,210,156,178,110,124,7,24,229,89,39,1,10,96,74,211,36,79,166,4,33,238,64,220,239,129,48,232,244,172,142,79,154,73,36,107,182,208,191,25,201,19,233,23,60,236,180,76,116,53,232,181,101,62,160,252,213,171,166,113,193,73,75,13,209,63,76,92,95,176,119,0,125,174,42,138,77,23,212,81,180,10,193,118,244,242,163,246,206,150,162,92,20,208,51,71,254,197,11,222,203,153,208,251,243,193,124,141,215,171,55,244,230,78,158,32,223,138,156,43,98,39,191,108,111,6,117,130,195,100,221,233,17,98,180,49,132,139,171,20,180,7,206,35,54,17,48,253,130,185,249,2,52,17,207,73,24,33)), 194)

print(195) assert("5e87f8d9a653312fd7b070a33a5d9e67b28b9a84" == hmac_sha1(string.char(255,237,33,255,4,170,95,90,88,77,217,10,94,118,134,20,33,208,17,136,77,18,169,205,112,36,203,231,67,47,186,91,7,17,29), string.char(97,211,98,53,135,238,42,101,144,12,75,185,119,223,114,81,201,94,21,118,16,152,74,215,56,61,131,151,83,96,83,59,49,199,255,207,153,90,231,39,181,4,59,9,2,150,207,124,209,120,37,236,195,66,189,209,137,9,165,78,172,142,209,243,237,145,204,210,222,153,52,127,39,174,133,17,186,219,87,142,209,212,223,60,249,57,244,251,44,254,73,238,52,99,94,237,189,185,237,1,101,166,220,170,103,209)), 195)

print(196) assert("837c7cc92e0d2c725b1d1d2f02ef787be37896fa" == hmac_sha1(string.char(150,241,64,89,79,72,88,157,113,139,190,43,211,214,202,52,124,91,111,198,47,161,120,17,120,157,112,248,245,154,254,25,233,96,216), string.char(214,251,73,193,181,158,253,28,23,48,186,168,162,26,124,103,22,195,165,63,189,196,162,229,69,1,208,85,249,24,73,101,243,149,68,236,124,147,108,67,37,75,202,143,57,124,71,176,27,216,208,183,164,173,219,170,79,10,198,1,232,35,9,19,70,131,211,60,37,94,146,98,92,31,150,95,89,189,46,38,156,118,171,137,86,87,32,173,77,14,135,233,233,114,162,136,57,113,73,115,134,87,184)), 196)

print(197) assert("64534553f76e55b890101380ad9149d3cacb5b76" == hmac_sha1(string.char(231,24,192,54,17,14,98,122,119,170,71,54,206,207,223,109,164,181,124,186,122,111,122,34,157,24,237,130,207,206,117,76,183,162,174,124,60,60,77,114,139,170,194,143,232,74,160,141,161,171,51,178,162,159,234,208,55), string.char(141,184,241,185,112,45,53,192,72,152,139,145,146,149,145,151,12,140,111,79,158,172,212,175,75,225,127,4,252,104,5,94,105,24,141,183,79,208,240,227,63,126,213,4,13,109,216,244,237,24,196,52,212,245,147,109,18,63,69,107,122,245,101,67,212,232,92,25,135,67,127,247,187,143,224,198,105,38,147,12,238,6,57,53,105,246,0,127,222,69,163,44,11,245,82,220,32,108,33,70,93,177,89,75,192,214,104,236,84,28,221,209,27,12,80,239,111,249,57,39,236,193,17,69,66,180,63,193,242,248,72,22,225,56,198,235,111,102,33,171,159,124,220,143,108,10,71,186,219,213,28,209,145,188,36,70,59,9,235,154,57,12,211,146,6,87,83)), 197)

print(198) assert("b7efbbc21ac1a746e22368e814ef5921056331ac" == hmac_sha1(string.char(137,153,151,252,88,36,165,92,194,50,19,117), string.char(155,113,35,47,22,52,144,77,130,20,178,133,75,207,168,146,132,209,160,7,123,190,117,196,147,212,142,25,182,222,56,249,192,228,6,224,250,221,89,7,176,27,37,49,215,192,74,132,127,101,32,23,34,131,23,74,37,226,208,205,162,242,102)), 198)

print(199) assert("950ad3222f4917f868d09feab237a909fb6d50b7" == hmac_sha1(string.char(78,46,85,132,231,4,243,255,22,45,240,155,151,119,94,213,50,111,10,83,40,204,49,52,17,69,132,44,213,83,54,251,211,159,123,55,17,58,162,170,210,3,35,237,165,181,217,27,7,249,158,22,158,207,77,121,37,63,37,39,204,68,99,158,78,175,73,183,47,99,134,65,74,234,154,33,14,117,126,98,167,242,106,112,145,82), string.char(144,133,184,16,9,8,227,98,190,60,141,255,87,69,63,214,12,67,14,206,32,120,59,232,176,82,32,194,115,52,148,143,126,86,82,101,167,249,17,169,9,105,228)), 199)

--]]------------------------------------------------------------------------------------------
--END

return sha1
