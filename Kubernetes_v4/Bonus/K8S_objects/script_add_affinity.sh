#!/bin/bash
for file in $(ls pod_*.yaml) ; do
  sed -i '/spec:/r script_add_affinity_text.txt' ${file}
done