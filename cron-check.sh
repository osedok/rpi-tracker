#!/bin/bash
#
if pidof -x "rpi-tracker.sh"; then
   exit
 else
     if pidof ptunnel; then
        killall ptunnel
      else
        /bin/sh -c /root/rpi-tracker/rpi-tracker.sh
        exit
    fi
fi
exit
