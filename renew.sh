#!/bin/bash

cd ${LE_RENEW_WORKDIR}

rm -f ./certbot-auto*

/usr/bin/wget https://dl.eff.org/certbot-auto

chmod a+x ./certbot-auto

/usr/bin/aws ec2 authorize-security-group-ingress --group-id ${LE_RENEW_SECGROUP_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0

./certbot-auto --apache certonly ${LE_RENEW_DOMAIN_LIST} -n --no-self-upgrade

/usr/bin/aws ec2 revoke-security-group-ingress --group-id ${LE_RENEW_SECGROUP_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0

cp ${LE_RENEW_CERT_DIR}/cert.pem /etc/pki/tls/certs/

chmod 644 /etc/pki/tls/certs/cert.pem

cp ${LE_RENEW_CERT_DIR}/chain.pem /etc/pki/tls/certs/

chmod 644 /etc/pki/tls/certs/chain.pem

cp ${LE_RENEW_CERT_DIR}/privkey.pem /etc/pki/tls/private/

chmod 600 /etc/pki/tls/private/privkey.pem

/sbin/service httpd configtest

if [ "$?" == 0 ]; then
  /sbin/service httpd reload
fi
