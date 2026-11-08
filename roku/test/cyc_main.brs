sub main()
  spInitBits()
  L = ParseJson(ReadAsciiFile("pkg:/fixtures/lineup.json"))
  for each c in L.channels
    if c.id = "rocket-punch" then
      vs = []
      for each p in c.versions
        mf = ParseJson(ReadAsciiFile("pkg:/fixtures/" + p.manifest))
        plat = ParseJson(ReadAsciiFile("pkg:/fixtures/" + mf.platform))
        vs.Push(spVersionFrom(mf, plat, p))
      end for
      pl = spMakePlaylist(c.id, vs)
      n = spNowAt(pl, 1793498284943&)
      b = pl.versions[0].built[n.cycle.ToStr()]
      lines = []
      for each e in b.entries
        d = ""
        if e.type = "ad" then
          d = e.sliceIndex.ToStr()
        else if e.type = "video" then
          d = e.src.id
        else
          cb = "" : pb = ""
          if e.channelBump <> invalid then cb = e.channelBump.id
          if e.platformBump <> invalid then pb = e.platformBump.id
          d = cb + "/" + pb
        end if
        lines.Push(e.key + "|" + e.type + "|" + e.durMs.ToStr() + "|" + d)
      end for
      WriteAsciiFile("pkg:/cyc_brs.txt", lines.Join(Chr(10)) + Chr(10))
    end if
  end for
end sub
