##!/usr/bin/env bash
set -e

sudo apt-get install strongswan -y
sudo apt-get install strongswan-pki -y
sudo apt-get  install libstrongswan-extra-plugins -y
### End Installing tools
ipsec pki --gen --outform pem > caKey.pem
ipsec pki --self --in caKey.pem --dn "CN=P2SRootCert" \
        --ca --outform pem > caCert.pem
openssl x509 -in caCert.pem -outform der | base64 -w0  > caCert.cer
#Create client certificate
PASSWORD="pass@word"
USERNAME="azureuser"

ipsec pki --gen --outform pem > "${USERNAME}Key.pem"
ipsec pki --pub --in "${USERNAME}Key.pem" | ipsec pki \
          --issue --cacert caCert.pem --cakey caKey.pem \
          --dn "CN=${USERNAME}" --san "${USERNAME}" \
          --flag clientAuth --outform pem > "${USERNAME}Cert.pem"

openssl pkcs12 -in "${USERNAME}Cert.pem" \
              -inkey "${USERNAME}Key.pem" \
              -certfile caCert.pem \
              -export -out "${USERNAME}.p12" \
              -password "pass:${PASSWORD}"