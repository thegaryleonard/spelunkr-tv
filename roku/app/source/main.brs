sub Main(args as dynamic)
  screen = CreateObject("roSGScreen")
  port = CreateObject("roMessagePort")
  screen.SetMessagePort(port)
  scene = screen.CreateScene("MainScene")
  ' deep link: contentId = channel id (e.g. "dusty-trails")
  if args <> invalid and args.contentId <> invalid then scene.launchChannel = args.contentId
  screen.Show()
  scene.ObserveField("exitApp", port)
  while true
    msg = wait(0, port)
    t = type(msg)
    if t = "roSGScreenEvent" then
      if msg.IsScreenClosed() then return
    else if t = "roSGNodeEvent" then
      if msg.GetField() = "exitApp" and msg.GetData() = true then return
    end if
  end while
end sub
