#########################################################################################
# ADDENDA 9: How to install & prepare HAProxy
#########################################################################################

If you need a HTTP or TCP Proxy, HAProxy can be an easy solution to deploy. It can also be used as a LoadBalancer.  
This page will provide you with a step-by-step way to install HAProxy as a RHEL Service, as well as enabling its logs.

```bash
yum install -y haproxy-1.5.18
```

That's it, already installed!  
Let's configure a simple way to read its logs, with rsyslog.  

First, we will create a new entry in rsyslog that will retrieve logs from HAProxy & write them in a specific file

```bash
$ cat <<EOF >> /etc/rsyslog.d/99-haproxy.conf
\$AddUnixListenSocket /var/lib/haproxy/dev/log
# Send HAProxy messages to a dedicated logfile
:programname, startswith, "haproxy" {
  /var/log/haproxy.log
  stop
}
EOF

$ mkdir /var/lib/haproxy/dev
```

HAProxy comes with a default configuration file. Let's save it & modify it to send the logs to the right place.

```bash
$ cp /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg.bak
$ sed -i '26 s/^    /    #/' /etc/haproxy/haproxy.cfg
$ sed -i '26 a \    log         /dev/log local0' /etc/haproxy/haproxy.cfg
```

Finally, we can start HAProxy & restart the log system

```bash
systemctl enable haproxy && systemctl start haproxy
systemctl restart rsyslog
```

In you want to check that all is well, you can look the ports that are listening & perform to test to see some logs.  
By default, a frontend listens on port 5000, let's see what we get:

```bash
netstat -aon | grep -e 5000
tcp        0      0 0.0.0.0:5000            0.0.0.0:*               LISTEN      off (0.00/0/0)
```

Something is listening! Let's try to reach this port

```bash
$ curl localhost:5000
<html><body><h1>503 Service Unavailable</h1>
No server is available to handle this request.
</body></html>
```

It fails, as expected, since there isn't really anything to forward the call to.  
However, let's look at the logs:

```bash
$ more /var/log/haproxy.log | grep 503
Mar  9 18:06:11 rhel6 haproxy[9113]: 127.0.0.1:49992 [09/Mar/2021:18:06:11.823] main app/<NOSRV> 0/-1/-1/-1/0 503 212 - - SC-- 0/0/0/0/0 0/0 "GET / HTTP/1.1"
```

There you go. You can see the call that led to a HTTP 503 error.
