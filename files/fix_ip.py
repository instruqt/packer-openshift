#!/usr/bin/env python
import requests
import ruamel.yaml
import os
import socket
import fcntl
import struct

from ruamel.yaml.util import load_yaml_guess_indent


metadata_server = "http://metadata/computeMetadata/v1/instance/"
metadata_flavor = {'Metadata-Flavor' : 'Google'}

def get_ip_address(ifname):
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    ip = socket.inet_ntoa(fcntl.ioctl(
        s.fileno(),
        0x8915,  # SIOCGIFADDR
        struct.pack('256s', ifname[:15])
    )[20:24])
    return ip.replace(".", "\.")


def get_external_ip_address():
    ip = requests.get(metadata_server + 'network-interfaces/0/access-configs/0/external-ip', headers = metadata_flavor).text
    return ip.replace(".", "\.")

def get_participant_dns():
    return requests.get(metadata_server + 'attributes/instruqt_participants_dns', headers = metadata_flavor).text

file_name = '/openshift.local.config/master/master-config.yaml'

config, ind, bsi = load_yaml_guess_indent(open(file_name))

participantid = os.environ["INSTRUQT_PARTICIPANT_ID"]
participant_dns = "." + get_participant_dns()
masterpublicurl = "https://openshift-8443-"+participantid+participant_dns
publicurl = masterpublicurl + "/console/"
internalip = get_ip_address('eth0')
externalip = get_external_ip_address()

config['corsAllowedOrigins'].append("//openshift-8443-"+participantid+participant_dns.replace('.', '\.')+":443$")
config['corsAllowedOrigins'].append("//openshift-8443-"+participantid+participant_dns.replace('.', '\.')+":8443$")
config['corsAllowedOrigins'].append("//openshift-8443-"+participantid+participant_dns.replace('.', '\.')+"$")
config['corsAllowedOrigins'].append("//"+internalip+"(:|$)")
config['corsAllowedOrigins'].append("//"+externalip+"(:|$)")
config['masterPublicURL'] = masterpublicurl
config['oauthConfig']['masterPublicURL'] = masterpublicurl
config['oauthConfig']['assetPublicURL'] = publicurl
config['routingConfig']['subdomain'] = "openshift-80-"+participantid+participant_dns

ruamel.yaml.round_trip_dump(config, open('/openshift.local.config/master/master-config.yaml', 'w'),
    indent=ind, block_seq_indent=bsi)
