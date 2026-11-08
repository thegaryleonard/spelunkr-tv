sub render()
    d = m.top.data
    sel = m.top.selected
    bg = m.top.findNode("bg")
    if sel then
      bg.color = "0x2A3A8CFF"
    else if m.top.odd then
      bg.color = "0x1D2352FF"
    else
      bg.color = "0x21285AFF"
    end if
    m.top.findNode("sel").visible = sel
    if d = invalid then return
    m.top.findNode("num").text = d.num
    m.top.findNode("name").text = d.name
    m.top.findNode("logo").logo = d.logo
    m.top.findNode("nowT").text = d.nowT
    m.top.findNode("nowM").text = d.nowM
    m.top.findNode("nxtT").text = d.nxtT
    m.top.findNode("nxtM").text = d.nxtM
    m.top.findNode("playing").visible = (d.playing = true)
    if sel then
      m.top.findNode("nowM").color = "0x8FFDFAFF"
    else
      m.top.findNode("nowM").color = "0xA8A8FFFF"
    end if
  end sub
