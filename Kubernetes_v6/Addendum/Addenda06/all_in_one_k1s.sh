#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL K1S"
echo "#"
echo "#######################################################################################################"
echo

cd
wget https://raw.githubusercontent.com/weibeld/k1s/master/k1s
chmod +x k1s
mv k1s /usr/local/bin

echo
echo "#######################################################################################################"
echo "#"
echo "# To run this tool, you can simply execute the command 'k1s ns_name object_to_monitor'"
echo "#"
echo "#######################################################################################################"
echo