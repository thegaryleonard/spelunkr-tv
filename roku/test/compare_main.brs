' Runs the BrightScript engine over the same fixtures/instants as expected.mjs and writes actual.txt
' run:  npx brs --root <test dir> ../app/source/engine.brs compare_main.brs
sub main()
  print "native bits "; spInitBits()
  cfg = ParseJson(ReadAsciiFile("pkg:/times.json"))
  L = ParseJson(ReadAsciiFile("pkg:/fixtures/lineup.json"))
  steps = cfg.steps
  only = cfg.only
  lines = []
  cache = {}
  t0 = CreateObject("roTimespan")
  for each c in L.channels
    if only = "" or Instr(1, "," + only + ",", "," + c.id + ",") > 0 then
      vs = []
      for each p in c.versions
        mf = loadJ(cache, p.manifest)
        if mf.engine <= 5 then
          plat = invalid
          if mf.platform <> invalid then plat = loadJ(cache, mf.platform)
          platText = invalid
          if mf.platform <> invalid then platText = ReadAsciiFile("pkg:/fixtures/" + mf.platform)
          vs.Push({ mfText: ReadAsciiFile("pkg:/fixtures/" + p.manifest), platText: platText, p: p })
        end if
      end for
      if vs.Count() > 0 then
        for each tt in cfg.times
          t& = tt
          ' fresh objects per instant (cold start), like expected.mjs
          built = []
          for each x in vs
            mf2 = ParseJson(x.mfText)
            pl2 = invalid
            if x.platText <> invalid then pl2 = ParseJson(x.platText)
            built.Push(spVersionFrom(mf2, pl2, x.p))
          end for
          pl = spMakePlaylist(c.id, built)
          at& = t&
          for i = 1 to steps
            n = spNowAt(pl, at&)
            lines.Push(c.id + "|" + t&.ToStr() + "|" + sig(n))
            at& = n.endMs
          end for
        end for
        print c.id; " done "; t0.TotalMilliseconds(); "ms"
        WriteAsciiFile("pkg:/actual.txt", lines.Join(Chr(10)) + Chr(10))
      end if
    end if
  end for
  WriteAsciiFile("pkg:/actual.txt", lines.Join(Chr(10)) + Chr(10))
  print "actual lines "; lines.Count()
end sub

function loadJ(cache as object, path as string) as object
  if not cache.DoesExist(path) then cache[path] = ParseJson(ReadAsciiFile("pkg:/fixtures/" + path))
  return cache[path]
end function

function aud(x as dynamic) as string
  if x = invalid then return "-"
  fb = []
  for each f in x.fallbacks
    if f.filename = invalid then fb.Push("") else fb.Push(f.filename)
  end for
  fn = "undefined"
  if x.track.filename <> invalid then fn = x.track.filename
  return fn + "@" + x.startOffset.ToStr() + "/" + fb.Join(",")
end function

function sig(n as object) as string
  i = n.item
  d = ""
  if i.type = "video" then
    d = i.src.id
  else if i.type = "up-next" then
    d = "-"
    if i.sting <> invalid then d = i.sting.track
  else if i.type = "ad" then
    d = i.sliceIndex.ToStr()
  else
    h = ""
    if i.half <> invalid then h = i.half
    cb = "-"
    if i.channelBump <> invalid then cb = i.channelBump.id
    pb = "-"
    if i.platformBump <> invalid then pb = i.platformBump.id
    d = h + "|" + cb + "|" + pb + "|" + aud(i.channelAudio) + "|" + aud(i.platformAudio)
  end if
  return n.key + "|" + i.type + "|" + n.startMs.ToStr() + "|" + n.endMs.ToStr() + "|" + d
end function
