#!/usr/bin/env bash

usage()
{
      echo "Usage: $0 [-c RCFILE] [-r CUSTOMRESOLUTION]"
}

rcfile=$XDG_CONFIG_HOME/awesome/rc.lua
resolution=1280x800

while getopts ":hc:r:" opt; do
  case "$opt" in
    h)
      usage
      exit 0
      ;;
    c)
      rcfile=$OPTARG
      ;;
    r)
      resolution=$OPTARG
      ;;
    *)
      echo -e "Unknown parameter:  -$OPTARG\n" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if ! pgrep Xephyr &> /dev/null; then
  # Get an absolute path of the config file
  rcfile="$(readlink -f $rcfile)"

  # Start a windowed X server
  Xephyr -ac -br -noreset -screen $resolution :1 &> /dev/null &
  sleep 1
  disown

  # Start awesome in the new X server
  cd
  export DISPLAY=:1.0
  awesome -c $rcfile &
else
  # If awesome is already running in the new X server, simply restart awesome
  export DISPLAY=:1.0
  echo "awesome.restart()" | awesome-client
fi

