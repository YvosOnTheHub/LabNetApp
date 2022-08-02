#!/bin/bash

echo
echo "#######################################################################################################"
echo "#"
echo "# INSTALL K8SH"
echo "#"
echo "#######################################################################################################"
echo

cd
git clone https://github.com/Comcast/k8sh.git
mv k8sh/k8sh /usr/bin/
sed -e '/  NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_NAMESPACE_COLOR.*/ s/CYAN/BLUE/' -i /usr/bin/k8sh
sed -e '/  PS_CONTEXT_COLOR.*/ s/LRED/RESTORE/' -i /usr/bin/k8sh

echo
echo "#######################################################################################################"
echo "#"
echo "# To run this tool, you can simply execute the command 'k8sh'"
echo "#"
echo "#######################################################################################################"
echo