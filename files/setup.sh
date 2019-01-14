#!/bin/sh
set -e

METADATA_URL=http://metadata.google.internal/computeMetadata/v1/instance
export INSTRUQT_PARTICIPANTS_DNS=$(curl --silent "$METADATA_URL/attributes/instruqt_participants_dns" -H "Metadata-Flavor: Google")

systemctl stop origin

/var/lib/openshift/openshift start --write-config /openshift.local.config/

python /openshift/fix_ip.py

systemctl start origin

mkdir -p ~/.kube
cp /openshift.local.config/master/admin.kubeconfig ~/.kube/config

echo "Starting OpenShift"
echo "Waiting for OpenShift to start... This may take a couple of moments"
until $(oc status &> /dev/null); do
  sleep 1
done
echo "OpenShift started. "
echo -n "Configuring... "

echo "configuring registry"
for i in {1..10}; do oc adm registry -n default --config=/openshift.local.config/master/admin.kubeconfig > /dev/null 2>&1 && break || sleep 1; done

echo "Adding policy"
for i in {1..10}; do oc adm policy add-scc-to-user hostnetwork -z router > /dev/null 2>&1 && break ||sleep 1; done

echo "Getting router"
for i in {1..10}; do oc adm router > /dev/null 2>&1 && break || sleep 1; done
until $(oc get svc router &> /dev/null); do
sleep 1
done

echo "creating image streams"
oc create -f /openshift/image-streams-centos7.json --namespace=openshift > /dev/null 2>&1
echo "OpenShift Ready"


echo "Scaling router"
oc scale dc router -n default --replicas=1
echo "Scaling registry"
oc scale dc docker-registry -n default --replicas=1

cat > /tmp/console-config.yaml << EOF
apiVersion: webconsole.config.openshift.io/v1
kind: WebConsoleConfiguration
clusterInfo:
  consolePublicURL: https://openshift-8443-$INSTRUQT_PARTICIPANT_ID.$INSTRUQT_PARTICIPANTS_DNS/console/
  loggingPublicURL: ""
  logoutPublicURL: ""
  masterPublicURL: https://openshift-8443-$INSTRUQT_PARTICIPANT_ID.$INSTRUQT_PARTICIPANTS_DNS
  metricsPublicURL: ""
extensions:
  scriptURLs: []
  stylesheetURLs: []
  properties: null
features:
  inactivityTimeoutMinutes: 0
  clusterResourceOverridesEnabled: false
servingInfo:
  bindAddress: 0.0.0.0:8443
  bindNetwork: tcp4
  certFile: /var/serving-cert/tls.crt
  clientCA: ""
  keyFile: /var/serving-cert/tls.key
  maxRequestsInFlight: 0
  namedCertificates: null
  requestTimeoutSeconds: 0
EOF

oc create ns openshift-web-console
oc process -f https://raw.githubusercontent.com/openshift/origin/master/install/origin-web-console/console-template.yaml -p "API_SERVER_CONFIG=$(cat /tmp/console-config.yaml)" | oc apply -n openshift-web-console -f -

until $(curl --output /dev/null --silent --head --insecure -L https://localhost:8443); do sleep 1; done
