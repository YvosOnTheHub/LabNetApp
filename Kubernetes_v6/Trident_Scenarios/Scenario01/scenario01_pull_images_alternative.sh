
podman run --rm quay.io/containers/skopeo:latest copy --multi-arch all \
  --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/trident:25.10.0 \
  docker://registry.demo.netapp.com/trident:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false

podman run --rm quay.io/containers/skopeo:latest copy \
  --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/trident-autosupport:25.10.0 \
  docker://registry.demo.netapp.com/trident-autosupport:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false
  
podman run --rm quay.io/containers/skopeo:latest copy \
  --dest-creds 'registryuser:Netapp1!' \
  docker://docker.io/netapp/trident-operator:25.10.0 \
  docker://registry.demo.netapp.com/trident-operator:25.10.0 \
  --src-tls-verify=false --dest-tls-verify=false 