-- https://rosettacode.org/wiki/Fast_Fourier_transform#Lua
-- operations on complex number
local complex = {__mt={} }
 
function complex.new (r, i) 
  local new={r=r, i=i or 0} 
  setmetatable(new,complex.__mt)
  return new
end
 
function complex.__mt.__add (c1, c2)
  return complex.new(c1.r + c2.r, c1.i + c2.i)
end
 
function complex.__mt.__sub (c1, c2)
  return complex.new(c1.r - c2.r, c1.i - c2.i)
end
 
function complex.__mt.__mul (c1, c2)
  return complex.new(c1.r*c2.r - c1.i*c2.i,
                      c1.r*c2.i + c1.i*c2.r)
end
 
function complex.expi (i)
  return complex.new(math.cos(i),math.sin(i))
end
 
function complex.__mt.__tostring(c)
  return "("..c.r..","..c.i..")"
end
 
 
-- Cooley–Tukey FFT (in-place, divide-and-conquer)
-- Higher memory requirements and redundancy although more intuitive
local function fft(vect)
  local n=#vect
  if n<=1 then return vect end
-- divide  
  local odd,even={},{}
  for i=1,n,2 do
    odd[#odd+1]=vect[i]
    even[#even+1]=vect[i+1]
  end
-- conquer
  fft(even);
  fft(odd);
-- combine
  for k=1,n/2 do
    local t=even[k] * complex.expi(-2*math.pi*(k-1)/n)
    vect[k] = odd[k] + t;
    vect[k+n/2] = odd[k] - t;
  end
  return vect
end
 
local function toComplex(vectr)
  vect={}
  for i,r in ipairs(vectr) do
    vect[i]=complex.new(r)
  end
  return vect
end

return {fft = fft, toComplex = toComplex, complex = complex}
