sub main()
  spInitBits()
  mf = ParseJson(ReadAsciiFile("pkg:/fixtures/manifests/rocket-punch/v10.json"))
  plan = spAdPlan(mf.ads.slices, mf.items, invalid, 1200000&, "rocket-punch", mf.ads.start, mf.ads.decades)
  out = []
  out.Push("start " + plan.start.ToStr())
  out.Push("cycle " + Str(plan.rates.cycleMs).Trim() + " total " + plan.rates.total.ToStr())
  ph = []
  for i = 0 to 19 : ph.Push(plan.phases[i].ToStr()) : end for
  out.Push("phases " + ph.Join(","))
  for each y in [invalid, 1981, 1985, 1987, 1992, 2026]
    for each t in spTiers(plan, y)
      f = []
      for i = 0 to 7 : f.Push(t.list[i].ToStr()) : end for
      tl = "Infinity"
      if t.tol <> invalid then tl = t.tol.ToStr()
      ys = "null"
      if y <> invalid then ys = y.ToStr()
      out.Push("tier " + ys + " tol=" + tl + " n=" + t.list.Count().ToStr() + " round=" + t.roundMs.ToStr() + " healthy=" + LCase(t.healthy.ToStr()) + " first=" + f.Join(","))
    end for
  end for
  WriteAsciiFile("pkg:/ads_brs.txt", out.Join(Chr(10)) + Chr(10))
end sub
