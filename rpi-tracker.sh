#!/bin/bash

tstamp() {
  date +"%F"_"%H":"%M"
 }

# func requires arguments (username)
chk_usr() {
   if [ "$(whoami)" != "$1" ]; then
       printf "\nyou need to be root\nexiting....\n$(tstamp)\n\n"
       exit
   fi
}

chk_tubes() {
  printf "\nChecking your tubes..."
  if ! ping -c 1 google.com > /dev/null 2>&1  ; then
      if ! ping -c 1 yahoo.com > /dev/null 2>&1  ; then
         if ! ping -c 1 bing.com > /dev/null 2>&1 ; then
             printf "\n\nno tubes detected....\n\n"
         fi
      fi
  fi
  printf "\n\ntubes working....\n\n"

}

chk_usr root
log=/var/log/tracking-log
geo=/root/geo-data
cfgpath="$( cd "$(dirname "$0")" ; pwd -P )"
if [[ ! -e $cfgpath/tracking.conf ]]; then
     printf "the tracking.conf file was not detected on $(tstamp), exiting..." >> $log
     exit
fi
source $cfgpath/tracking.conf

if [ ! -e "$geo" ]; then
     mkdir -p $geo/{gps,net-info,ap-info} > /dev/null 2>&1
fi

if ! gpspipe -r -n 10 > /dev/null 2>&1; then
     service stop gpsd
     killall gpsd
     if ! gpsd $GPSDEVICE -n -F /var/run/gpsd.sock; then
          printf "gpsd failed to restart, is it working? $(tstamp)" >> $log
          exit
     fi
fi

set -e
if ! wlan=$(iwconfig 2>/dev/null | grep -o "^\w*"); then  # you will have to tweak this if your wireless device is listed as ath0
     printf "failed to set wlan variable device not detected, maybe it's ath0? $(tstamp)" >> $log
     exit
fi

if ! ifconfig $wlan > /dev/null 2>&1; then
     printf "wlan not detected on attempt to check if network information exists, exiting $(tstamp)" >> $log
     exit
fi

if ! chk_tubes; then
     gpspipe -r -n 20 >> $geo/gps/"gps-info-$(tstamp)"
     iwlist $wlan scanning | grep -A 5 Cell >> $geo/ap-info/"ap-$(tstamp)"
     exit 0
fi

gpspipe -r -n 15 >> $geo/gps/"gps-info-$(tstamp)"
ifconfig $wlan | grep $wlan >> $geo/net-info/"net-$(tstamp)"
arp -n | awk '!/Address/{print $1,$3}' >> $geo/net-info/"net-$(tstamp)"
iwlist $wlan scanning | grep -A 5 Cell >> $geo/net-info/"net-$(tstamp)"

if [ $PINGTN == "on" ]; then

    ptunnel -p $PTIP -lp 443 -da $IP -dp $PORT -c $wlan -x $PASS &
    if [ $? -ne 0 ]; then
            printf "\nptunnel failed to establish ping tunnel, exiting... $(tstamp)" >> $log
            killall ptunnel
            exit
      elif rsync -avz -e "ssh -p 443" "$geo" "$USR"@"$IP":~/; then  # created check for retry without ptunnel
            killall ptunnel
            srm -rfz $geo/ > /dev/null 2>&1
            exit 0
      else
           killall ptunnel
           if ! rsync -avz -e "ssh -p $PORT" "$geo" "$USR"@"$PTIP":~/; then  # possible option (-o StrictHostKeyChecking=no) but it's best to import key fingerprint.
                   printf "\nping tunnel failed & rsync failed to upload to "$PTIP" without tunnel, exiting... $(tstamp)" >> $log
                   exit
              else
                   srm -rfz $geo > /dev/null 2>&1
                   exit 0
           fi
    fi
fi

if [ $PINGTN == "off" ]; then
    if ! rsync -avz -e "ssh -p $PORT" "$geo" "$USR"@"$IP":~/; then
          printf "\nrsync failed to upload to server, exiting $(tstamp)" >> $log
          exit
      else
          srm -rfz $geo > /dev/null 2>&1
          exit 0
    fi
fi

exit
