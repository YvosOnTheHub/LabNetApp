#!/bin/bash
for file in $(ls pvc*.yaml) ; do
  sed -i 's/storage-class-nas/storage-class-nas-economy/' ${file}
done