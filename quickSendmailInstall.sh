Commands to implement:
sudo yum install -y make sendmail sendmail-cf
sudo cp /etc/mail/sendmail.mc ~/sendmail.mc.copy
sudo cp /etc/mail/sendmail.cf ~/sendmail.cf.copy
local="local:myfolder"
sudo sed -i "s/smtp.your.provider/$local/g" /etc/mail/sendmail.mc
cd /etc/mail
sudo make sendmail.cf
sudo systemctl start sendmail
sudo systemctl enable sendmail

Commands to add restart of service on failure:
(you must sudo to root to create this file or sudo nano/vi the file creation. An echo into the file is not permitted with sudo)
mkdir -p /etc/systemd/system/sendmail.service.d
sudo su
echo "[Service]" | tee restart.conf
echo "Restart=on-failure" | tee -a restart.conf
echo "RestartSec=60s" | tee -a restart.conf
sudo systemctl daemon-reload
sudo systemctl restart sendmail
sudo systemctl status sendmail
sudo sed -i '/nomail/! s/missingok/&\n    nomail/'  /etc/logrotate.d/syslog

execute_command = "chmod +x {{ .Path }}; {{ .Vars }} sudo -E bash '{{ .Path }}'"
#!/bin/sh

# Exit on error
set -e

# Check if script was ran by root
if [ "${UID}" -ne 0 ]; then
  echo "Script executed without root permissions"
  echo "You must be root to run this program." >&2
  exit 3
fi

yum install -y make sendmail sendmail-cf
cp /etc/mail/sendmail.mc /tmp/sendmail.mc.copy 
cp /etc/mail/sendmail.cf /tmp/sendmail.cf.copy
local="local:myfolder"
sed -i "s/smtp.your.provider/$local/g" /etc/mail/sendmail.mc
cd /etc/mail
make sendmail.cf
systemctl start sendmail
systemctl enable sendmail
mkdir -p /etc/systemd/system/sendmail.service.d
cd /etc/systemd/system/sendmail.service.d
echo "[Service]" | tee restart.conf
echo "Restart=on-failure" | tee -a restart.conf
echo "RestartSec=60s" | tee -a restart.conf
systemctl daemon-reload
systemctl restart sendmail
systemctl status sendmail
