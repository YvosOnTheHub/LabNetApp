#!/bin/bash
for file in $(ls pvc*.yaml) ; do
  sed -i 's/storage-class-nas/sc-topology/' ${file}
done