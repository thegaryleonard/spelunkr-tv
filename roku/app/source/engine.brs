' Spelunkr schedule engine — BrightScript port of the scheduling code in spelunkr.tv's web bundle.
' Must stay bit-for-bit equivalent to the JS (test/compare.mjs checks that against the live site's code).
' All 32-bit maths is done on LongIntegers in [0, 2^32) with plain arithmetic, so it does not depend on
' how a given firmware treats Integer overflow, shifts or bitwise operators.

' ------------------------------------------------------------------ constants
function spK() as object
  if m.spK = invalid then
    m.spK = {
      SLIDE_MIN: 2500&, SLIDE_BASE: 1500&, SLIDE_PER_CHAR: 55&
      GAP: 300&, OPEN_MS: 3500&, HOLD_MS: 1000&, TAIL_MS: 1000&
      AD_GAP: 1200000&             ' 20 min
      ROUND: 1209600000&           ' 336 h
      LT: 1000000&
      BREAK_MS: 20000&
      DAY: 86400000&
      HOUR: 3600000&
      TWO32: 4294967296&
      MAX_BUILT: 8
    }
    xt = CreateObject("roArray", 256, false)
    for a = 0 to 15
      for b = 0 to 15
        r = 0 : bit = 1 : x = a : y = b
        for i = 0 to 3
          if (x mod 2) <> (y mod 2) then r = r + bit
          x = x \ 2 : y = y \ 2 : bit = bit * 2
        end for
        xt[a * 16 + b] = r
      end for
    end for
    m.spK.XT = xt
  end if
  return m.spK
end function

' ------------------------------------------------------------------ 32-bit helpers (values are LongInteger 0..2^32-1)
function spU32(x as dynamic) as longinteger
  r& = x
  r& = r& mod 4294967296&
  if r& < 0 then r& = r& + 4294967296&
  return r&
end function

function spS32(u as dynamic) as longinteger
  r& = spU32(u)
  if r& >= 2147483648& then r& = r& - 4294967296&
  return r&
end function

function spXor(a as longinteger, b as longinteger) as longinteger
  if m.spNativeBits = true then
    if a >= 2147483648& then a = a - 4294967296&
    if b >= 2147483648& then b = b - 4294967296&
    sa% = a : sb% = b
    rr% = (sa% or sb%) and (not (sa% and sb%))
    r& = rr%
    if r& < 0 then r& = r& + 4294967296&
    return r&
  end if
  return spXorSlow(a, b)
end function

' decide once whether this firmware does 32-bit bitwise maths the way JS does; keep the slow path otherwise
function spInitBits() as boolean
  m.spNativeBits = true
  r = spRng(12345)
  ok = (spRand(r) = 4207900869& and spRand(r) = 1317490944& and spRand(r) = 2079646450&)
  ok = ok and spXor(4171510507&, 987654321&) = spXorSlow(4171510507&, 987654321&)
  if not ok then m.spNativeBits = false
  return m.spNativeBits
end function

function spXorSlow(a as longinteger, b as longinteger) as longinteger
  xt = spK().XT
  r& = 0 : mul& = 1
  for i = 0 to 7
    ix% = (a mod 16) * 16 + (b mod 16)
    r& = r& + xt[ix%] * mul&
    a = a \ 16 : b = b \ 16 : mul& = mul& * 16
  end for
  return r&
end function

' a | b where b < 64
function spOrSmall(a as longinteger, b as integer) as longinteger
  lo% = a mod 64
  if m.spNativeBits = true then return a - lo% + (lo% or b)
  lo = lo%
  r = 0 : bit = 1 : x = lo : y = b
  for i = 0 to 5
    if (x mod 2) = 1 or (y mod 2) = 1 then r = r + bit
    x = x \ 2 : y = y \ 2 : bit = bit * 2
  end for
  return a - lo + r
end function

function spShr(a as longinteger, n as integer) as longinteger
  d& = 1
  for i = 1 to n : d& = d& * 2 : end for
  return a \ d&
end function

function spImul(a as longinteger, b as longinteger) as longinteger
  al& = a mod 65536
  ah& = a \ 65536
  r& = al& * b + ((ah& * b) mod 65536) * 65536
  return r& mod 4294967296&
end function

' JS: function Fn(e){let t=0;for(...)t=(t<<5)-t+e.charCodeAt(n)|0;return t}  -> returns signed 32
function spHash(s as string) as longinteger
  ba = m.spBA
  if ba = invalid then
    ba = CreateObject("roByteArray")
    m.spBA = ba
  end if
  ba.FromAsciiString(s)
  n = ba.Count()
  if n = Len(s) then
    ' pure ASCII: byte = code unit
    t& = 0
    for i = 0 to n - 1
      t& = (t& * 31 + ba[i]) mod 4294967296&
    end for
    return spS32(t&)
  end if
  t& = 0
  n = Len(s)
  for i = 1 to n
    c& = Asc(Mid(s, i, 1))
    if c& > 65535 then
      c& = c& - 65536
      t& = (t& * 31 + 55296 + (c& \ 1024)) mod 4294967296&
      t& = (t& * 31 + 56320 + (c& mod 1024)) mod 4294967296&
    else
      if c& < 0 then c& = c& + 65536
      t& = (t& * 31 + c&) mod 4294967296&
    end if
  end for
  return spS32(t&)
end function

' JS string .length (UTF-16 code units), from the UTF-8 bytes so it doesn't depend on Len() semantics
function spJsLen(s as dynamic) as integer
  if s = invalid then return 0
  s = s.ToStr()
  if m.spLenCache = invalid then
    m.spLenCache = {}
    m.spLenCache.SetModeCaseSensitive()
  end if
  c = m.spLenCache[s]
  if c <> invalid then return c
  ba = CreateObject("roByteArray")
  ba.FromAsciiString(s)
  r = 0
  for i = 0 to ba.Count() - 1
    v = ba[i]
    if v < 128 or v >= 192 then r = r + 1      ' start of a code point
    if v >= 240 then r = r + 1                 ' 4-byte sequence = surrogate pair in JS
  end for
  m.spLenCache[s] = r
  return r
end function

' mulberry32 — JS Wr(seed). Returns {t}; spRand(r) returns the next value as u32 (value/2^32 is the JS float)
function spRng(seed as longinteger) as object
  return { t: spU32(seed) }
end function

function spRand(r as object) as longinteger
  t& = (r.t + 1831565813&) mod 4294967296&
  r.t = t&
  o1& = t&
  if (t& mod 2) = 0 then o1& = t& + 1
  n& = spImul(spXor(t&, t& \ 32768&), o1&)
  n& = spXor(n&, (n& + spImul(spXor(n&, n& \ 128&), spOrSmall(n&, 61))) mod 4294967296&)
  return spXor(n&, n& \ 16384&)
end function

' Math.floor(rand() * n)
function spRandIdx(r as object, n as dynamic) as integer
  n& = n
  v% = (spRand(r) * n&) \ 4294967296&
  return v%
end function

' ------------------------------------------------------------------ small generic helpers
function spIsNum(x as dynamic) as boolean
  t = type(x)
  return t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" or t = "Float" or t = "roFloat" or t = "Double" or t = "roDouble" or t = "roIntrinsicDouble"
end function

function spIsInt(x as dynamic) as boolean
  t = type(x)
  if t = "Integer" or t = "roInt" or t = "roInteger" or t = "LongInteger" or t = "roLongInteger" then return true
  if spIsNum(x) then
    d# = x
    return d# = spFloorD(d#)
  end if
  return false
end function

' floor() of a Double that may not fit in 32 bits
function spFloorD(x as double) as longinteger
  hi& = Int(x / 1048576#)
  rest# = x - hi& * 1048576#
  return hi& * 1048576& + Int(rest#)
end function

function spIsStr(x as dynamic) as boolean
  t = type(x)
  return t = "String" or t = "roString"
end function

function spArr(x as dynamic) as object
  if type(x) = "roArray" then return x
  return []
end function

function spIsTrue(x as dynamic) as boolean
  t = type(x)
  if t = "Boolean" or t = "roBoolean" then return x
  return false
end function

function spIsFalse(x as dynamic) as boolean
  t = type(x)
  if t = "Boolean" or t = "roBoolean" then return not x
  return false
end function

function spStr(x as dynamic) as string
  if x = invalid then return "null"
  if spIsStr(x) then return x
  if spIsNum(x) then
    if spIsInt(x) then
      l& = x
      return l&.ToStr()
    end if
    return Str(x).Trim()
  end if
  return x.ToStr()
end function

function spLong(x as dynamic) as longinteger
  if x = invalid then return 0
  if spIsInt(x) then
    l& = x
    return l&
  end if
  if spIsNum(x) then return spFloorD(x)
  return 0
end function

' parseInt(year, 10) -> invalid if no leading digits
function spYear(x as dynamic) as dynamic
  if x = invalid then return invalid
  if spIsNum(x) then return spLong(x)
  s = x.ToStr().Trim()
  sign = 1 : i = 1
  if Left(s, 1) = "-" then sign = -1 : i = 2
  if Left(s, 1) = "+" then i = 2
  r& = 0 : gotDigit = false
  while i <= Len(s)
    c = Asc(Mid(s, i, 1))
    if c < 48 or c > 57 then exit while
    r& = r& * 10 + (c - 48) : gotDigit = true : i = i + 1
  end while
  if not gotDigit then return invalid
  return r& * sign
end function

' JS a < b on strings (code-unit order; identical to code-point order outside surrogates)
function spStrLess(a as string, b as string) as boolean
  return a < b
end function

' ------------------------------------------------------------------ bump timing
function spSlideMs(text as dynamic) as longinteger
  k = spK()
  v& = k.SLIDE_BASE + spJsLen(text) * k.SLIDE_PER_CHAR
  if v& < k.SLIDE_MIN then v& = k.SLIDE_MIN
  return v&
end function

function spSlidesMs(slides as dynamic) as longinteger
  t& = 0
  if slides = invalid then return 0
  for each s in spArr(slides) : t& = t& + spSlideMs(s.text) : end for
  return t&
end function

function spPairMs(a as object, b as object) as longinteger
  k = spK()
  return k.OPEN_MS + spSlidesMs(a.slides) + k.HOLD_MS + k.TAIL_MS + k.GAP + spSlidesMs(b.slides) + k.HOLD_MS + k.TAIL_MS
end function

' ------------------------------------------------------------------ seasonal bumps
function spMsToDate(ms as longinteger) as object
  d = CreateObject("roDateTime")
  d.FromSeconds(ms \ 1000)
  return d
end function

function spIsoMs(s as string) as longinteger
  if m.spIsoCache = invalid then m.spIsoCache = {}
  if m.spIsoCache.DoesExist(s) then return m.spIsoCache[s]
  d = CreateObject("roDateTime")
  d.FromISO8601String(s)
  m.spIsoCache[s] = d.AsSeconds() * 1000&
  return m.spIsoCache[s]
end function

function spMonthDay(t as longinteger) as integer
  dayKey& = t \ 86400000&
  if m.spMdKey <> invalid then
    if m.spMdKey = dayKey& then return m.spMdVal
  end if
  d = spMsToDate(t)
  m.spMdKey = dayKey&
  m.spMdVal = d.GetMonth() * 100 + d.GetDayOfMonth()
  return m.spMdVal
end function

function spIsoMsUnused(s as string) as longinteger
  d = CreateObject("roDateTime")
  d.FromISO8601String(s)
  return d.AsSeconds() * 1000&
end function

function spInRange(range as object, t as longinteger) as boolean
  n = range[0] : r = range[1]
  if spIsIsoDate(n) then
    return t >= spIsoMs(n + "T00:00:00Z") and t <= spIsoMs(r + "T23:59:59Z") + 999
  end if
  o = spMonthDay(t)
  a = n.Split("-") : b = r.Split("-")
  c = Val(a[0]) * 100 + Val(a[1])
  l = Val(b[0]) * 100 + Val(b[1])
  if c <= l then return o >= c and o <= l
  return o >= c or o <= l
end function

function spIsIsoDate(n as string) as boolean
  if Len(n) < 5 or Mid(n, 5, 1) <> "-" then return false
  for i = 1 to 4
    c = Asc(Mid(n, i, 1))
    if c < 48 or c > 57 then return false
  end for
  return true
end function

function spBumpSets(list as object) as object
  live = [] : yr = [] : seas = []
  for each b in list
    if not spIsFalse(b.active) then
      live.Push(b)
      if b.date_range = invalid then yr.Push(b) else seas.Push(b)
    end if
  end for
  return { all: list, live: live, yearRound: yr, seasonal: seas }
end function

function spEligible(sets as object, t as longinteger) as object
  ' membership in every date range only changes at UTC midnight -> cache per day
  dayKey& = t \ 86400000&
  if t < 0 and (t mod 86400000&) <> 0 then dayKey& = dayKey& - 1
  if sets.cacheDay <> invalid then
    if sets.cacheDay = dayKey& then return sets.cacheList
  end if
  found = false
  keyParts = []
  for each b in sets.seasonal
    if spInRange(b.date_range, t) then
      found = true
      keyParts.Push(spStr(b.id))
    end if
  end for
  if not found then
    res = sets.yearRound
  else
    res = []
    for each b in sets.live
      if b.date_range = invalid then
        res.Push(b)
      else if spInRange(b.date_range, t) then
        res.Push(b)
      end if
    end for
  end if
  sets.cacheDay = dayKey&
  sets.cacheList = res
  sets.cacheKey = keyParts.Join("|")
  return res
end function

' JS Mu(list, breakIndex, channelId, seed, atMs)
function spPickBump(sets as object, idx as longinteger, who as string, seed as string, at as longinteger) as dynamic
  if sets = invalid or sets.all.Count() = 0 then return invalid
  i = spEligible(sets, at)
  if i.Count() = 0 then return invalid
  r = spRng(spHash(who + "-break-" + idx.ToStr() + "-" + seed))
  return i[spRandIdx(r, i.Count())]
end function

' JS zg(list, recent, seed) — shuffle that keeps recently shown bumps out of the front half
function spDeckShuffle(e as object, recent as object, seed as longinteger) as object
  r = spRng(seed)
  s = []
  for each x in e : s.Push(x) : end for
  l = s.Count() - 1
  while l > 0
    u = spRandIdx(r, l + 1)
    tmp = s[l] : s[l] = s[u] : s[u] = tmp
    l = l - 1
  end while
  half = s.Count() \ 2
  o = {} : o.SetModeCaseSensitive()
  osize = 0
  lim = half
  if recent.Count() < lim then lim = recent.Count()
  l = lim
  while l >= 1
    key = recent[recent.Count() - l]._i.ToStr()
    if not o.DoesExist(key) then osize = osize + 1
    o[key] = half + 1 - l
    l = l - 1
  end while
  if osize = 0 then return s
  for l = 1 to lim
    u = recent[recent.Count() - l]
    cu = spDeckRank(o, u)
    d = -1
    for p = 0 to s.Count() - 1
      if s[p]._i = u._i then d = p : exit for
    end for
    if d >= 0 and d < cu then
      f = []
      for p = cu to s.Count() - 1
        if spDeckRank(o, s[p]) <= d then f.Push(p)
      end for
      if f.Count() > 0 then
        h = f[spRandIdx(r, f.Count())]
        tmp = s[d] : s[d] = s[h] : s[h] = tmp
      end if
    end if
  end for
  return s
end function

function spDeckRank(o as object, b as object) as integer
  v = o[b._i.ToStr()]
  if v = invalid then return 0
  return v
end function

function spDeckFrom(carry as dynamic) as object
  if carry = invalid then return { order: [], ix: 0, key: invalid, recent: [], rounds: 0 }
  rec = []
  for each x in carry.recent : rec.Push(x) : end for
  return { order: carry.order, ix: carry.ix, key: carry.key, recent: rec, rounds: 0 }
end function

' JS Yg(deck, bumps, channelId, seed, atMs)
function spDeckNext(e as object, sets as object, who as string, seed as string, at as longinteger) as dynamic
  if sets = invalid or sets.all.Count() = 0 then return invalid
  i = spEligible(sets, at)
  if i.Count() = 0 then return invalid
  c = sets.cacheKey   ' filled by spEligible for this day
  sameKey = false
  if e.key <> invalid then sameKey = (e.key = c)
  if (not sameKey) or e.ix >= e.order.Count() then
    seedStr = who + "-deck-" + seed + "-" + e.rounds.ToStr()
    e.rounds = e.rounds + 1
    e.order = spDeckShuffle(i, e.recent, spHash(seedStr))
    e.ix = 0
    e.key = c
  end if
  l = e.order[e.ix]
  e.ix = e.ix + 1
  e.recent.Push(l)
  if e.recent.Count() > e.order.Count() then e.recent.Shift()
  return l
end function

' JS Pu(audioList, bumpId, breakIndex, seed)
function spPickAudio(list as object, bumpId as dynamic, idx as longinteger, seed as string) as dynamic
  if list = invalid or list.Count() = 0 then return invalid
  r = spRng(spHash(spStr(bumpId) + "-audio-" + idx.ToStr() + "-" + seed))
  o = spRandIdx(r, list.Count())
  off = spRandIdx(r, 60)
  fb = []
  d = 1
  while d < list.Count() and fb.Count() < 3
    fb.Push(list[(o + d) mod list.Count()])
    d = d + 1
  end while
  return { track: list[o], startOffset: off, fallbacks: fb }
end function

' JS Xg(stings, breakIndex, channelId, seed)
function spPickSting(list as dynamic, idx as longinteger, who as string, seed as string) as dynamic
  if list = invalid or list.Count() = 0 then return invalid
  r = spRng(spHash(who + "-card-" + idx.ToStr() + "-" + seed))
  return list[spRandIdx(r, list.Count())]
end function

' ------------------------------------------------------------------ ad planner
function spAdPhase(slice as object) as longinteger
  r = spRng(spHash("ad-" + spStr(slice.id)))
  return (spRand(r) * 1000000&) \ 4294967296&
end function

' sort indices 0..n-1 by key[i], then ids[i] (string), then i  (bottom-up merge sort)
function spSortIdx(n as integer, key as object, ids as object) as object
  a = CreateObject("roArray", n, false)
  for i = 0 to n - 1 : a[i] = i : end for
  if n < 2 then return a
  b = CreateObject("roArray", n, false)
  width = 1
  while width < n
    lo = 0
    while lo < n
      mid = lo + width
      if mid > n then mid = n
      hi = lo + 2 * width
      if hi > n then hi = n
      i = lo : j = mid : k = lo
      while i < mid and j < hi
        x = a[i] : y = a[j]
        kx = key[x] : ky = key[y]
        takeY = false
        if ky < kx then
          takeY = true
        else if ky = kx then
          ix = ids[x] : iy = ids[y]
          if iy < ix then
            takeY = true
          else if iy = ix then
            takeY = (y < x)
          end if
        end if
        if takeY then
          b[k] = y : j = j + 1
        else
          b[k] = x : i = i + 1
        end if
        k = k + 1
      end while
      while i < mid
        b[k] = a[i] : i = i + 1 : k = k + 1
      end while
      while j < hi
        b[k] = a[j] : j = j + 1 : k = k + 1
      end while
      lo = lo + 2 * width
    end while
    t = a : a = b : b = t
    width = width * 2
  end while
  return a
end function

function spAdPlan(slices as object, lineup as object, block as dynamic, gapMs as longinteger, channelId as string, start as dynamic, decades as dynamic) as object
  k = spK()
  n = slices.Count()
  keys = CreateObject("roArray", n, false)
  ids = CreateObject("roArray", n, false)
  total& = 0
  for i = 0 to n - 1
    keys[i] = spAdPhase(slices[i])
    ids[i] = spStr(slices[i].id)
    total& = total& + spLong(slices[i].lengthMs)
  end for
  order = spSortIdx(n, keys, ids)
  phases = CreateObject("roArray", n, false)
  for s = 0 to n - 1
    phases[order[s]] = (s * k.LT) \ n
  end for
  ' slices in the order every tier list is sorted in: phase, then id, then index
  ordered = spSortIdx(n, phases, ids)
  mean# = spD(total&) / spD(n)
  rates = spAdRates(lineup, block, gapMs, mean#)
  years = CreateObject("roArray", n, false)
  decs = CreateObject("roArray", n, false)
  anywhere = CreateObject("roArray", n, false)
  for i = 0 to n - 1
    years[i] = spYear(slices[i].year)
    if years[i] <> invalid then decs[i] = spFloorD(years[i] / 10#)
    anywhere[i] = spIsTrue(slices[i].anywhere)
  end for
  decTol = invalid
  if spIsInt(decades) then
    if decades >= 1 then decTol = "d" + spLong(decades).ToStr()
  end if
  st& = 0
  ok = false
  if spIsInt(start) then
    if start >= 0 and start < 1000 then ok = true
  end if
  if ok then
    st& = spLong(start) * 1000
  else
    st& = (spU32(spHash("ads-" + channelId)) mod 1000) * 1000
  end if
  cacheP = {} : cacheP.SetModeCaseSensitive()
  cacheT = {} : cacheT.SetModeCaseSensitive()
  return { phases: phases, ordered: ordered, years: years, decs: decs, anywhere: anywhere, slices: slices, rates: rates, start: st&, decTol: decTol, cacheP: cacheP, cacheT: cacheT }
end function

' JS r0 — how often a cycle breaks for ads, by year
function spAdRates(e as object, block as dynamic, gapMs as longinteger, sliceMs as double) as object
  k = spK()
  s# = 0 : i# = 0 : o# = 0 : c = 0
  by = {} : by.SetModeCaseSensitive()
  n = e.Count()
  for d = 0 to n - 1
    u = e[d]
    f# = spD(spLong(u.duration)) * 1000#
    s# = s# + f# : i# = i# + f# : o# = o# + f#
    inBlock = false
    if block <> invalid and d < n - 1 then
      if o# < block.lengthMs then inBlock = true
    end if
    if inBlock then
      cm# = spD(block.cardMs)
      s# = s# + cm# : i# = i# + cm# : o# = o# + cm#
    else
      o# = 0
      h = e[(d + 1) mod n]
      if (not spIsTrue(u.offAir)) and (not spIsTrue(h.offAir)) and i# >= gapMs then
        c = c + 1
        y = spYear(u.year)
        yk = "null"
        if y <> invalid then yk = y.ToStr()
        if by[yk] = invalid then by[yk] = { year: y, n: 0 }
        by[yk].n = by[yk].n + 1
        s# = s# + (spD(k.BREAK_MS) + sliceMs)
        i# = spD(k.BREAK_MS) / 2#
      else
        s# = s# + spD(k.BREAK_MS) : i# = i# + spD(k.BREAK_MS)
      end if
    end if
  end for
  return { cycleMs: s#, total: c, byYear: by }
end function

' tolerance: invalid = Infinity, number = years, "dN" = decades
function spYearMatch(x as dynamic, g as dynamic, tol as dynamic) as boolean
  if tol = invalid then return true
  if x = invalid or g = invalid then return false
  if spIsStr(tol) then
    S& = Val(Mid(tol, 2))
    dx& = spFloorD(x / 10#) - spFloorD(g / 10#)
    if dx& < 0 then dx& = -dx&
    return dx& <= S&
  end if
  dd& = x - g
  if dd& < 0 then dd& = -dd&
  return dd& <= tol
end function

function spTier(plan as object, g as dynamic, tol as dynamic) as object
  k = spK()
  key = spStr(g) + "|" + spStr(tol)
  if tol = invalid then key = spStr(g) + "|Infinity"
  if plan.cacheP.DoesExist(key) then return plan.cacheP[key]
  w = [] : places = []
  years = plan.years : decs = plan.decs : anyw = plan.anywhere : ph = plan.phases
  if tol = invalid then
    for each x in plan.ordered
      w.Push(x) : places.Push(ph[x])
    end for
  else if g <> invalid then
    if spIsStr(tol) then
      S& = Val(Mid(tol, 2))
      gd& = spFloorD(g / 10#)
      for each x in plan.ordered
        ok = anyw[x]
        if not ok and decs[x] <> invalid then
          dd& = decs[x] - gd&
          ok = (dd& <= S& and dd& >= -S&)
        end if
        if ok then
          w.Push(x) : places.Push(ph[x])
        end if
      end for
    else
      tl& = tol
      for each x in plan.ordered
        ok = anyw[x]
        if not ok and years[x] <> invalid then
          dd& = years[x] - g
          ok = (dd& <= tl& and dd& >= -tl&)
        end if
        if ok then
          w.Push(x) : places.Push(ph[x])
        end if
      end for
    end if
  else
    for each x in plan.ordered
      if anyw[x] then
        w.Push(x) : places.Push(ph[x])
      end if
    end for
  end if
  R& = 0
  for each yk in plan.rates.byYear
    e = plan.rates.byYear[yk]
    if spYearMatch(e.year, g, tol) then R& = R& + e.n
  end for
  cyc# = plan.rates.cycleMs
  dollar# = 0
  if cyc# > 0 then dollar# = (spD(R&) * spD(k.ROUND)) / cyc#
  healthy = w.Count() > 0 and w.Count() >= dollar#
  if healthy or w.Count() = 0 then
    roundMs& = k.ROUND
  else
    roundMs& = spFloorD((spD(w.Count()) * cyc#) / spD(R&))
    if roundMs& < k.HOUR then roundMs& = k.HOUR
  end if
  t = { tol: tol, list: w, places: places, roundMs: roundMs&, healthy: healthy }
  plan.cacheP[key] = t
  return t
end function

function spTiers(plan as object, g as dynamic) as object
  key = spStr(g)
  if plan.cacheT.DoesExist(key) then return plan.cacheT[key]
  v = []
  if g = invalid then
    v.Push(spTier(plan, invalid, invalid))
  else
    tols = [3, 6]
    if plan.decTol <> invalid then tols.Push(plan.decTol)
    for each t in tols : v.Push(spTier(plan, g, t)) : end for
    v.Push(spTier(plan, g, invalid))
  end if
  first = 0
  for i = 0 to v.Count() - 1
    if v[i].healthy or v[i].tol = invalid then first = i : exit for
  end for
  out = []
  for i = first to v.Count() - 1 : out.Push(v[i]) : end for
  plan.cacheT[key] = out
  return out
end function

function spPhaseAt(e as longinteger, t as longinteger, n as longinteger) as longinteger
  LT& = 1000000&
  r& = ((e mod t) + t) mod t
  return ((r& * LT&) \ t + n) mod LT&
end function

function spLowerBound(arr as object, t as longinteger) as integer
  lo = 0 : hi = arr.Count()
  while lo < hi
    s = (lo + hi) \ 2
    if arr[s] < t then lo = s + 1 else hi = s
  end while
  return lo
end function

' JS o0(plan, usedSet, year, nowMs, fromMs) -> slice index
function spPickAd(plan as object, used as object, year as dynamic, r as longinteger, s as longinteger) as integer
  LT& = 1000000&
  k = spK()
  if used.Count() >= plan.phases.Count() then used.Clear()
  tiers = []
  for each l in spTiers(plan, year)
    if l.list.Count() > 0 then tiers.Push(l)
  end for
  c = []
  for each l in tiers
    u = l.list.Count()
    d& = spPhaseAt(s, l.roundMs, plan.start)
    f& = spPhaseAt(r, l.roundMs, plan.start)
    if r <= s then
      h& = 0
    else if r - s >= l.roundMs then
      h& = LT&
    else
      h& = (f& - d& + LT&) mod LT&
    end if
    cap& = k.DAY
    if l.roundMs < cap& then cap& = l.roundMs
    p& = (cap& * LT&) \ l.roundMs
    mm = spLowerBound(l.places, d& + 1)
    c.Push(mm)
    for g = 0 to u - 1
      v = (mm + g) mod u
      gap& = (l.places[v] - d& + LT&) mod LT&
      if gap& = 0 then gap& = LT&
      if gap& > h& then exit for
      if not used.DoesExist(l.list[v].ToStr()) then
        used[l.list[v].ToStr()] = true
        return l.list[v]
      end if
    end for
    for g = 1 to u
      v = (mm - g + u * 2) mod u
      if ((d& - l.places[v] + LT&) mod LT&) >= p& then exit for
      if not used.DoesExist(l.list[v].ToStr()) then
        used[l.list[v].ToStr()] = true
        return l.list[v]
      end if
    end for
  end for
  for li = 0 to tiers.Count() - 1
    tier = tiers[li]
    cnt = tier.list.Count()
    for ff = 1 to cnt
      hh = tier.list[(c[li] - ff + cnt * 2) mod cnt]
      if not used.DoesExist(hh.ToStr()) then
        used[hh.ToStr()] = true
        return hh
      end if
    end for
  end for
  return -1
end function

' ------------------------------------------------------------------ one cycle of a version (JS c0)
function spBuildCycle(items as object, t as dynamic) as object
  kc = spK()
  out = []
  plain = (t = invalid)
  if not plain then plain = (t.channelBumps = invalid or t.platformBumps = invalid)
  if plain then
    for each it in items : out.Push({ "type": "video", src: it, durMs: spLong(it.duration) * 1000& }) : end for
    return out
  end if
  blockCfg = t.block
  firstIdx = 0
  if t.firstIndex <> invalid then firstIdx = t.firstIndex
  seasonAt = t.seasonAtMs
  posMs& = 0
  if t.cycleStartMs <> invalid then posMs& = t.cycleStartMs
  blockMs& = 0 : cardIdx = 0
  slices = invalid
  if t.ads <> invalid and t.ads.slices <> invalid then
    if t.ads.slices.Count() > 0 then slices = t.ads.slices
  end if
  carry = invalid
  if slices <> invalid then carry = t.adCarry
  used = {} : used.SetModeCaseSensitive()
  fromMs = invalid
  if carry <> invalid then
    for each pair in spArr(carry.recent)
      if spIsInt(pair[0]) then
        if pair[0] >= 0 and pair[0] < slices.Count() then used[spLong(pair[0]).ToStr()] = true
      end if
    end for
    if spIsInt(carry.fromMs) then fromMs = spLong(carry.fromMs)
  end if
  picks = []
  adGap& = kc.AD_GAP
  if t.ads <> invalid then
    if spIsInt(t.ads.gapMs) then adGap& = spLong(t.ads.gapMs)
  end if
  plan = invalid
  if slices <> invalid then plan = t.adPlanFn(t, adGap&)
  sinceAd& = 0
  deck = invalid
  if spIsTrue(t.deck) then deck = spDeckFrom(t.deckCarry)
  cnt = items.Count()
  for ki = 0 to cnt - 1
    item = items[ki]
    brk& = firstIdx + ki
    dur& = spLong(item.duration) * 1000&
    out.Push({ "type": "video", src: item, durMs: dur& })
    posMs& = posMs& + dur& : blockMs& = blockMs& + dur& : sinceAd& = sinceAd& + dur&
    handled = false
    if blockCfg <> invalid and ki < cnt - 1 then
      if blockMs& < blockCfg.lengthMs then
        sting = spPickSting(blockCfg.stings, brk&, t.channelId, t.seed)
        cardMs& = spLong(blockCfg.cardMs)
        if sting <> invalid then cardMs& = spLong(sting.lengthMs)
        out.Push({ "type": "up-next", breakIndex: brk&, cardIndex: cardIdx, sting: sting, durMs: cardMs& })
        cardIdx = cardIdx + 1
        posMs& = posMs& + cardMs& : blockMs& = blockMs& + cardMs& : sinceAd& = sinceAd& + cardMs&
        handled = true
      end if
    end if
    if not handled then
      blockMs& = 0
      atMs& = posMs&
      if seasonAt <> invalid then atMs& = seasonAt
      if deck <> invalid then
        chB = spDeckNext(deck, t.chSets, t.channelId, t.seed, atMs&)
      else
        chB = spPickBump(t.chSets, brk&, t.channelId, t.seed, atMs&)
      end if
      plB = spPickBump(t.platSets, brk&, "spelunkr", t.seed, atMs&)
      if chB <> invalid and plB <> invalid then
        chAud = spPickAudio(t.channelAudio, chB.id, brk&, t.seed)
        plAud = spPickAudio(t.platformAudio, plB.id, brk&, t.seed)
        if ki < cnt - 1 then nextItem = items[ki + 1] else nextItem = t.wrapItem
        nextOff = false
        if nextItem <> invalid then nextOff = spIsTrue(nextItem.offAir)
        adHere = false
        if slices <> invalid and (not spIsTrue(item.offAir)) and (not nextOff) then adHere = (sinceAd& >= adGap&)
        if adHere then
          fm& = posMs& - sinceAd&
          if fromMs <> invalid then fm& = fromMs
          adIdx = spPickAd(plan, used, spYear(item.year), posMs&, fm&)
          fromMs = invalid
          picks.Push([adIdx, posMs&])
          adSlice = slices[adIdx]
          openMs& = kc.OPEN_MS + spSlidesMs(chB.slides) + kc.HOLD_MS + kc.TAIL_MS
          closeMs& = spSlidesMs(plB.slides) + kc.HOLD_MS + kc.TAIL_MS
          adMs& = spLong(adSlice.lengthMs)
          out.Push({ "type": "bump-break", half: "open", breakIndex: brk&, channelBump: chB, channelAudio: chAud, durMs: openMs& })
          out.Push({ "type": "ad", breakIndex: brk&, slice: adSlice, sliceIndex: adIdx, durMs: adMs& })
          out.Push({ "type": "bump-break", half: "close", breakIndex: brk&, platformBump: plB, platformAudio: plAud, durMs: closeMs& })
          posMs& = posMs& + openMs& + adMs& + closeMs&
          sinceAd& = closeMs&
          if t.adOut <> invalid then t.adOut.fromMs = posMs&
        else
          pairMs& = spPairMs(chB, plB)
          out.Push({ "type": "bump-break", breakIndex: brk&, channelBump: chB, platformBump: plB, channelAudio: chAud, platformAudio: plAud, durMs: pairMs& })
          posMs& = posMs& + pairMs& : sinceAd& = sinceAd& + pairMs&
        end if
      end if
    end if
  end for
  if slices <> invalid and t.adOut <> invalid then
    ao = t.adOut
    if picks.Count() = 0 then
      if fromMs <> invalid then
        ao.fromMs = fromMs
      else if t.cycleStartMs <> invalid then
        ao.fromMs = t.cycleStartMs
      else
        ao.fromMs = 0&
      end if
    end if
    cut& = posMs& - kc.DAY
    rec = []
    if carry <> invalid then
      for each pr in spArr(carry.recent)
        if pr[1] >= cut& then rec.Push(pr)
      end for
    end if
    for each pr in picks
      if pr[1] >= cut& then rec.Push(pr)
    end for
    ao.recent = rec
  end if
  if deck <> invalid and t.deckOut <> invalid then
    t.deckOut.order = deck.order
    t.deckOut.ix = deck.ix
    t.deckOut.key = deck.key
    t.deckOut.recent = deck.recent
  end if
  return out
end function

function spAdPlanFor(t as object, gap as longinteger) as object
  ver = t.ver
  if ver.adPlan = invalid or ver.adPlanGap <> gap then
    ver.adPlan = spAdPlan(ver.ads.slices, ver.items, ver.block, gap, ver.channelId, ver.ads.start, ver.ads.decades)
    ver.adPlanGap = gap
  end if
  return ver.adPlan
end function

' ------------------------------------------------------------------ versions & playlists
' JS ev(manifest, platformFile, pointer). keyOrder: audioPools keys in JSON order (AAs lose it)
function spVersionFrom(mf as object, plat as dynamic, p as object, poolOrder = invalid as dynamic) as object
  r = spArr(mf.bumps)
  s = []
  if plat <> invalid then s = spArr(plat.bumps)
  for i = 0 to r.Count() - 1 : r[i]._i = i : end for
  for i = 0 to s.Count() - 1 : s[i]._i = i : end for
  bumps = invalid
  if r.Count() > 0 and s.Count() > 0 then
    chAudio = []
    if spIsTrue(mf.audioOverlay) then
      pools = mf.audioPools
      if pools <> invalid then
        order = poolOrder
        if order = invalid then order = pools.Keys()
        for each key in order
          for each x in spArr(pools[key]) : chAudio.Push(x) : end for
        end for
      end if
    else
      chAudio = spArr(mf.audio)
    end if
    bumps = { channelBumps: r, platformBumps: s, chSets: spBumpSets(r), platSets: spBumpSets(s), channelAudio: chAudio, platformAudio: spArr(plat.audio) }
  end if
  eff& = spLong(p.epochMs)
  if p.effectiveAtMs <> invalid then eff& = spLong(p.effectiveAtMs)
  si% = 0
  if p.startIndex <> invalid then si% = spLong(p.startIndex)
  ads = invalid
  if mf.ads <> invalid and mf.ads.slices <> invalid then
    if mf.ads.slices.Count() > 0 then ads = mf.ads
  end if
  return { v: spLong(p.v), epochMs: spLong(p.epochMs), effectiveAtMs: eff&, startIndex: si%, items: mf.items, bumps: bumps, block: mf.block, ads: ads, engine: spLong(mf.engine) }
end function

function spMakePlaylist(channelId as string, versions as object) as object
  pl = { channelId: channelId, versions: [] }
  for each v in versions : spAddVersion(pl, v) : end for
  return pl
end function

function spAddVersion(pl as object, t as object) as boolean
  for each v in pl.versions
    if v.v = t.v then return false
  end for
  vm& = 0
  for each it in t.items : vm& = vm& + spLong(it.duration) * 1000& : end for
  t.channelId = pl.channelId
  t.videoMs = vm&
  t.fwd = [] : t.back = []
  t.built = {} : t.builtOrder = []
  t.adCarry = {} : t.deckCarry = {}
  t.adPlan = invalid
  pl.versions.Push(t)
  pl.versions.SortBy("v")
  return true
end function

function spVersionAt(pl as object, t as longinteger) as dynamic
  n = pl.versions
  for s = n.Count() - 1 to 0 step -1
    if n[s].effectiveAtMs <= t then return n[s]
  end for
  if n.Count() = 0 then return invalid
  r = n[0]
  for each s in n
    if s.effectiveAtMs < r.effectiveAtMs or (s.effectiveAtMs = r.effectiveAtMs and s.v > r.v) then r = s
  end for
  return r
end function

function spNextSwitch(pl as object, cur as object, t as longinteger) as dynamic
  r = invalid
  for each s in pl.versions
    if s.v > cur.v and s.effectiveAtMs > t then
      if r = invalid then
        r = s.effectiveAtMs
      else if s.effectiveAtMs < r then
        r = s.effectiveAtMs
      end if
    end if
  end for
  return r
end function

function spCycleList(e as object, t as integer, extra as object) as object
  r = 0
  if t = 0 then r = e.startIndex
  s = e.items
  if r > 0 then
    s = []
    for i = r to e.items.Count() - 1 : s.Push(e.items[i]) : end for
  end if
  hasAds = (e.ads <> invalid and e.bumps <> invalid and t >= 0)
  o = invalid
  if hasAds then o = {}
  deckOn = (e.bumps <> invalid and e.engine >= 5)
  l = invalid
  if deckOn and t >= 0 then l = {}
  opts = invalid
  if e.bumps <> invalid then
    opts = {}
    opts.Append(e.bumps)
    opts.block = e.block
    if e.ads <> invalid then
      opts.ads = e.ads
      opts.wrapItem = e.items[0]
      opts.adCarry = invalid
      if t >= 1 then opts.adCarry = e.adCarry[t.ToStr()]
      opts.adOut = o
      opts.ver = e
      opts.adPlanFn = spAdPlanFor
    end if
    if deckOn then
      opts.deck = true
      opts.deckCarry = invalid
      if t >= 1 then opts.deckCarry = e.deckCarry[t.ToStr()]
      opts.deckOut = l
    end if
    opts.channelId = e.channelId
    opts.seed = e.v.ToStr() + "." + t.ToStr()
    opts.firstIndex = r
    opts.Append(extra)
  end if
  u = spBuildCycle(s, opts)
  nk = (t + 1).ToStr()
  if hasAds and not e.adCarry.DoesExist(nk) then e.adCarry[nk] = o
  if l <> invalid and not e.deckCarry.DoesExist(nk) then e.deckCarry[nk] = l
  return u
end function

function spListMs(list as object) as longinteger
  t& = 0
  for each x in list : t& = t& + x.durMs : end for
  return t&
end function

function spCycle(e as object, t as integer) as object
  if t >= 0 then
    fw = e.fwd
    while fw.Count() <= t
      if fw.Count() > 0 then
        st& = fw[fw.Count() - 1].startMs + fw[fw.Count() - 1].lengthMs
      else
        st& = e.epochMs
      end if
      ci = fw.Count()
      lst = spCycleList(e, ci, { cycleStartMs: st& })
      e.lastList = { k: ci, list: lst }
      fw.Push({ startMs: st&, lengthMs: spListMs(lst) })
    end while
    return fw[t]
  end if
  bk = e.back
  want = -t - 1
  while bk.Count() <= want
    if bk.Count() > 0 then endAt& = bk[bk.Count() - 1].startMs else endAt& = e.epochMs
    ci = -(bk.Count() + 1)
    lst = spCycleList(e, ci, { seasonAtMs: e.epochMs })
    len& = spListMs(lst)
    e.lastList = { k: ci, list: lst }
    bk.Push({ startMs: endAt& - len&, lengthMs: len& })
  end while
  return bk[want]
end function

function spCycleIndex(e as object, t as longinteger) as integer
  if t >= e.epochMs then
    r = e.fwd
    if r.Count() > 0 then
      s = r[r.Count() - 1]
      if t < s.startMs + s.lengthMs then
        o = 0 : c = r.Count() - 1
        while o < c
          l = (o + c + 1) \ 2
          if r[l].startMs <= t then o = l else c = l - 1
        end while
        return o
      end if
    end if
    i = 0
    if r.Count() > 0 then i = r.Count() - 1
    while true
      o = spCycle(e, i)
      if t < o.startMs + o.lengthMs then return i
      i = i + 1
    end while
  end if
  n = -1
  while spCycle(e, n).startMs > t
    n = n - 1
  end while
  return n
end function

function spBuilt(e as object, t as integer) as object
  key = t.ToStr()
  if e.built.DoesExist(key) then return e.built[key]
  r = spCycle(e, t)
  if e.lastList <> invalid and e.lastList.k = t then
    s = e.lastList.list
  else
    if t >= 0 then
      s = spCycleList(e, t, { cycleStartMs: r.startMs })
    else
      s = spCycleList(e, t, { seasonAtMs: e.epochMs })
    end if
  end if
  e.lastList = invalid
  vi = 0
  if t = 0 then vi = e.startIndex
  o& = 0
  for f = 0 to s.Count() - 1
    d = s[f]
    d.index = f
    d.v = e.v
    d.key = e.v.ToStr() + ":" + key + ":" + f.ToStr()
    d.offMs = o&
    if d.type = "video" then
      d.videoIndex = vi : vi = vi + 1
    end if
    o& = o& + d.durMs
  end for
  u = { k: t, startMs: r.startMs, lengthMs: r.lengthMs, seed: e.v.ToStr() + "." + key, entries: s }
  e.built[key] = u
  e.builtOrder.Push(key)
  if e.builtOrder.Count() > spK().MAX_BUILT then e.built.Delete(e.builtOrder.Shift())
  return u
end function

' JS on(playlist, ms) — what is on the air at ms
function spNowAt(pl as object, t as longinteger) as dynamic
  n = spVersionAt(pl, t)
  if n = invalid then return invalid
  r = spBuilt(n, spCycleIndex(n, t))
  s = r.entries
  i& = t - r.startMs
  o = 0 : c = s.Count() - 1
  while o < c
    p = (o + c + 1) \ 2
    if s[p].offMs <= i& then o = p else c = p - 1
  end while
  l = s[o]
  u& = r.startMs + l.offMs
  d& = u& + l.durMs
  f = spNextSwitch(pl, n, t)
  if f <> invalid then
    if f < d& then d& = f
  end if
  return { item: l, index: o, key: l.key, offsetMs: t - u&, startMs: u&, endMs: d&, version: n.v, cycle: r.k, count: s.Count() }
end function

' in-point (seconds into the tape) for an entry
function spInPoint(item as object) as double
  if item.type = "ad" then
    if item.slice <> invalid and spIsInt(item.slice.inMs) then
      if item.slice.inMs > 0 then return spD(item.slice.inMs) / 1000#
    end if
    return 0#
  end if
  src = item.src
  if src <> invalid and spIsInt(src.inS) then
    if src.inS > 0 then return spD(src.inS)
  end if
  return 0#
end function

' ------------------------------------------------------------------ media URL (needs metadata lookup only for bare items)
function spEncodeURI(s as string) as string
  out = ""
  safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()"
  hex = "0123456789ABCDEF"
  ba = CreateObject("roByteArray")
  ba.FromAsciiString(s)
  for i = 0 to ba.Count() - 1
    b = ba[i]
    ch = Chr(b)
    if b < 128 and Instr(1, safe, ch) > 0 then
      out = out + ch
    else
      out = out + "%" + Mid(hex, (b \ 16) + 1, 1) + Mid(hex, (b mod 16) + 1, 1)
    end if
  end for
  return out
end function

function spDownloadUrl(id as string, file as string) as string
  return "https://archive.org/download/" + id + "/" + spEncodeURI(file)
end function

' returns {url} or {lookup: identifier} when the archive metadata API must be asked
function spMediaRef(item as object) as dynamic
  if item.type = "ad" then
    sl = item.slice
    if sl <> invalid and sl.tape <> invalid and sl.file <> invalid then return { url: spDownloadUrl(sl.tape, sl.file) }
    return invalid
  end if
  src = item.src
  if src = invalid or src.id = invalid then return invalid
  if src.file <> invalid then return { url: spDownloadUrl(src.id, src.file) }
  if src.mp4 <> invalid then return { url: spDownloadUrl(src.id, src.mp4) }
  return { lookup: src.id }
end function

' JS _0(files) — choose the playable file from archive.org metadata
function spPickArchiveFile(files as object) as dynamic
  for each fmt in ["h.264 IA", "h.264", "512Kb MPEG4", "MPEG4"]
    for each f in files
      if f.format = fmt then return f
    end for
  end for
  for each f in files
    if f.name <> invalid and Right(f.name, 4) = ".mp4" then return f
  end for
  return invalid
end function

' ------------------------------------------------------------------ logo palette (JS ul / OS)
function spHexByte(s as string, i as integer) as integer
  return Val(Mid(s, i, 2), 16)
end function

function spPalette(color as dynamic) as object
  base = { k: "#0b0f26", n: "#2a3580", s: "#8899cc", p: "#e8eaf0", g: "#ffd740", o: "#d2500c" }
  c = "#666666"
  if spIsStr(color) then
    if Len(color) = 7 and Left(color, 1) = "#" then
      ok = true
      for i = 2 to 7
        if Instr(1, "0123456789abcdefABCDEF", Mid(color, i, 1)) = 0 then ok = false
      end for
      if ok then c = LCase(color)
    end if
  end if
  hsv = spHsv(c)
  base.c = c
  sh = spHueToward(hsv[0], 255, 14)
  sat = hsv[1] * 1.1#
  if sat > 100 then sat = 100#
  base.d = spHsvHex(sh, sat, hsv[2] * 0.6#)
  base.l = spHsvHex(spHueToward(hsv[0], 50, 10), hsv[1] * 0.6#, hsv[2] + (100 - hsv[2]) * 0.6#)
  return base
end function

function spHsv(c as string) as object
  t# = spHexByte(c, 2) / 255# : n# = spHexByte(c, 4) / 255# : r# = spHexByte(c, 6) / 255#
  s# = t#
  if n# > s# then s# = n#
  if r# > s# then s# = r#
  i# = t#
  if n# < i# then i# = n#
  if r# < i# then i# = r#
  o# = s# - i#
  h# = 0
  if o# <> 0 then
    if s# = t# then
      add# = 0
      if n# < r# then add# = 6
      h# = ((n# - r#) / o# + add#) / 6
    else if s# = n# then
      h# = ((r# - t#) / o# + 2) / 6
    else
      h# = ((t# - n#) / o# + 4) / 6
    end if
  end if
  sv# = 0
  if s# <> 0 then sv# = o# / s# * 100
  return [h# * 360, sv#, s# * 100]
end function

function spJsMod(a as double, b as double) as double
  return a - b * Fix(a / b)
end function

function spHsvHex(e as double, t as double, n as double) as string
  t = t / 100 : n = n / 100
  out = "#"
  for each sh in [5, 3, 1]
    i# = spJsMod(sh + e / 60, 6)
    mn# = i#
    if 4 - i# < mn# then mn# = 4 - i#
    if 1 < mn# then mn# = 1
    if mn# < 0 then mn# = 0
    v# = 255 * (n - n * t * mn#)
    b = Int(v# + 0.5)
    hx = LCase(StrI(b, 16))
    if Len(hx) < 2 then hx = "0" + hx
    out = out + hx
  end for
  return out
end function

function spHueToward(e as double, t as double, n as double) as double
  r# = spJsMod(t - e + 540, 360) - 180
  sg# = 0
  if r# > 0 then sg# = 1
  if r# < 0 then sg# = -1
  ar# = r#
  if ar# < 0 then ar# = -ar#
  mn# = n
  if ar# < mn# then mn# = ar#
  return spJsMod(e + sg# * mn# + 360, 360)
end function

' merged rectangles for a pixel logomark: [{x,y,w,h,t}]
function spPixelRects(rows as object) as object
  out = []
  open = {} : open.SetModeCaseSensitive()
  for r = 0 to rows.Count() - 1
    s = rows[r]
    seen = {} : seen.SetModeCaseSensitive()
    o = 1 : n = Len(s)
    while o <= n
      c = Mid(s, o, 1)
      l = o + 1
      while l <= n and Mid(s, l, 1) = c
        l = l + 1
      end while
      if c <> "." then
        key = (o - 1).ToStr() + ":" + (l - o).ToStr() + ":" + c
        d = open[key]
        if d <> invalid and d.y + d.h = r then
          d.h = d.h + 1
        else
          d = { x: o - 1, y: r, w: l - o, h: 1, t: c }
          out.Push(d)
          open[key] = d
        end if
        seen[key] = true
      end if
      o = l
    end while
    for each key in open.Keys()
      if not seen.DoesExist(key) then open.Delete(key)
    end for
  end for
  return out
end function

' exact conversion to Double (CDbl() can go through single-precision Float)
function spD(x as dynamic) as double
  d# = x
  return d#
end function
