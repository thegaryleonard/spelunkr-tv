' BroadcastTask — owns all network + schedule maths so the render thread stays smooth.

sub init()
  m.top.functionName = "taskMain"
end sub

' ------------------------------------------------------------------ helpers
function nowMs() as longinteger
  d = CreateObject("roDateTime")
  off& = 0
  if m.clockOffset <> invalid then off& = m.clockOffset
  return d.AsSeconds() * 1000& + d.GetMilliseconds() + off&
end function

function http(url as string, timeoutMs = 15000 as integer) as dynamic
  ut = CreateObject("roUrlTransfer")
  ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
  ut.InitClientCertificates()
  ut.EnableEncodings(true)
  ut.RetainBodyOnError(false)
  ut.SetUrl(url)
  ' data.spelunkr.tv admits clients that name themselves (agreed with the Spelunkr devs)
  ut.AddHeader("User-Agent", m.userAgent)
  if m.viaProxy = true then ut.AddHeader("X-Client", m.userAgent)   ' simulator: its XHR can't set User-Agent
  port = CreateObject("roMessagePort")
  ut.SetMessagePort(port)
  if not ut.AsyncGetToString() then return invalid
  msg = wait(timeoutMs, port)
  if type(msg) = "roUrlEvent" then
    if msg.GetResponseCode() = 200 then
      hd = msg.GetResponseHeaders()
      m.lastDate = invalid
      if hd <> invalid then m.lastDate = hd["date"]
      return msg.GetString()
    end if
    print "[spelunkr] HTTP "; msg.GetResponseCode(); " "; url; " "; msg.GetFailureReason()
    return invalid
  end if
  print "[spelunkr] timeout "; url; " "; type(msg)
  ut.AsyncCancel()
  return invalid
end function

function getJson(path as string) as dynamic
  ' manifests/platform files are immutable (versioned) -> cache their text
  fresh = (path = "lineup.json" or path = "live.json")
  if not fresh and m.textCache.DoesExist(path) then return ParseJson(m.textCache[path])
  txt = http(m.dataBase + path)
  if txt = invalid then return invalid
  if not fresh then m.textCache[path] = txt
  return ParseJson(txt)
end function

function padNum(n as integer) as string
  if n < 10 then return "0" + n.ToStr()
  return n.ToStr()
end function

function dialText(dial as dynamic) as string
  if dial = invalid then return "--"
  if dial < 100 then return padNum(dial)
  return dial.ToStr()
end function

' ------------------------------------------------------------------ lineup
function loadLineup() as boolean
  L = getJson("lineup.json")
  if L = invalid or L.channels = invalid then return false
  if L.audioBase <> invalid then m.audioBase = L.audioBase
  if m.forceAudioBase <> invalid then m.audioBase = m.forceAudioBase
  ' remember which versions we have, to compare with live.json
  sum& = 0
  for each c in L.channels
    mx& = 0
    for each p in spArr(c.versions)
      m.knownVersions[c.id + ":" + spLong(p.v).ToStr()] = true
      if spLong(p.v) > mx& then mx& = spLong(p.v)
    end for
    sum& = sum& + mx&
  end for
  m.knownSum = sum&
  list = []
  for each c in L.channels
    ok = (not spIsTrue(c.debugOnly)) and (not spIsTrue(c.comingSoon)) and c.versions <> invalid
    if ok then ok = c.versions.Count() > 0
    if ok then
      ch = m.byId[c.id]
      if ch = invalid then
        ch = { id: c.id, pointers: [], playlist: invalid, fresh: false, failedAt: 0& }
        m.byId[c.id] = ch
      end if
      ch.name = c.name : ch.color = c.color : ch.dial = c.dial : ch.description = c.description
      ch.logomark = c.logomark
      for each p in c.versions
        have = false
        for each q in ch.pointers
          if q.v = p.v then have = true
        end for
        if not have then
          ch.pointers.Push(p)
          ch.fresh = true
        end if
      end for
      list.Push(ch)
    end if
  end for
  ' dial order, channels without a dial last
  for i = 1 to list.Count() - 1
    j = i
    while j > 0 and dialKey(list[j - 1]) > dialKey(list[j])
      t = list[j] : list[j] = list[j - 1] : list[j - 1] = t
      j = j - 1
    end while
  end for
  m.channels = list
  out = []
  for each ch in list
    out.Push({ id: ch.id, name: ch.name, num: dialText(ch.dial), color: ch.color, description: cleanText(ch.description), logo: logoRects(ch) })
  end for
  m.top.lineup = out
  return true
end function

function dialKey(ch as object) as integer
  if ch.dial = invalid then return 100000
  return ch.dial
end function

function valStr(x as dynamic) as string
  if x = invalid then return ""
  return x
end function

' pixel logo -> [{x,y,w,h,c}] with Roku colors, plus grid size
function logoRects(ch as object) as object
  lm = ch.logomark
  if lm = invalid or lm.rows = invalid then return { n: 0, rects: [] }
  pal = spPalette(ch.color)
  out = []
  for each r in spPixelRects(lm.rows)
    col = pal[r.t]
    if col = invalid then col = pal.p
    out.Push({ x: r.x, y: r.y, w: r.w, h: r.h, c: "0x" + Mid(col, 2) + "FF" })
  end for
  return { n: lm.rows.Count(), rects: out }
end function

' ------------------------------------------------------------------ playlists
function relevantPointers(ch as object, t as longinteger) as object
  cur = invalid
  for each p in ch.pointers
    if spLong(p.effectiveAtMs) <= t then
      if cur = invalid then
        cur = p
      else if p.v > cur.v then
        cur = p
      end if
    end if
  end for
  out = []
  for each p in ch.pointers
    if cur = invalid then
      out.Push(p)
    else if p.v >= cur.v then
      out.Push(p)
    end if
  end for
  return out
end function

function buildVersion(p as object) as dynamic
  mf = getJson(p.manifest)
  if mf = invalid then return invalid
  if mf.engine <> invalid and mf.engine > 5 then
    m.top.status = "needs-update"
    return invalid
  end if
  plat = invalid
  if mf.platform <> invalid then plat = getJson(mf.platform)
  order = invalid
  if spIsTrue(mf.audioOverlay) and mf.audioPools <> invalid then order = jsonKeyOrder(m.textCache[p.manifest], "audioPools")
  return spVersionFrom(mf, plat, p, order)
end function

' keys of a top-level object member in source order (roAssociativeArray forgets order)
function jsonKeyOrder(txt as dynamic, member as string) as dynamic
  if txt = invalid then return invalid
  i = Instr(1, txt, Chr(34) + member + Chr(34))
  if i = 0 then return invalid
  i = Instr(i, txt, "{")
  depth = 0 : keys = [] : n = Len(txt) : inStr = false : expectKey = true
  while i <= n
    c = Mid(txt, i, 1)
    if inStr then
      if c = "\" then
        i = i + 1
      else if c = Chr(34) then
        inStr = false
        if depth = 1 and expectKey then
          keys.Push(Mid(txt, keyStart, i - keyStart))
          expectKey = false
        end if
      end if
    else if c = Chr(34) then
      inStr = true : keyStart = i + 1
    else if c = "{" or c = "[" then
      depth = depth + 1
    else if c = "}" or c = "]" then
      depth = depth - 1
      if depth = 0 then return keys
    else if c = "," and depth = 1 then
      expectKey = true
    end if
    i = i + 1
  end while
  return keys
end function

function ensurePlaylist(ch as object) as boolean
  if ch.playlist <> invalid then
    if ch.fresh then addNewVersions(ch)
    return true
  end if
  if ch.failedAt > 0 and nowMs() - ch.failedAt < 20000 then return false
  vs = []
  for each p in relevantPointers(ch, nowMs())
    v = buildVersion(p)
    if v <> invalid then vs.Push(v)
  end for
  if vs.Count() = 0 then
    ch.failedAt = nowMs()
    return false
  end if
  ch.playlist = spMakePlaylist(ch.id, vs)
  ch.fresh = false
  return true
end function

sub addNewVersions(ch as object)
  ch.fresh = false
  for each p in relevantPointers(ch, nowMs())
    have = false
    for each v in ch.playlist.versions
      if v.v = p.v then have = true
    end for
    if not have then
      v = buildVersion(p)
      if v <> invalid then spAddVersion(ch.playlist, v)
    end if
  end for
end sub

' current + next *show* (skips bumps/cards/ads)
function nowNext(ch as object, t as longinteger) as object
  res = { now: invalid, nxt: invalid }
  if ch.playlist = invalid then return res
  at& = t
  for k = 1 to 300
    n = spNowAt(ch.playlist, at&)
    if n = invalid then exit for
    if n.item.type = "video" then
      info = { title: cleanTitle(n.item.src), year: valStr2(n.item.src.year), startMs: n.startMs, endMs: n.endMs }
      if res.now = invalid then
        res.now = info
      else
        res.nxt = info
        exit for
      end if
    end if
    at& = n.endMs
  end for
  return res
end function

function valStr2(x as dynamic) as string
  if x = invalid then return ""
  if spIsStr(x) then return x
  return spStr(x)
end function

' the pixel fonts draw em/en dashes as blanks: use plain hyphens
function cleanText(t as dynamic) as string
  if t = invalid then return ""
  t = t.ToStr()
  for each d in [Chr(8212), Chr(8211), Chr(8210), Chr(8213)]
    t = t.Replace(" " + d + " ", " - ")
    t = t.Replace(d, "-")
  end for
  return t
end function

function cleanTitle(src as dynamic) as string
  if src = invalid then return ""
  t = src.title
  if t = invalid then t = src.id
  if t = invalid then return ""
  return cleanText(t)
end function

' ------------------------------------------------------------------ "what's on" for the player
function audioRef(a as dynamic) as dynamic
  if a = invalid then return invalid
  urls = []
  if a.track.filename <> invalid then urls.Push(m.audioBase + spEncodeURI(a.track.filename))
  for each f in a.fallbacks
    if f.filename <> invalid then urls.Push(m.audioBase + spEncodeURI(f.filename))
  end for
  if urls.Count() = 0 then return invalid
  return { urls: urls, offset: a.startOffset }
end function

function describe(ch as object, n as object, seq as integer) as object
  it = n.item
  d = { seq: seq, id: ch.id, key: n.key, kind: it.type, startMs: n.startMs, endMs: n.endMs }
  if it.type = "video" or it.type = "ad" then
    ref = spMediaRef(it)
    url = invalid
    if ref <> invalid then
      if ref.url <> invalid then
        url = ref.url
      else if ref.lookup <> invalid then
        url = lookupArchive(ref.lookup)
      end if
    end if
    d.url = url
    d.inPoint = spInPoint(it)
    if it.type = "video" then d.title = cleanTitle(it.src)
    return d
  end if
  segs = [] : aud = []
  if it.type = "up-next" then
    nn = nowNext(ch, n.endMs + 1)
    lines = []
    if nn.now <> invalid then lines.Push("NEXT   " + clockText(nn.now.startMs) + "  " + nn.now.title)
    if nn.nxt <> invalid then lines.Push("LATER  " + clockText(nn.nxt.startMs) + "  " + nn.nxt.title)
    big = ch.name
    if nn.now <> invalid then big = nn.now.title
    segs.Push({ a: 0, b: n.endMs - n.startMs, logo: "channel", kicker: "UP NEXT ON " + ch.name, text: big, sub: lines.Join(Chr(10)) })
    if it.sting <> invalid then
      aud.Push({ a: 0, b: n.endMs - n.startMs, urls: [m.audioBase + spEncodeURI(it.sting.track)], offset: spLong(it.sting.startMs) / 1000# })
    end if
  else
    t& = 0
    if it.channelBump <> invalid then
      a0& = t&
      segs.Push({ a: t&, b: t& + 3500, logo: "big", kicker: "CHANNEL " + dialText(ch.dial), text: ch.name, sub: "" })
      t& = t& + 3500
      t& = addSlides(segs, it.channelBump.slides, t&, "channel")
      r = audioRef(it.channelAudio)
      if r <> invalid then
        r.a = a0& : r.b = t&
        aud.Push(r)
      end if
    end if
    if it.channelBump <> invalid and it.platformBump <> invalid then
      segs.Push({ a: t&, b: t& + 300, logo: "", kicker: "", text: "", sub: "" })
      t& = t& + 300
    end if
    if it.platformBump <> invalid then
      a1& = t&
      t& = addSlides(segs, it.platformBump.slides, t&, "spelunkr")
      r = audioRef(it.platformAudio)
      if r <> invalid then
        r.a = a1& : r.b = t&
        aud.Push(r)
      end if
    end if
  end if
  d.segments = segs
  d.audio = aud
  return d
end function

function addSlides(segs as object, list as dynamic, t as longinteger, who as string) as longinteger
  arr = spArr(list)
  for i = 0 to arr.Count() - 1
    ms& = spSlideMs(arr[i].text)
    if i = arr.Count() - 1 then ms& = ms& + 2000   ' last slide holds + tail, as on the site
    segs.Push({ a: t, b: t + ms&, logo: who, kicker: "", text: cleanText(arr[i].text), sub: "" })
    t = t + ms&
  end for
  return t
end function

function clockText(ms as longinteger) as string
  d = CreateObject("roDateTime")
  d.FromSeconds(ms \ 1000)
  d.ToLocalTime()
  h = d.GetHours() : mi = d.GetMinutes()
  ap = "AM"
  if h >= 12 then ap = "PM"
  h12 = h mod 12
  if h12 = 0 then h12 = 12
  return h12.ToStr() + ":" + padNum(mi) + " " + ap
end function

function lookupArchive(id as string) as dynamic
  if m.lookups.DoesExist(id) then return m.lookups[id]
  txt = http("https://archive.org/metadata/" + id, 8000)
  if txt = invalid then return invalid
  j = ParseJson(txt)
  if j = invalid or j.files = invalid then return invalid
  f = spPickArchiveFile(j.files)
  if f = invalid then return invalid
  url = spDownloadUrl(id, f.name)
  m.lookups[id] = url
  return url
end function

' ------------------------------------------------------------------ commands
sub answerNow(cmd as object)
  ch = m.byId[cmd.id]
  if ch = invalid then return
  if not ensurePlaylist(ch) then
    m.top.now = { seq: cmd.seq, id: cmd.id, kind: "nosignal", startMs: nowMs(), endMs: nowMs() + 10000 }
    return
  end if
  n = spNowAt(ch.playlist, nowMs())
  if n = invalid then
    m.top.now = { seq: cmd.seq, id: cmd.id, kind: "nosignal", startMs: nowMs(), endMs: nowMs() + 10000 }
    return
  end if
  d = describe(ch, n, cmd.seq)
  nn = nowNext(ch, nowMs())
  d.show = nn.now
  d.nextShow = nn.nxt
  ' during a break the "now" show is the one coming back
  m.top.now = d
end sub

sub answerGuide()
  rows = {}
  t = nowMs()
  for each ch in m.channels
    if ch.playlist <> invalid then
      nn = nowNext(ch, t)
      rows[ch.id] = { now: nn.now, nxt: nn.nxt }
    end if
  end for
  m.top.guide = { at: t, rows: rows }
end sub

' ------------------------------------------------------------------ live.json heartbeat
' Polled once a minute. lineup.json (and new manifests) are fetched only when it shows a new version.
' Its HTTP Date header also keeps our clock honest (replaces the old spelunkr.tv clock checks).
sub pollLive()
  sent& = nowMs()
  live = getJson("live.json")
  if live = invalid then return
  got& = nowMs()
  clockFromLive(m.lastDate, live.written, sent&, got&)
  changed = false
  if live.publicVersionSum <> invalid and m.knownSum <> invalid then
    if spLong(live.publicVersionSum) <> m.knownSum then changed = true
  end if
  if live.latest <> invalid and live.latest.channel_id <> invalid then
    if not m.knownVersions.DoesExist(live.latest.channel_id + ":" + spLong(live.latest.version).ToStr()) then changed = true
  end if
  for each v in spArr(live.versions)
    if v <> invalid and v.channel_id <> invalid then
      if not m.knownVersions.DoesExist(v.channel_id + ":" + spLong(v.version).ToStr()) then changed = true
    end if
  end for
  if changed then
    if loadLineup() then m.bgIndex = 0
  end if
end sub

sub clockFromLive(httpDate as dynamic, written as dynamic, sent as longinteger, got as longinteger)
  if m.fixedClock = true then return   ' simulator test with a forced clock
  local& = sent + (got - sent) \ 2 - m.clockOffset   ' device clock at mid-request
  if httpDate <> invalid then
    d = CreateObject("roDateTime")
    d.FromISO8601String(httpToIso(httpDate))
    srv& = d.AsSeconds() * 1000& + 500
    if srv& > 1000000000000& then
      s& = srv& - local&
      if s& > 1500 or s& < -1500 then m.clockOffset = s& else m.clockOffset = 0&
      m.top.clockOffset = m.clockOffset
      return
    end if
  end if
  if written <> invalid then
    d = CreateObject("roDateTime")
    d.FromISO8601String(written)
    w& = d.AsSeconds() * 1000&
    if w& > 1000000000000& and local& + m.clockOffset < w& - 2000 then
      m.clockOffset = w& - local&
      m.top.clockOffset = m.clockOffset
    end if
  end if
end sub

' "Sun, 08 Nov 2026 22:37:20 GMT" -> "2026-11-08T22:37:20Z"
function httpToIso(h as string) as string
  months = { Jan: "01", Feb: "02", Mar: "03", Apr: "04", May: "05", Jun: "06", Jul: "07", Aug: "08", Sep: "09", Oct: "10", Nov: "11", Dec: "12" }
  p = h.Trim().Split(" ")
  if p.Count() < 5 then return ""
  mo = months[p[2]]
  if mo = invalid then return ""
  dd = p[1]
  if Len(dd) = 1 then dd = "0" + dd
  return p[3] + "-" + mo + "-" + dd + "T" + p[4] + "Z"
end function

' ------------------------------------------------------------------ main loop
sub taskMain()
  print "[spelunkr] task start"
  spInitBits()
  m.textCache = {}
  m.lookups = {}
  m.byId = {}
  m.byId.SetModeCaseSensitive()
  m.channels = []
  m.audioBase = "https://audio.spelunkr.tv/bumps/"
  m.dataBase = "https://data.spelunkr.tv/"
  m.userAgent = "spelunkr-roku/" + CreateObject("roAppInfo").GetVersion()
  m.knownVersions = {}
  m.knownVersions.SetModeCaseSensitive()
  m.knownSum = invalid
  m.lastDate = invalid
  m.fixedClock = false
  m.viaProxy = false
  if m.clockOffset = invalid then m.clockOffset = 0&
  ' optional pkg:/config.json (used for simulator builds that need a CORS proxy)
  cfgTxt = ""
  if CreateObject("roFileSystem").Exists("pkg:/config.json") then cfgTxt = ReadAsciiFile("pkg:/config.json")
  if cfgTxt <> "" then
    cfg = ParseJson(cfgTxt)
    if cfg <> invalid and cfg.dataBase <> invalid then
      m.dataBase = cfg.dataBase
      m.viaProxy = true
    end if
    if cfg <> invalid and cfg.audioBase <> invalid then m.forceAudioBase = cfg.audioBase
    if cfg <> invalid and cfg.clockOffsetMs <> invalid then
      m.clockOffset = spLong(cfg.clockOffsetMs)
      m.fixedClock = true
      m.top.clockOffset = m.clockOffset
    end if
  end if
  port = CreateObject("roMessagePort")
  m.top.ObserveField("cmd", port)
  m.top.status = "loading"
  while not loadLineup()
    m.top.status = "offline"
    wait(10000, port)
  end while
  m.top.status = "ready"
  pollLive()
  lastLive = nowMs()
  m.bgIndex = 0
  guideDirty = false
  while true
    msg = wait(250, port)
    if type(msg) = "roSGNodeEvent" then
      cmd = msg.GetData()
      if cmd <> invalid and cmd.type = "now" then answerNow(cmd)
      if cmd <> invalid and cmd.type = "guide" then answerGuide()
    else
      ' idle: build one more channel's schedule in the background; heartbeat once a minute
      if m.bgIndex < m.channels.Count() then
        ch = m.channels[m.bgIndex]
        if ch.playlist = invalid then
          if ensurePlaylist(ch) then nowNext(ch, nowMs())   ' warm the schedule maths too
          guideDirty = true
        end if
        m.bgIndex = m.bgIndex + 1
      else if guideDirty then
        guideDirty = false
        answerGuide()
      end if
      if nowMs() - lastLive > 60000 then
        lastLive = nowMs()
        pollLive()
      end if
    end if
  end while
end sub
