' Spelunkr for Roku — remote-first player: ▲▼ channels, OK guide, ◀▶ info, Back closes / exits.

sub init()
  m.video = m.top.findNode("video")
  m.audio = m.top.findNode("audio")
  m.card = m.top.findNode("card")
  m.static = m.top.findNode("static")
  m.banner = m.top.findNode("banner")
  m.guide = m.top.findNode("guide")
  m.preview = m.top.findNode("preview")
  m.rows = m.top.findNode("rows")
  m.toast = m.top.findNode("toast")
  m.statics = [m.top.findNode("st0"), m.top.findNode("st1"), m.top.findNode("st2"), m.top.findNode("st3")]
  m.miniStatics = [m.top.findNode("ms0"), m.top.findNode("ms1"), m.top.findNode("ms2"), m.top.findNode("ms3")]
  m.mini = m.top.findNode("mini")
  m.cardOn = false
  m.clockOffset = 0&
  m.staticFrame = 0

  m.seq = 0
  m.channels = []
  m.cur = invalid
  m.entry = invalid
  m.segIndex = -1
  m.audioKey = ""
  m.loadedUrl = ""
  m.mediaSince = 0&
  m.exitArmed = 0&
  m.flipTo = invalid
  m.guideRows = {}
  m.guideSel = 0
  m.guideTop = 0
  m.VISIBLE = 6
  m.reg = CreateObject("roRegistrySection", "spelunkr")

  m.video.observeField("state", "onVideoState")
  m.audio.observeField("state", "onAudioState")
  m.top.findNode("tick").observeField("fire", "onTick")
  m.top.findNode("staticTimer").observeField("fire", "onStatic")
  m.top.findNode("endTimer").observeField("fire", "onEntryEnd")
  m.top.findNode("bannerTimer").observeField("fire", "hideBanner")
  m.top.findNode("flipTimer").observeField("fire", "onFlipDone")
  m.top.findNode("toastTimer").observeField("fire", "hideToast")
  m.top.findNode("retryTimer").observeField("fire", "requestNow")
  m.top.findNode("watchdog").observeField("fire", "onWatchdog")
  m.top.findNode("slowTimer").observeField("fire", "onSlow")
  m.top.findNode("tick").control = "start"
  m.top.findNode("watchdog").control = "start"
  m.top.findNode("slowTimer").control = "start"

  m.task = CreateObject("roSGNode", "BroadcastTask")
  m.task.observeField("lineup", "onLineup")
  m.task.observeField("now", "onNow")
  m.task.observeField("guide", "onGuide")
  m.task.observeField("status", "onStatus")
  m.task.observeField("clockOffset", "onClockOffset")
  m.task.control = "RUN"

  showStatic("ADJUSTING THE ANTENNA…")
  m.top.setFocus(true)
end sub

' ------------------------------------------------------------------ time & text
function nowMs() as longinteger
  d = CreateObject("roDateTime")
  return d.AsSeconds() * 1000& + d.GetMilliseconds() + m.clockOffset
end function

function pad2(n as integer) as string
  if n < 10 then return "0" + n.ToStr()
  return n.ToStr()
end function

function clockText(ms as longinteger) as string
  d = CreateObject("roDateTime")
  d.FromSeconds(ms \ 1000)
  d.ToLocalTime()
  h = d.GetHours()
  ap = "AM"
  if h >= 12 then ap = "PM"
  h12 = h mod 12
  if h12 = 0 then h12 = 12
  return h12.ToStr() + ":" + pad2(d.GetMinutes()) + " " + ap
end function

function durText(ms as longinteger) as string
  sec = ms \ 1000
  if sec < 0 then sec = 0
  h = sec \ 3600
  mi = (sec mod 3600) \ 60
  if h > 0 then return h.ToStr() + " HR " + mi.ToStr() + " MIN"
  if mi < 1 then mi = 1
  return mi.ToStr() + " MIN"
end function

function withYear(show as object) as string
  t = show.title
  y = show.year
  if y <> invalid and y <> "" then
    if Instr(1, t, Right(y, 2)) = 0 then return t + "  (" + y + ")"
  end if
  return t
end function

' ------------------------------------------------------------------ task events
sub onClockOffset()
  m.clockOffset = m.task.clockOffset
end sub

sub onStatus()
  st = m.task.status
  if st = "offline" then showCard({ logo: "", kicker: "", text: "NO SIGNAL", sub: "can't reach spelunkr.tv — check the internet connection." + Chr(10) + "trying again…" })
  if st = "needs-update" then showToast("THIS CHANNEL NEEDS A NEWER VERSION OF THE APP", 6)
end sub

sub onLineup()
  list = m.task.lineup
  if list = invalid or list.Count() = 0 then return
  first = (m.channels.Count() = 0)
  m.channels = list
  if first then
    last = m.reg.Read("last")
    want = last
    if m.top.launchChannel <> invalid and m.top.launchChannel <> "" then want = m.top.launchChannel
    ch = list[0]
    for each c in list
      if c.id = want then ch = c
    end for
    tune(ch)
    if last = "" then showToast("▲▼ CHANGE CHANNEL  ·  OK GUIDE  ·  ◀▶ INFO", 6)
  else if m.cur <> invalid then
    for each c in list
      if c.id = m.cur.id then m.cur = c
    end for
  end if
end sub

sub onGuide()
  g = m.task.guide
  if g = invalid or g.rows = invalid then return
  m.guideRows = g.rows
  if m.guide.visible then renderGuide()
end sub

' ------------------------------------------------------------------ tuning
sub tune(ch as object)
  m.seq = m.seq + 1
  m.cur = ch
  m.entry = invalid
  m.reg.Write("last", ch.id)
  m.reg.Flush()
  m.top.findNode("endTimer").control = "stop"
  m.top.findNode("retryTimer").control = "stop"
  stopVideo()
  stopAudio()
  showStatic("ADJUSTING THE ANTENNA…")
  if not m.guide.visible then showBanner(6)
  requestNow()
end sub

sub requestNow()
  if m.cur = invalid then return
  m.task.cmd = { "type": "now", id: m.cur.id, seq: m.seq }
end sub

sub onNow()
  d = m.task.now
  if d = invalid or m.cur = invalid then return
  if d.seq <> m.seq or d.id <> m.cur.id then return
  prev = m.entry
  m.entry = d
  m.segIndex = -1
  et = m.top.findNode("endTimer")
  wait# = (d.endMs - nowMs()) / 1000# + 0.03
  if wait# < 0.25 then wait# = 0.25
  et.duration = wait#
  et.control = "start"
  if d.kind = "video" or d.kind = "ad" then
    stopAudio()
    if d.url = invalid then
      noSignal()
    else
      playMedia(d)
    end if
  else if d.kind = "nosignal" then
    stopVideo()
    stopAudio()
    showCard({ logo: "channel", kicker: "CH " + m.cur.num + " · " + m.cur.name, text: "NO SIGNAL", sub: "trying again in a few seconds…" })
  else
    stopVideo()
    onTick()
  end if
  if m.banner.visible then renderBanner()
end sub

sub onEntryEnd()
  requestNow()
end sub

function target() as double
  return m.entry.inPoint + (nowMs() - m.entry.startMs) / 1000#
end function

sub playMedia(d as object)
  if m.loadedUrl = d.url and (m.video.state = "playing" or m.video.state = "paused") then
    t# = target()
    if Abs(m.video.position - t#) > 2 then m.video.seek = t#
    if m.video.state = "paused" then m.video.control = "resume"
    return
  end if
  if not m.card.visible then showStatic("ADJUSTING THE ANTENNA…")
  c = CreateObject("roSGNode", "ContentNode")
  c.url = d.url
  c.streamFormat = "mp4"
  t# = target()
  c.PlayStart = Int(t#)
  m.video.content = c
  m.video.control = "play"
  m.loadedUrl = d.url
  m.mediaSince = nowMs()
end sub

sub stopVideo()
  m.video.control = "stop"
  m.loadedUrl = ""
end sub

sub onVideoState()
  st = m.video.state
  if m.entry = invalid then return
  isMedia = (m.entry.kind = "video" or m.entry.kind = "ad")
  if not isMedia then return
  if st = "playing" then
    m.mediaSince = nowMs()
    t# = target()
    if Abs(m.video.position - t#) > 3 then m.video.seek = t#
    hideCard()
  else if st = "error" then
    noSignal()
  else if st = "finished" then
    requestNow()
  end if
end sub

sub noSignal()
  stopVideo()
  title = ""
  if m.entry <> invalid and m.entry.title <> invalid then title = m.entry.title
  showCard({ logo: "channel", kicker: "CH " + m.cur.num + " · " + m.cur.name, text: "NO SIGNAL", sub: title + Chr(10) + "this tape won't play right now — retrying…" })
  rt = m.top.findNode("retryTimer")
  rt.duration = 12
  rt.control = "start"
end sub

sub onWatchdog()
  if m.entry = invalid then return
  if not (m.entry.kind = "video" or m.entry.kind = "ad") or m.loadedUrl = "" then return
  st = m.video.state
  if st = "playing" then
    m.mediaSince = nowMs()
    t# = target()
    if Abs(m.video.position - t#) > 6 then m.video.seek = t#
  else if nowMs() - m.mediaSince > 30000 then
    m.loadedUrl = ""     ' stuck for 30 s: reload at the live point
    requestNow()
  end if
end sub

' ------------------------------------------------------------------ cards (bumps, up next, static)
sub syncMini()
  inGuide = m.guide.visible
  m.mini.visible = inGuide and m.cardOn
  m.card.visible = (not inGuide) and m.cardOn
  m.top.findNode("miniStatic").visible = m.static.visible
  m.top.findNode("miniBox").visible = m.static.visible
  m.top.findNode("miniText").text = m.top.findNode("cardText").text
end sub

sub showStatic(msg as string)
  m.cardOn = true
  m.card.visible = true
  m.static.visible = true
  m.top.findNode("staticTimer").control = "start"
  m.top.findNode("cardLogo").visible = false
  m.top.findNode("cardS").visible = false
  m.top.findNode("cardKicker").text = ""
  m.top.findNode("cardSub").text = ""
  setCardText(msg, 60)
  m.top.findNode("cardText").translation = [260, 500]
  m.top.findNode("cardShadow").translation = [264, 504]
  syncMini()
end sub

sub setCardText(t as string, size as integer)
  for each id in ["cardText", "cardShadow"]
    n = m.top.findNode(id)
    n.text = t
  end for
end sub

sub showCard(o as object)
  m.cardOn = true
  m.card.visible = true
  m.static.visible = false
  m.top.findNode("staticTimer").control = "stop"
  logo = m.top.findNode("cardLogo")
  s = m.top.findNode("cardS")
  logo.visible = false
  s.visible = false
  if o.logo = "channel" or o.logo = "big" then
    size = 160
    if o.logo = "big" then size = 260
    logo.size = size
    logo.logo = m.cur.logo
    logo.translation = [960 - size / 2, 420 - size]
    logo.visible = true
  else if o.logo = "spelunkr" then
    s.visible = true
  end if
  m.top.findNode("cardKicker").text = o.kicker
  setCardText(o.text, 72)
  m.top.findNode("cardText").translation = [260, 530]
  m.top.findNode("cardShadow").translation = [264, 534]
  m.top.findNode("cardSub").text = o.sub
  syncMini()
end sub

sub hideCard()
  m.cardOn = false
  m.mini.visible = false
  m.card.visible = false
  m.static.visible = false
  m.top.findNode("staticTimer").control = "stop"
end sub

sub onStatic()
  m.statics[m.staticFrame].visible = false
  m.miniStatics[m.staticFrame].visible = false
  m.staticFrame = (m.staticFrame + 1) mod 4
  m.statics[m.staticFrame].visible = true
  m.miniStatics[m.staticFrame].visible = true
end sub

sub onTick()
  e = m.entry
  if e = invalid or e.segments = invalid then return
  if e.kind = "video" or e.kind = "ad" or e.kind = "nosignal" then return
  el& = nowMs() - e.startMs
  segs = e.segments
  if segs.Count() = 0 then return
  i = 0
  while i < segs.Count() - 1 and el& >= segs[i].b
    i = i + 1
  end while
  if i <> m.segIndex then
    m.segIndex = i
    showCard(segs[i])
  end if
  ap = invalid
  for each a in e.audio
    if el& >= a.a and el& < a.b then ap = a
  end for
  if ap <> invalid then
    playTrack(ap, (el& - ap.a) / 1000#)
  else if m.audioKey <> "" then
    stopAudio()
  end if
end sub

sub playTrack(ref as object, into as double)
  key = ref.urls[0]
  if m.audioKey = key then return
  m.audioKey = key
  m.audioRef = ref
  m.audioIdx = 0
  m.audioInto = into
  m.audioAsked = nowMs()
  startAudioUrl()
end sub

sub startAudioUrl()
  c = CreateObject("roSGNode", "ContentNode")
  c.url = m.audioRef.urls[m.audioIdx]
  c.streamFormat = "mp3"
  m.audio.content = c
  m.audio.control = "play"
  m.audioSeeked = false
end sub

sub onAudioState()
  st = m.audio.state
  if m.audioKey = "" then return
  if st = "playing" and not m.audioSeeked then
    m.audioSeeked = true
    m.audio.seek = m.audioRef.offset + m.audioInto + (nowMs() - m.audioAsked) / 1000#
  else if st = "error" then
    if m.audioIdx + 1 < m.audioRef.urls.Count() then
      m.audioIdx = m.audioIdx + 1
      startAudioUrl()
    end if
  end if
end sub

sub stopAudio()
  m.audio.control = "stop"
  m.audioKey = ""
end sub

' ------------------------------------------------------------------ banner
sub showBanner(sec as integer)
  m.banner.visible = true
  renderBanner()
  bt = m.top.findNode("bannerTimer")
  bt.duration = sec
  bt.control = "stop"
  bt.control = "start"
end sub

sub hideBanner()
  m.banner.visible = false
end sub

sub renderBanner()
  ch = m.cur
  if m.flipTo <> invalid then ch = m.flipTo
  if ch = invalid then return
  t& = nowMs()
  m.top.findNode("bNum").text = ch.num
  m.top.findNode("bLogo").logo = ch.logo
  m.top.findNode("bName").text = ch.name
  m.top.findNode("bClock").text = clockText(t&)
  show = invalid : nxt = invalid
  isBreak = false
  if m.flipTo = invalid and m.entry <> invalid and m.entry.show <> invalid then
    show = m.entry.show
    nxt = m.entry.nextShow
    isBreak = (m.entry.kind <> "video" and show.startMs > t&)
  else
    r = m.guideRows[ch.id]
    if r <> invalid then
      show = r.now
      nxt = r.nxt
    end if
  end if
  nowL = m.top.findNode("bNow")
  nowT = m.top.findNode("bNowTime")
  nxtL = m.top.findNode("bNext")
  nxtT = m.top.findNode("bNextTime")
  prog = m.top.findNode("bProgress")
  if show = invalid then
    nowL.text = "ADJUSTING THE ANTENNA…"
    nowT.text = "" : nxtL.text = "" : nxtT.text = ""
    prog.width = 0
    return
  end if
  if isBreak then
    nowL.text = "WE'LL BE RIGHT BACK"
    nowT.text = "BACK AT " + clockText(show.startMs)
    prog.width = 0
    nxtL.text = show.title
    nxtT.text = clockText(show.startMs)
  else
    nowL.text = withYear(show)
    nowT.text = durText(show.endMs - t&) + " LEFT"
    span# = show.endMs - show.startMs
    pct# = 0
    if span# > 0 then pct# = (t& - show.startMs) / span#
    if pct# < 0 then pct# = 0
    if pct# > 1 then pct# = 1
    prog.width = Int(1518 * pct#)
    if nxt <> invalid then
      nxtL.text = nxt.title
      nxtT.text = clockText(nxt.startMs)
    else
      nxtL.text = "" : nxtT.text = ""
    end if
  end if
end sub

' ------------------------------------------------------------------ guide
sub openGuide()
  hideBanner()
  m.guideSel = 0
  for i = 0 to m.channels.Count() - 1
    if m.cur <> invalid and m.channels[i].id = m.cur.id then m.guideSel = i
  end for
  m.guideTop = m.guideSel - 2
  if m.guideTop > m.channels.Count() - m.VISIBLE then m.guideTop = m.channels.Count() - m.VISIBLE
  if m.guideTop < 0 then m.guideTop = 0
  m.top.findNode("guideBg").visible = true
  m.top.findNode("videoFrame").visible = true
  m.video.translation = [40, 28]
  m.video.width = 576
  m.video.height = 324
  m.guide.visible = true
  m.preview.visible = true
  syncMini()
  m.task.cmd = { "type": "guide" }
  renderGuide()
end sub

sub closeGuide()
  m.guide.visible = false
  m.preview.visible = false
  m.top.findNode("guideBg").visible = false
  m.top.findNode("videoFrame").visible = false
  m.video.translation = [0, 0]
  m.video.width = 1920
  m.video.height = 1080
  syncMini()
end sub

sub moveSel(d as integer)
  n = m.channels.Count()
  if n = 0 then return
  m.guideSel = ((m.guideSel + d) mod n + n) mod n
  if m.guideSel < m.guideTop then m.guideTop = m.guideSel
  if m.guideSel >= m.guideTop + m.VISIBLE then m.guideTop = m.guideSel - m.VISIBLE + 1
  renderGuide()
end sub

sub renderGuide()
  t& = nowMs()
  m.top.findNode("gClock").text = clockText(t&)
  for k = 0 to m.VISIBLE - 1
    row = m.rows.getChild(k)
    i = m.guideTop + k
    if i < m.channels.Count() then
      row.visible = true
      ch = m.channels[i]
      r = m.guideRows[ch.id]
      d = { num: ch.num, name: ch.name, logo: ch.logo, nowT: "ADJUSTING THE ANTENNA…", nowM: "", nxtT: "", nxtM: "", playing: (m.cur <> invalid and ch.id = m.cur.id) }
      if r <> invalid and r.now <> invalid then
        d.nowT = r.now.title
        if r.now.startMs > t& then
          d.nowM = "STARTS " + clockText(r.now.startMs)
        else
          d.nowM = durText(r.now.endMs - t&) + " LEFT"
          if r.now.year <> invalid and r.now.year <> "" then d.nowM = d.nowM + " · " + r.now.year
        end if
        if r.nxt <> invalid then
          d.nxtT = r.nxt.title
          d.nxtM = clockText(r.nxt.startMs)
        end if
      end if
      row.odd = (k mod 2) = 0
      row.selected = (i = m.guideSel)
      row.data = d
    else
      row.visible = false
    end if
  end for
  ch = m.channels[m.guideSel]
  if ch = invalid then return
  m.top.findNode("pLogo").logo = ch.logo
  m.top.findNode("pNum").text = ch.num
  m.top.findNode("pName").text = ch.name
  r = m.guideRows[ch.id]
  pn = ""
  if r <> invalid and r.now <> invalid then pn = withYear(r.now)
  m.top.findNode("pNow").text = pn
  m.top.findNode("pDesc").text = ch.description
  if m.cur <> invalid and ch.id = m.cur.id then
    m.top.findNode("pHint").text = "NOW WATCHING"
  else
    m.top.findNode("pHint").text = "PRESS OK TO TUNE IN"
  end if
end sub

sub onSlow()
  if m.guide.visible then m.task.cmd = { "type": "guide" }
  if not m.guide.visible and m.channels.Count() > 0 then m.task.cmd = { "type": "guide" }
end sub

' ------------------------------------------------------------------ flipping
sub flip(d as integer)
  n = m.channels.Count()
  if n = 0 then return
  base = m.cur
  if m.flipTo <> invalid then base = m.flipTo
  idx = 0
  for i = 0 to n - 1
    if m.channels[i].id = base.id then idx = i
  end for
  m.flipTo = m.channels[((idx + d) mod n + n) mod n]
  showBanner(6)
  ft = m.top.findNode("flipTimer")
  ft.control = "stop"
  ft.control = "start"
end sub

sub onFlipDone()
  ch = m.flipTo
  m.flipTo = invalid
  if ch <> invalid then tune(ch)
end sub

' ------------------------------------------------------------------ toast
sub showToast(msg as string, sec as integer)
  m.top.findNode("toastText").text = msg
  m.toast.visible = true
  tt = m.top.findNode("toastTimer")
  tt.duration = sec
  tt.control = "stop"
  tt.control = "start"
end sub

sub hideToast()
  m.toast.visible = false
end sub

' ------------------------------------------------------------------ keys
function onKeyEvent(key as string, press as boolean) as boolean
  if not press then return true
  if m.channels.Count() = 0 then
    if key = "back" then m.top.exitApp = true
    return true
  end if
  if m.guide.visible then
    if key = "up" then
      moveSel(-1)
    else if key = "down" then
      moveSel(1)
    else if key = "left" or key = "rewind" then
      moveSel(-m.VISIBLE)
    else if key = "right" or key = "fastforward" then
      moveSel(m.VISIBLE)
    else if key = "OK" or key = "play" then
      ch = m.channels[m.guideSel]
      closeGuide()
      if m.cur = invalid or ch.id <> m.cur.id then tune(ch) else showBanner(6)
    else if key = "back" or key = "options" then
      closeGuide()
    end if
    return true
  end if
  if key = "up" then
    flip(1)
  else if key = "down" then
    flip(-1)
  else if key = "OK" or key = "options" then
    openGuide()
  else if key = "left" or key = "right" or key = "play" then
    showBanner(8)
  else if key = "back" then
    if m.banner.visible then
      hideBanner()
    else if nowMs() - m.exitArmed < 3000 then
      m.top.exitApp = true
    else
      m.exitArmed = nowMs()
      showToast("PRESS BACK AGAIN TO TURN OFF THE TV… ER, THE APP", 3)
    end if
  end if
  return true
end function
