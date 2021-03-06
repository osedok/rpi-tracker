# rpi-tracker

An attempt to eliminate the need of third parties for remote gps tracking.

This bash script configures the raspberry pi to log data from a
TTL serial GPS device and surrounding WiFi access points, 
for additional geolocation. The script uploads this data to an ssh 
server after establishing an internet connection using wpa_supplicant, 
which is set to roam for open WiFi access points.

The GPS logs are in NMEA format and can be used with any software 
that supports it.

The GPS logs along with other information is stored in the 
/root/geo-data to be stage for upload. The data is then deleted 
upon a successful upload.

It also has an option if desired to use an icmp tunnel for uploading data 
using the ptunnel package. In order to use this feature you need to have 
a ptunnel proxy for your device (rpi) to establish the tunnel.

## INSTALL
This script is made for the raspberry pi, to use on other platforms
one will need to specifiy the gps device using the GPSDEVICE variable. 
  
you first will need to edit the variable options in tracker.conf
then run install.sh as root/sudo the necessary files will be
placed in /root/tracking-engine/ 

Configuration changes must be made to tracking.conf the install.sh
will not function with default variables.

## Variable Options in tracking.conf   

GPSDEVICE - for the GPIO pins on the RPi is /dev/ttyAMA0
for USB devices it *may* be /dev/ttyUSB0

PINGTN - (on || off)  This activates the option to use a ping tunnel

PTIP - ptunnel proxy IP, if the PINGTN option is on this is required 

PASS - password for the ptunnel password

USR - username to be used with ssh

KCHK - (yes || no ) if yes you will manually have to import the ssh key fingerprint. If no importation is automatic.

PORT - the configured port for ssh, the default is 22

IP - IP address or domain of ssh reporting server

This is were it can get tricky if also using ptunnel. Depending on 
your set up you may have a dedicated ptunnel proxy and a separate 
dedicated ssh server each with there own IP addresses. 
 
 For example: 

 |rpi:1.1.1.1|->--->---->--|PTIP:3.3.3.3|-->-->-->-|IP:5.5.5.5:22| 


But if the if the ptunnel proxy is also used for ssh then 
it would look like this.

 |rpi.1.1.1.1|->--->---|PTIP:3.3.3.3//IP:localhost:22| 

This script is designed for having the ptunnel proxy on the same 
server as the ssh service otherwise you will have to edit the 
scripts if failed statement. If the tunnel fails it will 
retry to connect directly to the PTIP variable without a tunnel. 
 

## IMPORTANT

The authentication for ssh relies on public keys so these must be 
imported manually to the server from the client device (rpi).

Create them with ssh-keygen and import the id_rsa.pub to 
the ~/.ssh/authorized_keys of the specified user in the 
reporting server, don't use server root for this.

Don't forget about the server's ssh fingerprint.

This can be done using ssh-keyscan

```
ssh-keyscan -p port -t rsa,ecdsa "server_ip_or_domain" >> ~/.ssh/know_hosts
```

The port option is metioned due to it's relevance when you are using the
ptunnel option. You will need to import the fingerprint when you
log into the ssh server through the tunnel even though you may
already have sshed to it directly, as the ip/domain will be different 
(127.0.0.1/localhost). 

You can hash these inputs in the know_hosts file with 
the "ssh-keygen -H" option. 

Also when using ptunnel the know_hosts fingerprint may still prompt 
you since it detects a different ip than when ssh into the server
without a tunnel so either use the above method and change the ip 
to localhost in the know_hosts file before hashing it or log in manually 
once to the server through the tunnel to update this file or just turn 
off the fingerprint checks by turning off stricthostkeychecking option 
in the global /etc/ssh/ssh_config (not recommended).


For specifics on using ptunnel use the --help option for details. 
Be sure to run it with a password if using it as a proxy to prevent 
just anyone from using it.

To run it from boot one can use cron.

```
@reboot root /usr/bin/ptunnel -x "some_password" &
```

## PROBLEMS?
Be aware that some routers throttle ping traffic due to DOS mitigation 
firewall rules which may prevent the ping tunnel from being established.

for example
ACCEPT   icmp  --  *   *   0.0.0.0/0   0.0.0.0/0   limit: avg 1/sec burst 5 

[keep in mind that the ping tunnel feature is designed to increase the 
percentage of usable access points and will not work on all routers.]

Also ptunnel is set by the script to listen on the wlan interfaces so if 
you want to test it over an wired interface (eth0) you will have to 
edit the following from rpi-tracker.sh.

```
FROM: ptunnel -p $PTIP -lp 443 -da $IP -dp $PORT -c $wlan -x $PASS &
  TO: ptunnel -p $PTIP -lp 443 -da $IP -dp $PORT -c eth(your number) -x $PASS &   
```
As stated before this uses wpa_supplicant for managing wireless 
connections. To add known WiFi networks refer to [man wpa_supplicant.conf] 
in the terminal for precise details on how to best do this.

For more info visit nightowlconsulting.com
