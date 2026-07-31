#Only used when Logs are going to Log anaylitcs workspace 
#and being exported to storage with data export to assure the logs are kept for the required time.

#!/bin/bash

if [ -e /etc/redhat-release ]; then
#Backup the files being updated
cp /etc/logrotate.conf ~/logrotate.conf
cp /etc/logrotate.d/syslog ~/syslog

echo "Updating rhel logrotate files"

#Add or alter the lines in the global conf file
#Removing lines and readding
sudo sed -Ei '/^(rotate)/d' /etc/logrotate.conf
sudo sed -Ei '/(backlogs)/d'  /etc/logrotate.conf

sudo sed -i '/keep 2/! s/^weekly/&\n\n#Keep 2 weeks worth of backups/'  /etc/logrotate.conf
sudo sed -i '/rotate 2/! s/#Keep 2 weeks worth of backups/&\nrotate 2/'  /etc/logrotate.conf

#Uncomment the compress line if it is compressed
sudo sed -i 's/#compress/compress/g' /etc/logrotate.conf
sudo sed -i 's/#dateext/dateext/g' /etc/logrotate.conf

#Add the lines by line number in the syslog specific rotate file

sudo sed -i '/delaycompress/! s/missingok/&\n    delaycompress/'  /etc/logrotate.d/syslog
sudo sed -i '/^s{4}compress$/! s/missingok/&\n    compress/'  /etc/logrotate.d/syslog
sudo sed -i '/daily/! s/missingok/&\n    daily/'  /etc/logrotate.d/syslog
sudo sed -i '/size 100M/! s/missingok/&\n    size 100M/'  /etc/logrotate.d/syslog
sudo sed -Ei '/^s{4}weekly$/d' /etc/logrotate.d/syslog
sudo sed -Ei '/(^s{4}rotate)/d' /etc/logrotate.d/syslog
sudo sed '/rotate 14/! s/missingok/&\n    rotate 14/'  /etc/logrotate.d/syslog

#Clean out weekly rotation if it exists
sudo sed -Ei '/(weekly)/d'  /etc/logrotate.d/syslog

fi

if grep ID=ubuntu /etc/os-release| grep -v grep; then
#Backup the files being updated
cp /etc/logrotate.conf ~/logrotate.conf
cp /etc/logrotate.d/rsyslog ~/rsyslog

echo "Updating Ubuntu logrotate files"

#Add or alter the lines in the global conf file
#Removing lines and readding
       if grep -E '^(rotate)' /etc/logrotate.conf | grep -v grep; then
              sed -Ei '/^(rotate)/d' /etc/logrotate.conf
              sed -Ei '/(backlogs)/d'  /etc/logrotate.conf
       fi

       sed -i '9i\#keep 2 weeks worth of backlogs\r' /etc/logrotate.conf
       sed -i '10i\rotate 2\r' /etc/logrotate.conf

#Uncomment the date extention and compress lines if they are compressed
       sed -i "s/#dateext/dateext/g" /etc/logrotate.conf
       sed -i "s/#compress/compress/g" /etc/logrotate.conf

 #Alter rsyslog specific rotate file
       sed -Ei "/(^\t{1}rotate)/d" /etc/logrotate.d/rsyslog
       sed -i '3i\       rotate 2'  /etc/logrotate.d/rsyslog
       sed -i '27i\       rotate 2'  /etc/logrotate.d/rsyslog
       sed -Ei "s/(daily)/weekly/g" /etc/logrotate.d/rsyslog
fi
