ping -c1 -W1 -q rhel4 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL4 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi
ping -c1 -W1 -q rhel5 &>/dev/null
if [[ $? == 1 ]];then
  echo "#################################################################"
  echo "# You first need to start RHEL5 from the LoD MyLabs page"
  echo "#################################################################"
  exit 0
fi

echo
echo "#####################################################"
echo "# Copy second K8S cluster creation script to RHEL5"
echo "#####################################################"

curl -s --insecure --user root:Netapp1! -T ../../Addendum/Addenda12/all_in_one.sh sftp://rhel5/root/

echo
echo "#####################################################"
echo "# Launch second cluster setup"
echo "#####################################################"

ssh -o "StrictHostKeyChecking no" root@rhel5 sh all_in_one.sh