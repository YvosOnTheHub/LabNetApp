#########################################################################################
# SCENARIO 29: Space Management
#########################################################################################

**GOAL:**  
Follow a volume from the day Trident creates it to the day it is full.  
Provisioning, writes, deletes, snapshots and clones each change a different number, and those numbers rarely move together.  
That gap is where applications hit _No space left on device_ while `kubectl get pvc` still looks healthy.  

Two mechanisms can grow the volume before that happens. The first two folders run each one on its own. The third runs both on the same `ontap-san-economy` pool:  
[1.](1-autogrow-policy) Trident Autogrow Policy  
[2.](2-ontap-volume-autosize) ONTAP volume autosize  
[3.](3-san-economy-both) Both mechanisms on ontap-san-economy  

Manual resize was covered in [Scenario09](../Scenario09).  
Snapshots and clones were covered in [Scenario13](../Scenario13).  
What follows is the space accounting that sits underneath both.  

## A. Three numbers, one volume

Keep three figures in mind. They answer three different questions.  

| What you look at | The question it answers |
| :--- | :--- |
| `kubectl get pvc` (CAPACITY) | How big did someone _request_? |
| `df` inside the pod | How much of the filesystem can the application still use? |
| ONTAP volume used space | How many blocks does this volume hold on the aggregate, including blocks kept by snapshots? |

Kubernetes stores the first number on the PVC and on the PV.  
It does not update that number when the application writes, deletes, or takes a snapshot.  
Core Kubernetes also does not expand a volume because the filesystem is getting full.  
Someone, or something, has to do that on purpose.  

## B. Provisioning

A PVC request is a ceiling. Trident turns it into storage:  

- **ontap-nas** and **ontap-nas-flexgroup**: a FlexVol of the requested size.  
- **ontap-san**: a LUN of the requested size, inside a FlexVol.  
- **ontap-nas-economy** and **ontap-san-economy**: a qtree or a LUN inside a _shared_ FlexVol. Neighbors in that backing volume consume the same pool of blocks.  

With `spaceReserve: none` (thin provisioning), an empty volume costs almost nothing on the aggregate.  
The size is a promise the client may write up to. Blocks are taken from the aggregate only when data arrives.  

With `spaceReserve: volume` (thick provisioning), ONTAP reserves the space at creation time.  
An empty 100Gi volume already occupies its 100Gi. Deletes later on do not give that reservation back.  

ONTAP also sets aside a snapshot reserve, 5% of the volume unless the backend sets `snapshotReserve` to something else.  
That slice is part of the volume size. It is why a 100Gi NFS volume often shows about 95Gi in `df` the moment it is mounted: the missing piece was never offered to the filesystem.  

A ResourceQuota counts the request, so ten empty 100Gi PVCs look like 1Ti to Kubernetes.  
On a thin aggregate they are still almost free.  
[Scenario08](../Scenario08) is about putting limits on that freedom. This chapter is about what happens to the bytes after the volume exists.  

## C. Data is written

The application writes. Two of the three numbers move.  

`df` inside the pod climbs, because the filesystem has less free space.  
ONTAP used space climbs with it. Deduplication, compression and compaction can make the physical consumption smaller than the logical write, so the two increases are related and still not equal.  
The PVC capacity stays exactly where it was.  

Nothing in the PVC object says "this volume is at 92%".  
Trident can see it, because Trident can ask ONTAP. Kubernetes will not act on it.  
If the filesystem reaches 100%, the next write fails inside the container. The PVC remains `Bound`, with the same capacity it had on day one.  

## D. Data is deleted

Deleting files feels like it should rewind the previous step. It depends on the protocol, and on whether a snapshot still needs those blocks.  

**NFS or SMB, and no snapshot holds the blocks.**  
The client removes the file, ONTAP frees the blocks, `df` drops, volume used space drops.  
The FlexVol keeps its size. The PVC keeps its capacity.  
The freed room can be reused inside that same volume. It is not returned as a smaller claim, and a thick reservation stays reserved.  

**iSCSI or NVMe.**  
The guest filesystem marks the blocks free, so `df` drops.  
The LUN itself still owns the blocks. ONTAP used space stays high until the guest sends SCSI UNMAP (TRIM).  
Trident has to be told to advertise that behavior (`spaceAllocation`), and the guest has to actually unmap.  
Until both are true, the application sees a volume with room in it and the aggregate still carries every block that was ever written.  

**A snapshot still references the deleted file.**  
The blocks leave the active filesystem and stay in the snapshot.  
`df` may recover. The aggregate does not.  
Volume used space only falls when the snapshot that pins those blocks is deleted.  

## E. Snapshots

A CSI VolumeSnapshot creates an ONTAP snapshot.  
Creation itself is metadata. A brand new snapshot of a quiet volume consumes almost no extra space, which is why people start taking them freely.  

The cost shows up at the next modification.  
Any block that is overwritten or deleted is kept for the snapshot. Space grows with _change_, so one snapshot of a busy database can cost more than fifty snapshots of a volume nobody writes to.  

That consumption is charged to the snapshot reserve first.  
Once the snapshots outgrow the reserve, they spill into the active filesystem.  
`df` then shrinks even though the application wrote nothing new, and a delete no longer returns free space to the pod: the blocks are still owed to the snapshot.  
This is the usual "I deleted half the data and the volume is still full" ticket.  

The space comes back when the snapshot is deleted, and only if no clone still depends on it.  
This is the model when the PVC has its own FlexVol (`ontap-nas`, `ontap-san`).  
`ontap-san-economy` does not take a FlexVol snapshot. That difference shows up with the clones.  

## F. Clones

A PVC clone, or a new PVC created from a VolumeSnapshot, is an ONTAP FlexClone.  
The clone and its parent share the same blocks. Creating it is immediate, and the aggregate barely moves.  

Kubernetes does not see the sharing.  
It sees a second PVC, with the same capacity as the source, and a ResourceQuota counts that capacity a second time.  
Ten clones of a 100Gi golden image look like 1Ti requested, while ONTAP stores one copy plus whatever has diverged.  

Two things then eat the saving:  

- Writes to the clone or to the parent split the shared blocks. Only the delta is new, and a clone that drifts far enough costs as much as a full copy.  
- The clone is pinned to a backing snapshot. That snapshot cannot be deleted while the clone exists, so every block it holds stays allocated. Deleting the snapshot later, once the clone is gone, is what releases them. A clone split copies the shared blocks out and the saving disappears in one operation.  

`ontap-san-economy` behaves differently, because a snapshot there is a LUN clone.  
A FlexVol snapshot would capture every LUN that shares the volume, so Trident clones only the LUN that backs the PVC, and a PVC created from that snapshot is another LUN clone.  
The copy is still immediate and space-efficient: blocks stay shared until the source or the clone changes.  
What changes is where the cost lands. The LUN clone lives inside the same shared FlexVol, next to every other LUN, rather than in a new FlexVol with its own snapshot reserve.  
One PVC's snapshots and clones can fill that volume for all of its neighbors.  

Clones are the right tool for fast copies. They are a poor tool if you add up PVC sizes and expect that total to match the aggregate.  

## G. Where this leaves the application

Put the whole life of the volume together and a filesystem fills up for reasons the PVC never displays:  

- the original request was simply too small for the workload,  
- deleted files are still held by a snapshot, or were never unmapped from a LUN,  
- snapshots spilled out of their reserve,  
- with `ontap-san-economy`, LUN-clone snapshots filled the shared FlexVol,  
- clones diverged, or a split materialized a full extra copy.  

The pod returns _No space left on device_.  
`kubectl get pvc` still shows `Bound` and the original capacity.  
[Scenario09](../Scenario09) showed the manual remedy: raise the PVC size, with `allowVolumeExpansion: true`, and let Trident resize the backend.  
That works when a person notices in time.  

The rest of this scenario removes that person from the path.  
Two features watch used space and grow the volume on their own. They protect the same customer, and they do not leave the cluster in the same state.  
The third folder turns both on for one shared pool, and reads both sizes after every write, snapshot, delete and trim.  

## H. Trident Autogrow Policy

Trident 26.02 can grow a PersistentVolume by itself.  
You define a `TridentAutogrowPolicy` (a threshold, how much to add, and a maximum size) and you attach it to a StorageClass or to a single PVC.  
The StorageClass still needs `allowVolumeExpansion: true`.  

Trident checks used capacity regularly.  
Once the threshold is crossed, it resizes the PVC. The new size is applied on ONTAP, and `kubectl get pvc` shows it.  
For a LUN, the LUN grows with the claim, and the filesystem is extended while the volume is mounted.  
Kubernetes remains the source of truth: the capacity you read in the cluster is the capacity ONTAP has.  
SMB is not covered by this policy today.  

The walkthrough is in [1. Trident Autogrow Policy](1-autogrow-policy).  

## I. ONTAP volume autosize

Trident 26.10 can enable ONTAP volume autosize on the FlexVol that backs a SAN volume.  
The setting is an `ontapAutosize` block on the backend: `grow` or `off`, a used-space threshold, and a maximum size.  
Trident writes those settings when it creates, clones, resizes, or imports a volume it manages. Past the threshold, ONTAP grows the FlexVol on its own. The PVC is not edited.  

The LUN stays the same size, and so does the guest filesystem.  
The extra room is for snapshots and for the overhead around the LUN.  
`kubectl get pvc` keeps the original capacity, so Kubernetes and ONTAP no longer advertise the same size.  

Supported drivers are `ontap-san` (iSCSI, NVMe, FCP) and `ontap-san-economy` (iSCSI).  
NAS backends are rejected.  
Shrinking is not part of the feature: ONTAP volume autosize does not shrink a FlexVol. The [limitations](https://docs.netapp.com/us-en/trident/trident-use/ontap-autosize.html#limitations) list that explicitly, along with the drivers that are out of scope.  

The walkthrough is in [2. ONTAP volume autosize](2-ontap-volume-autosize).  

| | Trident Autogrow Policy | ONTAP volume autosize |
| :--- | :--- | :--- |
| Who grows the storage | Trident, from a policy on the StorageClass or the PVC | ONTAP, from the `ontapAutosize` settings on the backend |
| What grows | The PVC, then the FlexVol. The LUN as well, for SAN | The backing FlexVol |
| What `kubectl get pvc` shows afterwards | The new capacity | The original capacity |
| SAN filesystem | Gets a larger LUN | Stays the same size |
| Shrink | No | No |
| Where it applies | NFS and SAN. SMB is excluded today | `ontap-san` and `ontap-san-economy` |
| Safety rail | `maxSize` on the policy | `maximumSize` on the backend |

Use the first when the PVC must stay the authority for the size of the disk the application writes to.  
Use the second when the FlexVol needs room for snapshots and overhead without changing the LUN.  
Both stop at a maximum. Neither one is a substitute for watching the aggregate those volumes grow into.  

## J. Both mechanisms on one economy pool

A shared `ontap-san-economy` FlexVol asks both questions at once.  
Autogrow grows a PVC when that filesystem fills up. The LUN grows with the claim, and Trident enlarges the pool so the new LUN still fits.  
Autosize grows the same pool when snapshot LUN clones and blocks that were never unmapped push the FlexVol past its threshold. The claims stay at the size autogrow last wrote.

The walkthrough writes data from two pods, takes a snapshot, deletes, and trims, and reads the PVC capacity and the FlexVol size after each step.  
It is in [3. Both mechanisms on ontap-san-economy](3-san-economy-both).  

