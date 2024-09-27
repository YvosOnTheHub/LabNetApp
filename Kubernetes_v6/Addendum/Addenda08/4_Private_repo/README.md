#########################################################################################
# ADDENDA 8: Use a private Docker registry
#########################################################################################

Organizations may not necessarily give direct access to public repositories, mainly for security reasons.  
Instead, they may pull images on a specific host, audit them & potentially push them in a private repository.  

The LabOnDemand has a private repository: registry.demo.netapp.com.  

Then, you may want to pull public images, populate the local repository & modify your applications YAML files to point to it!  
Let's see how to do this.  

We will log into Docker, pull an image locally (busybox:1.33), tag & push it into the local repository

```bash
$ podman login -u my_user -p my_password
Login Succeeded

$ podman pull docker.io/busybox:1.33.0
1.33.0: Pulling from library/busybox
524791274d4f: Pull complete
Digest: sha256:cde96a6db8ba29d051b91de849f6240e8aac5bcaf559e8cc5286183264cd8d48
Status: Downloaded newer image for busybox:1.33.0

$ podman images -f reference='busybox' -f reference='*/busybox'
REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
busybox                            1.33.0              af0f90b2d710        6 hours ago         1.24MB

$ podman tag docker.io/busybox:1.33.0 registry.demo.netapp.com/busybox:1.33.0

$ podman images -f reference='busybox' -f reference='*/busybox'
REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
busybox                            1.33.0              af0f90b2d710        6 hours ago         1.24MB
registry.demo.netapp.com/busybox   1.33.0              af0f90b2d710        6 hours ago         1.24MB

$ podman push registry.demo.netapp.com/busybox:1.33.0
The push refers to repository [registry.demo.netapp.com/busybox]
6c199d37e39d: Pushed
1.33.0: digest: sha256:4fd7b9462c21b36d48f0fc853a98cce91d15befba8fdd1363e880bcbb4cabb1b size: 527
```

At this point, we have populated a new image in our local registry.  
We can test this by lauching a new POD **on rhel3** that uses this image.  
We will use busybox to ping the ONTAP Management LIF.  
```bash
$ docker images -f reference='*/busybox'
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE

$ kubectl run -i --tty ping --image=registry.demo.netapp.com/busybox:1.33.0 --restart=Never -- ping 192.168.0.133
If you dont see a command prompt, try pressing enter.
64 bytes from 192.168.0.133: seq=1 ttl=63 time=0.291 ms
64 bytes from 192.168.0.133: seq=2 ttl=63 time=0.365 ms
^C
--- 192.168.0.133 ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.291/0.622/1.210 ms

$ docker images -f reference='*/busybox'
REPOSITORY                         TAG                 IMAGE ID            CREATED             SIZE
registry.demo.netapp.com/busybox   1.33.0              af0f90b2d710        23 hours ago        1.24MB

$ kubectl describe pod ping | grep Events: -A 7
Events:
  Type    Reason     Age        From               Message
  ----    ------     ----       ----               -------
  Normal  Scheduled  <unknown>  default-scheduler  Successfully assigned default/ping to rhel3
  Normal  Pulling    118s       kubelet, rhel3     Pulling image "registry.demo.netapp.com/busybox:1.33.0"
  Normal  Pulled     118s       kubelet, rhel3     Successfully pulled image "registry.demo.netapp.com/busybox:1.33.0"
  Normal  Created    118s       kubelet, rhel3     Created container ping
  Normal  Started    118s       kubelet, rhel3     Started container ping

$ kubectl del pod ping
pod "ping" deleted
```

It works !  
You proved that the busybox image was pulled from the local repository!

If you like this method, you can reproduce it for all scenarios.
