#########################################################################################
# SCENARIO 6: Tests scenario with Hooks
#########################################################################################  

Trident Protect allows you to interact with your apps in various use cases so that you get consistent protections.  

There are 2 ways to visualize snapshots:
- Crash Consistent Snapshots: similar to removing the plug from you wall. May end up with some data _floating in the air_  
- Application Consistent Snapshot: puts your app in a "quiesce" or "hot backup" state while taking a snapshot, which then contains all of the data   

The second one is often required with databases, where some data sits in a buffer or a cache before being pushed to the storage.

Interacting with applications is done with scripts or **hooks** which you need to configure.  
NetApp provides a library of open-source hooks available on the following repo: https://github.com/NetApp/Verda  

Trident Protect supports the following types of execution hooks, based on when they will run in the protection process:  
- Pre-snapshot  
- Post-snapshot  
- Pre-backup  
- Post-backup  
- Post-restore  
- Post-failover  

This scenario can be used to see how those hooks work & the result you can expect:  
[1.](1-Snapshots) Snapshots  
[2.](2-Post-Restore) Post Restore  
[3.](3-Post-Failover) Post Failover  