sub main()
  spInitBits()
  ts = CreateObject("roTimespan")
  L = ParseJson(ReadAsciiFile("pkg:/fixtures/lineup.json"))
  c = L.channels[0]
  p = c.versions[0]
  txt = ReadAsciiFile("pkg:/fixtures/" + p.manifest)
  print "read "; ts.TotalMilliseconds() : ts.Mark()
  mf = ParseJson(txt)
  print "parse "; ts.TotalMilliseconds(); " len "; Len(txt) : ts.Mark()
  plat = ParseJson(ReadAsciiFile("pkg:/fixtures/" + mf.platform))
  print "parse plat "; ts.TotalMilliseconds() : ts.Mark()
  v = spVersionFrom(mf, plat, p)
  pl = spMakePlaylist(c.id, [v])
  print "version "; ts.TotalMilliseconds() : ts.Mark()
  n = spNowAt(pl, 1793498284943&)
  print "first nowAt "; ts.TotalMilliseconds(); " cycles "; pl.versions[0].fwd.Count() : ts.Mark()
  n = spNowAt(pl, n.endMs)
  print "second nowAt "; ts.TotalMilliseconds() : ts.Mark()
  e = pl.versions[0]
  for i = 1 to 50 : x = spCycleList(e, 0, { cycleStartMs: e.epochMs }) : end for
  print "50 cycle builds "; ts.TotalMilliseconds(); " entries "; x.Count()
end sub
