#########################################################################################
# SCENARIO 19: Let's talk about protocols & access modes !
#########################################################################################

"What protocol would you recommend for my environment ?"  

This is a question I often get. Kubernetes being mostly IP based, Astra Trident supports NFS & iSCSI, both compatible with ReadWriteMany (RWX), ReadWriteOnce (RWO) & ReadOnlyMany (ROX) workloads. Most people think block storage (iSCSI) when it comes to RWO & NFS when it comes to RWX, however we also support RWO with NFS & RWX with iSCSI (note that this requires the app to own the filesystem).  

So, short answer to the aforementioned question:  
=> "It depends !".  
A more complete answer could be:  
=> "The application type is a good indicator of what access mode & protocol to use, however NFS can cover most workloads"

We will cover in this chapter various topics all focused on protocols & access modes.

[1.](1_NFS_Benefits) What benefits can RWX & NFS bring over RWO?  
[2.](2_Security_Contexts) About Security Contexts  
