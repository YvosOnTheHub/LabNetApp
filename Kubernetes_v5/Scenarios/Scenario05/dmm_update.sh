cd ~/LabNetApp/Kubernetes_v5/Scenarios/Scenario05

echo "#######################################################################################################"
echo "Update RPM"
echo "#######################################################################################################"

rpm -Uvh http://mirror.centos.org/centos/7/updates/x86_64/Packages/rpm-4.11.3-46.el7_9.x86_64.rpm \
https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-libs-4.11.3-46.el7_9.x86_64.rpm \
https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-python-4.11.3-46.el7_9.x86_64.rpm \
https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-build-4.11.3-46.el7_9.x86_64.rpm \
https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-build-libs-4.11.3-46.el7_9.x86_64.rpm \
https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-sign-4.11.3-46.el7_9.x86_64.rpm

hosts=( "rhel1" "rhel2" )
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host "rpm -Uvh http://mirror.centos.org/centos/7/updates/x86_64/Packages/rpm-4.11.3-46.el7_9.x86_64.rpm https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-libs-4.11.3-46.el7_9.x86_64.rpm https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-python-4.11.3-46.el7_9.x86_64.rpm https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-build-4.11.3-46.el7_9.x86_64.rpm https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-build-libs-4.11.3-46.el7_9.x86_64.rpm https://rpmfind.net/linux/centos/7.9.2009/updates/x86_64/Packages/rpm-sign-4.11.3-46.el7_9.x86_64.rpm"
done

echo "#######################################################################################################"
echo "Validate RPM version: 4.11.3-46"
echo "#######################################################################################################"

rpm -q rpm

hosts=( "rhel1" "rhel2" )
for host in "${hosts[@]}"
do
  ssh -o "StrictHostKeyChecking no" root@$host "rpm -q rpm"
done

echo "#######################################################################################################"
echo "Update DMM "
echo "#######################################################################################################"

cat <<EOF > /etc/yum.repos.d/epel8.repo
[EPEL-8]
baseurl = http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os
enabled = 1
gpgcheck = 0
name = EPEL8 RPMs
skip_if_unavailable = 1
EOF

yum install -y deltarpm device-mapper-multipath.x86_64


hosts=( "rhel1" "rhel2" )
for host in "${hosts[@]}"
do

  ssh -o "StrictHostKeyChecking no" root@$host "cat <<EOF > /etc/yum.repos.d/epel8.repo
[EPEL-8]
baseurl = http://mirror.centos.org/centos/8-stream/BaseOS/x86_64/os
enabled = 1
gpgcheck = 0
name = EPEL8 RPMs
skip_if_unavailable = 1
EOF"

  ssh -o "StrictHostKeyChecking no" root@$host "yum install -y deltarpm device-mapper-multipath.x86_64"
done