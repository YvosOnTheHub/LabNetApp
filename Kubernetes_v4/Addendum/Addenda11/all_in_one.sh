#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL & CONFIGURE HAPROXY"
echo "#"
echo "#######################################################################################################"
echo

yum install -y haproxy-1.5.18

echo "#######################################################################################################"
echo "# Create a HAProxy log entry for Syslog"
echo "#######################################################################################################"
echo

cat <<EOF >> /etc/rsyslog.d/99-haproxy.conf
\$AddUnixListenSocket /var/lib/haproxy/dev/log
# Send HAProxy messages to a dedicated logfile
:programname, startswith, "haproxy" {
  /var/log/haproxy.log
  stop
}
EOF
mkdir /var/lib/haproxy/dev

echo "#######################################################################################################"
echo "# Modify HAProxy logging configuration"
echo "#######################################################################################################"
echo

cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
sed -i '26 s/^    /    #/' /etc/haproxy/haproxy.cfg
sed -i '26 a \    log         /dev/log local0' /etc/haproxy/haproxy.cfg

echo "#######################################################################################################"
echo "# Start HAProxy & Restart Rsyslog"
echo "#######################################################################################################"
echo
systemctl enable haproxy && systemctl start haproxy
systemctl restart rsyslog