# Let's Encrypt Automatic Renewal Script

This script requests for a new SSL certificate from Let's Encrypt using `certbot-auto`.

I wrote the script with the following scenario and situation in mind:

- The machine is an AWS EC2 instance in public subnet, but with restricted security group which prevents public internet from accessing HTTP/HTTPS. This will prevent Let's Encrypt from verifying the domain.

- Apache web server is already setup with a virtualhost (or default site) which points to a set of SSL certificate files.

- The script will need to poke a hole in the security group temporarily (0.0.0.0/0 HTTPS), run `certbot-auto`, and close it immediately afterwards.

- The script will copy the resulting SSL certificate files to `/etc/pki/tls/certs` and `/etc/pki/tls/private` directories, which will match the Apache virtualhost configuration.

## Pre-requisites

- The machine needs to have `aws-cli` installed and configured to run as an IAM user (or better, as instance IAM role) which is allowed to change security group settings.

- The machine has a security group attached that will be manipulated for the purpose of domain validation.


## Run it as a cron job

Example:

`0 0 1 * * LE_RENEW_WORKDIR="/path/to/workdir" LE_RENEW_DOMAIN_LIST="-d www.domain.com -d domain.com" LE_RENEW_CERT_DIR="/etc/letsencrypt/live/domain.com" LE_RENEW_SECGROUP_ID="sg-1234abcd" /path/to/workdir/renew.sh`

The cron job above will run every first day of the month.

## Explanation

The script will change working directory and :

Download the latest `certbot-auto` from EFF website and make sure it is executable.

```
rm -f ./certbot-auto*

/usr/bin/wget https://dl.eff.org/certbot-auto

chmod a+x ./certbot-auto
```

Open up the security group to allow HTTPS ingress from 0.0.0.0/0.

```
/usr/bin/aws ec2 authorize-security-group-ingress --group-id ${LE_RENEW_SECGROUP_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0
```

Run `certbot-auto` for Apache web server to request and download certificate only (`--apache certonly`), non-interactively (`-n`), and prevent self-upgrade (`--no-self-upgrade`).

```
./certbot-auto --apache certonly ${LE_RENEW_DOMAIN_LIST} -n --no-self-upgrade
```

Close the hole in the security group immediately.

```
/usr/bin/aws ec2 revoke-security-group-ingress --group-id ${LE_RENEW_SECGROUP_ID} --protocol tcp --port 443 --cidr 0.0.0.0/0
```

Copy the resulting SSL certificate files.

```
cp ${LE_RENEW_CERT_DIR}/cert.pem /etc/pki/tls/certs/

chmod 644 /etc/pki/tls/certs/cert.pem

cp ${LE_RENEW_CERT_DIR}/chain.pem /etc/pki/tls/certs/

chmod 644 /etc/pki/tls/certs/chain.pem

cp ${LE_RENEW_CERT_DIR}/privkey.pem /etc/pki/tls/private/

chmod 600 /etc/pki/tls/private/privkey.pem
```

Reload Apache.

```
/sbin/service httpd configtest

if [ "$?" == 0 ]; then
  /sbin/service httpd reload
fi
```

## Improvements

- Monitor the machine to make sure that the security group is properly configured i.e., don't let the HTTPS port open outside of during renewal.

