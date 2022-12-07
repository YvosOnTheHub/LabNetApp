
echo "##############################################################"
echo "# GENERATE A KEY"
echo "##############################################################"

IPSECKEY=$(openssl rand -base64 24)

echo "##############################################################"
echo "# UPDATE ANSIBLE INVENTORY WITH KEY"
echo "##############################################################"

sed -i s/SC14KEY/$IPSECKEY/ /etc/ansible/hosts