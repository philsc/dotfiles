#!/usr/bin/env bash

# Emulate a lightdm login
"$HOME/.xprofile"

# Now start awesome
exec awesome
