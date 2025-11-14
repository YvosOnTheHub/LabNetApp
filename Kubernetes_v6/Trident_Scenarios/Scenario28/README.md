#########################################################################################
# SCENARIO 27: Automated Workload Failover 
#########################################################################################

 grep -nE 'GracefulNodeShutdown|shutdownGracePeriod' /var/lib/kubelet/config.yaml || true
40:shutdownGracePeriod: 0s
41:shutdownGracePeriodCriticalPods: 0s

If shutdownGracePeriod* are set to "0s" (or absent and feature disabled) the kubelet will not perform graceful node shutdown.

Note that by default, both configuration options described below, shutdownGracePeriod and shutdownGracePeriodCriticalPods, are set to zero, thus not activating the graceful node shutdown functionality. To activate the feature, both options should be configured appropriately and set to non-zero values.

