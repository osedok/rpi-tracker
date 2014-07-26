#!/bin/bash
#
#This script exists to check if rpi-tracker is running in order to prevent
#cron from executing the rpi-tracker.sh script concurrently
#
if pidof -x "rpi-tracker.sh"; then
      exit 0
 else
      if pidof ptunnel; then
           killall ptunnel
       else
          /bin/sh -c /root/tracking-engine/rpi-tracker.sh
          exit 0
      fi
fi

exit
