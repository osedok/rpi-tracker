#!/bin/bash
#
#-------------------------------------------------------------------------------------------------------------------------
# IGNORE IF NOT USING TUNNELING
PINGTN='off'           # (on/off) enable only if your monitoring server is setup with ping tunnel
PTIP='x.x.x.x'         # IP or domain of ping tunnel
PASS='your-password'   # password your ping tunnel proxy is set up with
#The listening port on the client (rpi) for the ping tunnel is port 80
# you can change this manually on line 292
#-------------------------------------------------------------------------------------------------------------------------
# SSH SERVER SETTINGS FOR RSYNC UPLOAD
USR='foo'              # Change this to the user name that exists on your ssh monitoring server
IP='127.0.0.1'         # IP of ssh server (USE localhost IF it's the SAME IP for the ping tunnel proxy as the ssh server)
PORT='22'              # default port number for ssh, change if different
#-------------------------------------------------------------------------------------------------------------------------
#

tstamp() {
  date +"%F"_"%H":"%M"
 }

shell=$(whoami)
if [ $shell != root ]; then

     printf "\nYou need to be root, exiting\n\n"
     exit
fi

if [[ $PINGTN != 'on' && $PINGTN != 'off' ]]; then

       unset PINGTN
       PINGTN=off
       printf "You probably changed the ping tunnel values incorrectly, turning it off $(tstamp)\n" >> pingtn-error
       printf "\nYou probably changed the ping tunnel values incorrectly, ignoring values until corrected.\n"
       sleep 2

fi

# Performing check if already configured previously if not installing packages.

if [ ! -f "/var/log/first-run" ]; then  # DONT remove this file unless you want to break the cron job.

    if [ $USR == 'foo' ]; then

             printf "\nYou have not changed the server user name, check the ip address, port number as well.\n\n"
             exit
       else

          if [ $PINGTN == "on" ]; then

               printf "\n\nBy turning the PINGTN option on it means you have a server setup with\na configured ptunnnel service"
               printf "\n\nDo you wish to continue? (y/n) \n"

           while [[ $ans != "n" || $ans != "N" || $ans != "y" || $ans != "Y" ]]; do
                    read ans
             if  [[ $ans == "n" || $ans == "N" ]]; then
                     printf "\n\nexiting....\n"
                     sleep 1
                     exit
               elif  [[ $ans == "y" || $ans == "Y" ]]; then

                    printf "\ncontinuing....\n\n"
                    break
               else
                  printf "\n\n not a valid entry, please try again."
                  printf "\n(y/n)?\n"
             fi
          done
          fi

            printf "\n\nthis script works best with a vanilla .img of Raspbian"
            printf "\nit will make changes to the network configuration, dedicating it to WiFi and gps functions."
            printf "\nif you use this device as a server or for any other services stop the script now!"
            printf "\n\nContinue? (y/n) \n"
       while [[ $ansr != "n" || $ansr != "N" || $ansr != "y" || $ansr != "Y" ]]; do
                   read ansr
            if  [[ $ansr == "n" || $ansr == "N" ]]; then
                   printf "\n\nexiting....\n"
                   sleep 1
                   exit
            elif  [[ $ansr == "y" || $ansr == "Y" ]]; then
                   printf "\ncontinuing....\n\n"
                   break
            else
                  printf "\n\n not a valid entry, please try again."
                  printf "\n(y/n)?\n"
            fi
       done

     # you may have to purge network manager if you run this in another distro

     apt-get update
     if ! apt-get -y install gpsd-clients; then
          printf "\n\nAPT failed to install gpsd-clients, are your repos working?\nexiting...\n\n" && exit

      elif ! apt-get -y install ptunnel; then
           printf "\n\nAPT failed to install ptunnel, are your repos working?\nexiting...\n\n" && exit

      elif ! apt-get -y install secure-delete; then
           printf "\n\nAPT failed to install secure-delete, are your repos working?\nexiting...\n\n" && exit
     fi
      cat >> /var/log/first-run << EOL
first configuration run of rpi-tracker.sh
on $(tstamp)
EOL
    fi
fi


# Setting up cron job which performs periodic updates to server

if [ ! -e "/etc/cron.d/geo-rpi" ]; then


    if ! iwconfig 2>/dev/null | grep -o "^\w*"; then   # you may have to tweak this if your wireless device doesn't start with wlan, for example: ath0

           printf "\nwlan device not detected, have you plugged it in the USB port already? \n\n"
           sleep 1
           exit

      else

        if [ ! -d "/etc/wpa_supplicant/" ]; then

            printf "\n/etc/wpa_supplicant not detected, is it installed? \nExiting..."
            sleep 1
            exit

          else

            printf "\n" > /etc/udev/rules.d/70-persistent-net.rules
            printf "\n\nWarning the pi will reboot as devices are configured."
            printf "\n\nIf your using ssh it's going to hang, heads up\n\n"
            sleep 1

            /etc/init.d/networking restart > /dev/null 2>&1
            ifdown -a
            ifup -a

            set -e
            if ! wlan=$(iwconfig 2>/dev/null | grep -o "^\w*"); then   # you may have to tweak this if your wireless device doesn't start with wlan

                printf "\nfailed to set wlan variable, wlan device not detected, maybe it's ath0? $(tstamp) \n\n" >> /root/rpi-tracker/wlan-error
                sleep 1
                exit

             else

# the following are modifications to set up wireless roaming
# you may add additional network profiles, see (man wpa_supplicant.conf) for details
# do so at your own risk
             cat > /etc/network/interfaces << EOL
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp

allow-hotplug $wlan
iface wlan0 inet manual
wpa-roam /etc/wpa_supplicant/wpa_supplicant.conf
iface default inet dhcp
EOL

# here you can add access point profiles but before doing so read up on the .conf format
             cat > /etc/wpa_supplicant/wpa_supplicant.conf << EOL
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1

network={
       key_mgmt=NONE
}
network={
        ssid="default"
        key_mgmt=NONE
}
EOL
             usermod -a -G netdev root

# here the dhclient settings are set aggressively
             cat > /etc/dhcp/dhclient.conf << EOL
# Configuration file for /sbin/dhclient, which is included in Debian's
# dhcp3-client package.
# the file has been modified to work better for WiFi roaming

backoff-cutoff 1;
initial-interval 1;
#link-timeout 10;
#reboot 0;
retry 10;
select-timeout 0;
timeout 15;

option rfc3442-classless-static-routes code 121 = array of unsigned integer 8;

request subnet-mask, broadcast-address, time-offset, routers,
        domain-name, domain-name-servers, domain-search, host-name,
        netbios-name-servers, netbios-scope, interface-mtu,
        rfc3442-classless-static-routes, ntp-servers,
        dhcp6.domain-search, dhcp6.fqdn,
        dhcp6.name-servers, dhcp6.sntp-servers;
EOL

# enabling GPIO UART for use by TTL Serial GPS device
             cat > /boot/cmdline.txt <<  EOL
dwc_otg.lpm_enable=0 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=deadline rootwait
EOL

             sed -i 's/T0:23:respawn:\/sbin\/getty -L ttyAMA0/#T0:23:respawn:\/sbin\/getty -L ttyAMA0/' /etc/inittab

# the cron job, once created the above configurations to the interface and wpa-roam.conf will not repeat.

             cat > /etc/cron.d/geo-rpi << EOL
PATH=/sbin:/usr/sbin:/bin:/usr/bin

@reboot root /usr/sbin/gpsd /dev/ttyAMA0 -n -F /var/run/gpsd.sock
* * * * * root /bin/sh -c /root/rpi-tracker/cron-check.sh
EOL

            ifdown eth0 && ifup eth0
            ifdown $wlan && ifup $wlan
            reboot -f
          fi
        fi
   fi
fi


#-------------------------------------------------------------------------------------------------------------
# The cron job executes the following after the first two files are detected.
# if you wish you may seperate this into another stand alone script after the nessary configurations are made.

if [ ! -d "/root/geo/" ]; then

    mkdir -p /root/geo/{gps,net-info,ap-info} > /dev/null 2>&1

  else
    if ! gpspipe -r -n 10 > /dev/null 2>&1; then

         service stop gpsd
         killall gpsd
         if ! gpsd /dev/ttyAMA0 -n -F /var/run/gpsd.sock; then
              printf "gpsd failed to restart, is it working? $(tstamp)" >> /root/geo/error-log
              exit
         fi
    fi
    set -e
    if ! wlan=$(iwconfig 2>/dev/null | grep -o "^\w*"); then  # you will have to tweak this if your wireless device is listed as ath0

           printf "failed to set wlan variable device not detected, maybe it's ath0? $(tstamp)" >> /root/geo/error-log
           exit

     else

        if ! ifconfig $wlan > /dev/null 2>&1; then

           printf "wlan not detected on attempt to log network information, exiting $(tstamp)" >> /root/geo/error-log
           exit

           elif ! ping -c 1 google.com > /dev/null 2>&1; then

               gpspipe -r -n 20 >> /root/geo/gps/gps-info-$(tstamp)
               iwlist $wlan scanning | grep -A 5 Cell >> /root/geo/ap-info/ap-$(tstamp)
               exit

           else
                gpspipe -r -n 15 >> /root/geo/gps/gps-info-$(tstamp)
                ifconfig $wlan | grep $wlan > /root/geo/net-info/net-$(tstamp)
                arp -n | awk '!/Address/{print $1,$3}' >> /root/geo/net-info/net-$(tstamp)
                iwlist $wlan scanning | grep -A 5 Cell >> /root/geo/net-info/net-$(tstamp)

                if [ $PINGTN == "on" ]; then


                             ptunnel -p $PTIP -lp 80 -da $IP -dp $PORT -c $wlan -x $PASS &
                             if [ $? -ne 0 ]; then

                                   printf "\nptunnel failed to establish ping tunnel, exiting... $(tstamp)" >> /root/geo/error-log
                                   killall ptunnel
                                   exit
                              else

                                   if rsync -avz -e "ssh -p 80" /root/geo "$USR"@"$IP":~/; then  # created check for retry without ptunnel

                                      killall ptunnel
                                      srm -rfz /root/geo > /dev/null 2>&1
                                      exit

                                    else

                                      killall ptunnel
                                       if ! rsync -avz -e "ssh -p $PORT" /root/geo "$USR"@"$PTIP":~/; then   # possible option (-o StrictHostKeyChecking=no) but it's best to import key fingerprint.

                                             printf "\nping tunnel failed & rsync failed to upload to "$PTIP" without tunnel, exiting... $(tstamp)" >> /root/geo/error-log
                                             exit
                                         else
                                             srm -rfz /root/geo > /dev/null 2>&1
                                             exit
                                       fi
                                  fi

                             fi

                 elif [ $PINGTN == "off" ]; then

                            if ! rsync -avz -e "ssh -p $PORT" /root/geo "$USR"@"$IP":~/; then   # possible option (-o StrictHostKeyChecking=no) but it's best to import key fingerprint

                                   printf "\nrsync failed to upload to server, exiting $(tstamp)" >> /root/geo/error-log
                                   exit
                              else
                                   srm -rfz /root/geo > /dev/null 2>&1
                                   exit
                            fi

                fi

        fi

    fi

fi
exit
