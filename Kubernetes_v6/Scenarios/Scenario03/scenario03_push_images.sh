# the Grafana image is already present on RHEL2.
# if that node had to reboot, the pod may not restart if no more tokens are available
# we will tag/push that image to the local registry & update the deploy

ssh rhel2 podman tag docker.io/grafana/grafana:10.4.1 registry.demo.netapp.com/grafana/grafana:10.4.1
ssh rhel2 podman login -u registryuser -p Netapp1! registry.demo.netapp.com
ssh rhel2 podman push registry.demo.netapp.com/grafana/grafana:10.4.1

kubectl set image -n monitoring deploy prometheus-grafana grafana=registry.demo.netapp.com/grafana/grafana:10.4.1

