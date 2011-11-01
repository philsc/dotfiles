#!/usr/bin/env bash

stopawesome()
{
  export DISPLAY=:1.0
  echo 'awesome.quit()' | awesome-client
}

trap stopawesome 1 2 15

rcfile=$XDG_CONFIG_HOME/awesome/rc.lua
resolution=1280x800

while getopts ":c:r:" opt; do
  case "$opt" in
    c)
      rcfile=$OPTARG
      ;;
    r)
      resolution=$OPTARG
      ;;
    *)
      echo "Unknown parameter '$opt'."
      echo ""
      echo "Usage: $0 [-c RCFILE] [-r CUSTOMRESOLUTION]"
      ;;
  esac
done

if ! pgrep Xephyr &> /dev/null; then
  echo "awful.util.spawn('Xephyr -ac -br -noreset -screen $resolution :1')" | awesome-client
  sleep 1
fi

DISPLAY=:1.0 awesome -c $rcfile

