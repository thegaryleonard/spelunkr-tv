sub redraw()
    m.top.removeChildrenIndex(m.top.getChildCount(), 0)
    lg = m.top.logo
    if lg = invalid or lg.n = invalid or lg.n = 0 then return
    s = m.top.size / lg.n
    for each r in lg.rects
      rc = m.top.createChild("Rectangle")
      rc.translation = [r.x * s, r.y * s]
      rc.width = r.w * s + 0.5
      rc.height = r.h * s + 0.5
      rc.color = r.c
    end for
  end sub
