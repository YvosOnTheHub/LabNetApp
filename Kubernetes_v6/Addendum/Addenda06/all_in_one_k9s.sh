dnf install -y snapd
systemctl enable --now snapd.socket
systemctl start snapd
ln -s /var/lib/snapd/snap /snap

snap install k9s
ln -s /snap/k9s/current/bin/k9s /snap/bin/
export PATH=$PATH:/snap/bin
echo 'export PATH=$PATH:/snap/bin' >> ~/.bashrc