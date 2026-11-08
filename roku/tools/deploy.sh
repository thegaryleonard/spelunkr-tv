#!/bin/bash
# Sideload / control the Spelunkr Roku app.
#   ROKU_IP=192.168.1.50 ROKU_PASS=... ./deploy.sh install      # build zip + install (replaces the dev channel)
#   ROKU_IP=... ROKU_PASS=... ./deploy.sh shot out.jpg          # screenshot of the dev channel
#   ROKU_IP=... ./deploy.sh key Up|Down|Left|Right|Select|Back|Home   # remote keys over ECP
#   ROKU_IP=... ./deploy.sh launch [channel-id]                 # start the dev channel (optionally on a channel)
#   ROKU_IP=... ./deploy.sh log                                 # live BrightScript console (port 8085)
set -e
cd "$(dirname "$0")/.."
: "${ROKU_IP:?set ROKU_IP}"
case "$1" in
  install)
    : "${ROKU_PASS:?set ROKU_PASS (the developer-mode password you chose on the Roku)}"
    python tools/package.py
    curl -s --digest -u "rokudev:$ROKU_PASS" -F "mysubmit=Install" -F "archive=@out/spelunkr-roku.zip" \
      "http://$ROKU_IP/plugin_install" | grep -o -E "Install Success|Identical to previous version|Install Failure[^<]*|Application Received[^<]*" | head -3
    ;;
  shot)
    : "${ROKU_PASS:?set ROKU_PASS}"
    out="${2:-out/roku-shot.jpg}"
    curl -s --digest -u "rokudev:$ROKU_PASS" -F "mysubmit=Screenshot" -F "archive=" -F "passwd=" "http://$ROKU_IP/plugin_inspect" > /dev/null
    curl -s --digest -u "rokudev:$ROKU_PASS" -o "$out" "http://$ROKU_IP/pkgs/dev.jpg?time=$(date +%s)"
    echo "saved $out"
    ;;
  key)    curl -s -X POST "http://$ROKU_IP:8060/keypress/$2" ;;
  launch) if [ -n "$2" ]; then curl -s -X POST "http://$ROKU_IP:8060/launch/dev?contentId=$2&mediaType=live"; else curl -s -X POST "http://$ROKU_IP:8060/launch/dev"; fi ;;
  log)    exec python -c "import socket,sys;s=socket.create_connection(('$ROKU_IP',8085));[sys.stdout.write(s.recv(4096).decode('utf-8','replace')) or sys.stdout.flush() for _ in iter(int,1)]" ;;
  *) echo "usage: $0 install|shot|key|launch|log"; exit 1 ;;
esac
