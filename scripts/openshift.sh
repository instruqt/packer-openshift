set -e
export VERSION=v3.9.0
export ARCH=v3.9.0-191fece-linux
export URL=https://github.com/openshift/origin/releases/download/$VERSION
df -h
setenforce 0

mkdir -p /openshift
yum install ca-certificates git nfs-utils python2-ruamel-yaml -y
curl -o openshift.tar.gz -L $URL/openshift-origin-server-$ARCH-64bit.tar.gz
tar -xvf openshift.tar.gz
rm openshift.tar.gz
mv openshift-origin-server-$ARCH-64bit/ /var/lib/openshift/

curl -o oc.tar.gz -L $URL/openshift-origin-client-tools-$ARCH-64bit.tar.gz
tar -xvf oc.tar.gz
rm oc.tar.gz

mv openshift-origin-client-tools-$ARCH-64bit/oc /usr/bin/oc
rm -rf ~/*
chmod +x /usr/bin/oc
/usr/bin/oc version
echo $PATH
oc version


cat <<-EOF > /etc/systemd/system/origin.service
[Unit]
Description=OpenShift
After=docker.target network.target
[Service]
Type=notify
Environment=KUBECONFIG=/openshift.local.config/master/admin.kubeconfig
Environment=CURL_CA_BUNDLE=/openshift.local.config/master/ca.crt
ExecStartPre=/usr/bin/rm -irf /openshift.local.etcd/ /openshift.local.volumes/;
ExecStart=/var/lib/openshift/openshift start --master-config=/openshift.local.config/master/master-config.yaml --node-config=/openshift.local.config/node-%H/node-config.yaml --dns=tcp://0.0.0.0:8053
Restart=always
RestartSec=3
TimeoutSec=30
[Install]
WantedBy=multi-user.target
EOF

touch ~/.hushlogin

echo 'echo 127.0.0.1 \$HOSTNAME >> /etc/hosts' >> /root/.set-hostname
chmod +x /root/.set-hostname

curl -Lk https://raw.githubusercontent.com/openshift/origin/master/examples/image-streams/image-streams-centos7.json -o /openshift/image-streams-centos7.json
# oc create -f /openshift/image-streams-centos7.json --namespace=openshift
# oc policy add-role-to-user system:masters developer

echo 'export KUBECONFIG=/openshift.local.config/master/admin.kubeconfig' >> ~/.bashrc
echo 'export CURL_CA_BUNDLE=/openshift.local.config/master/ca.crt' >> ~/.bashrc
echo 'export PS1="$ "' >> ~/.bashrc

mv /tmp/files/* /openshift && chmod +x /openshift/*
