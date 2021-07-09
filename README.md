# cert-numeric-ip

Bash script to create TLS certificates with numeric IP addresses in V3 Subject Alternative Name.

### Requirements

* openssl
* linux

Written using openssl 1.1.1d using Debian 10. Other OS not tested.

### Used For...

This is a script that I have used for several years to make Raspberry Pi TLS certificates for
IOT devices on a home network.
I prefer to interconnect Raspberry Pi web API connections using two way, client and server,
TLS certificate verification. In this configuration, each API web server will only
accept TLS client connections from other devices with a valid TLS client certificate.

To make IOT device networking simple, each device is referred to by a numeric IP address
such as "192.168.1.99" rather than a domain name like "device123.example.com".
However, many TLS certificate tutorials or toolbox scripts are limited to creation of
certificates for domain names rather than numeric addresses.
After some experimenting, several openssl commands were evolved that can produce
functional TLS certificates for use with numeric address.

With this approach, one self signed CA certificate can be created as an authority
to digitally sign or verify signatures for all client and server certificates.
If the CA certificate is added to a web browser, it will allow access to IOT devices
without certificate warning,
provided the IP address of each server matches the certificate SAN, and the certificates are valid.

# Installation

### Clipboard from github

Since this is a bash script, the simplest way to copy github to clipboard.

* Create an empty folder
* Open new file "make-certs.sh" in editor
* Copy/paste contents of make-certs.sh from this github repository
* Save file, and change permission to executable

### Clone Repository

If you would prefer to clone the repository...

```bash
git clone git@github.com:cotarr/cert-numeric-ip.git
cd cert-numeric-ip
```

Check the permissions of the make-certs.sh file. If it is not executable,
you may change by typing:

```bash
chmod 744 make-certs.sh
```

# Configuration

If you are not familiar with creating TLS certificates, it may be useful
to run the script one time before configuring your specific hosthames and IP addresses.
This will create some example certificates that can be tested using openssl commands
as shown at the end of this README. The example addresses are set to the local host address.

## 1 - openssl configuration file

Two minor changes are needed in a modified copy of openssl.cnf.
In other linux distributions, openssl.cnf may be in an alternate location.
On Debian linux, the system openssl configuration file can be
copied to "my_openssl.cnf" with the following command.

```
cp -v /etc/ssl/openssl.cnf my_openssl.cnf"
```

In the file "my_openssl.cnf", search for the string: "[ v3_ca ]".

In the v3_ca section, find the string "basicConstraints = critical". Append "pathlen:0" separated by a comma, without space. The line should look like this:

```
basicConstraints = critical,CA:true,pathlen:0
```

Next, in the v3_ca section, remove the comment symbol from the following line
```
keyUsage = cRLSign, keyCertSign
```

## 2 - Organization name

Open the "make-certs.sh" script. Locate the environment variable
assignment for "TLS_ORG". Remove the comment symbol.
Enter a new unique value for the organization name.

In the case where the CA certificate may be added to a web browser
as a trusted authority, the custom CA certificate
will be listed by the organization name when managing the list of
installed browser CA certificates.

```
TLS_ORG="My Organization Name"
```

Each time the script is run, the CA (Certificate Authority) certificate file
shall be created automatically if it does not previously exist.
The CA certificate is a prerequisite to make other certificates, so this is always performed.
Therefore, there is no other unique configuration to select creation of a CA certificate.

## 3 - Certificate host specific configuration

The script will check existence of certificate files from a list of
desired certificates located at the end of the make-certs.sh file.
If a certificate file is not found, the certificate and key files will
be created by the script using openssl bash statements.
It is not necessary to disable configuration lines for certificates
that exist previously as they will be skipped.

Each configuration is a series of bash statements on a single line separated
by semicolon (;) symbols. The "reset" statement is a bash function to remove
previous configuration. Several environment (env) variables are defined.
The statement "create_cert_and_key" located at the right end of the line
is a bash function used to create the certificates based on the env variable contents.

```bash
reset ; TYPE="server" ; TLS_HOST="server1" ; TLS_IP1="127.0.0.1"    ; TLS_IP2="::1" ; create_cert_and_key
reset ; TYPE="client" ; TLS_HOST="client2" ; TLS_IP1="127.0.0.1"    ; TLS_IP2="::1" ; create_cert_and_key
```

### 3A - TYPE

The env variable TYPE can have 3 values "client", "server", "both". This determines
if the certificate should be a server or client TLS certificate. If the "both" designation
is used, a certificate is created that can be used as both a client and server
certificate. This is useful when chaining connections from one IOT device to the next
such as a raspberry pi containing an API web server with reverse proxy connection
to a second API web server.

### 3B - TLS_HOST

The env variable TLS_HOST is used to construct certificate filenames.

The TLS_HOST also appears in the TLS certificate as the CN (Common Name) value
for each server certificate or client certificate.

### 3C - Host Identification

This script allows numeric IP address to be used for host identification.

In a TLS certificate, either IPV4 or IPV6 numeric IP addresses may
be included in the v3 Subject Alternative Name (SAN) field.
When the CA certificate is added to a web browser as a trusted authority,
then attempts to visit a URL such as "https://192.168.1.99"
will load without browser certificate security warning for cases where
a web page's TLS certificate has a valid CA issuer certificate signature and
the IP address in the URL matches the IP address value in the
server TLS certificate v3 SAN.

Several optional env variable names may be used to specify host IP addresses:
TLS_IP1, TLS_IP2, TLS_IP3, TLS_IP4, TLS_DNS1, TLS_DNS2. The script
in this repository contains several examples. The env variables syntax
should follow the this example. Note there are no space characters by the
equals sign.

```
TLS_IP1="192.168.1.99"
TLS_IP2="fc00:1::1111:2222:3333:4444"
TLS_DNS1="server5.example.com"
```

This completes the configuration.

# Removal of previous certificates

If you want to erase all the certificates and start over, the
following rm command will erase all previous certificates.

```bash
rm -v *.crt *.key *.srl
```

# Running the script

It is necessary to provide a password used to encrypt the CA private key.
This applies only to the CA key. The server and client private keys are not password encrypted
in this script. The CA key password is entered using the "CA_KEY_PW" unix environment
variable. Caution, this may save the password in your bash history. Some shells can skip
the history by starting the line with a space character. In other cases, appending
a history command such as `export CA_KEY_PW=xxxxxxx ; history -c` can clear the bash history.
This only needs to be entered one time as it will remain in the shell memory.
Substitute your password for xxxxxxxx.

```bash
export CA_KEY_PW=xxxxxxxx
```

Next, execute the script from the command line.

```bash
./make-certs.sh
```

Using the ls command, list the certificates and keys created by the script.
If you did not edit the script, the following files will have been created.

```
CA.key
CA.crt
CA.srl

server1.key
server1.crt
server1-fullchain.crt

client2.key
client2.crt
client2-fullchain.crt
```

# Viewing certificate contents

The following openssl x509 command will decode and display the
CA certificate contents.

```bash
openssl x509 -in CA.crt -noout -text
```

You should check that the organization name appears correctly.
You should also note the expiration date.
You will need to generate new certificates before it expires.

```
Issuer: O = My Organization Name, CN = My Organization Name-CA
Validity
    Not Before: Jul  7 09:28:25 2021 GMT
    Not After : Jul  7 09:28:25 2022 GMT
Subject: O = My Organization Name, CN = My Organization Name-CA
X509v3 Basic Constraints: critical
    CA:TRUE, pathlen:0
X509v3 Key Usage:
    Certificate Sign, CRL Sign
```

Each IOT server certificate can be decoded and displayed with the same command:

```bash
openssl x509 -in server1.crt -noout -text
```

In the server certificate contents, note the Extended Key Usage is set
to "TLS Web Server Authentication".
In the case of server certificates, it is recommended to
verify the correct values for the IP addresses.
You should also note the expiration date.
It is a good practice to avoid long expiration dates
in server certificates, because some web browsers are beginning
to not trust server certificates with extreme future expiration dates.

```
Issuer: O = My Organization Name, CN = My Organization Name-CA
Validity
    Not Before: Jul  7 09:28:25 2021 GMT
    Not After : Jul  7 09:28:25 2022 GMT
Subject: O = My Organization Name, CN = server1
X509v3 Extended Key Usage:
    TLS Web Server Authentication
X509v3 Subject Alternative Name:
    IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1
```

The client certificate can also be viewed in the same manner.

```bash
openssl x509 -in client2.crt -noout -text
```

In the client certificate contents, note the Extended Key Usage is set to
"TLS Web Client Authentication".

```
Issuer: O = My Organization Name, CN = My Organization Name-CA
Validity
    Not Before: Jul  7 09:28:25 2021 GMT
    Not After : Jul  7 09:28:25 2022 GMT
Subject: O = My Organization Name, CN = client2
X509v3 Extended Key Usage:
    TLS Web Client Authentication
X509v3 Subject Alternative Name:
    IP Address:127.0.0.1, IP Address:0:0:0:0:0:0:0:1
```

# Testing the certificates

The following is optional.

The openssl library provides two programs s_client and s_server that can be
used to test TLS certificates. SSL/TLS is a network socket connection.
With a socket connection, when the server and client are connected, anything
typed in one will pass through the socket and will appear in the other.
If you have run make-certs.sh with the original configuration,
the certificates will be setup with the localhost address.
The following tests can be run on a single computer by opening two terminals side by side.

### Encryption without identity verification.

The following command will start s_server in one terminal.
The server certificate and private key will used by s_server to negotiate the encrypted connection.
These examples can be stopped by pressing ctrl-C.

Server:

```bash
openssl s_server -port 8000 -cert server1.crt -key server1.key
```

In a second terminal, start the s_client program. In this case, no certificates are specified.
The s_client will use the default TLS certificates provided by the operating system.
Without CA certificate, verification of the server certificate signature is not possible.
Therefore, an error will be expected.

It is up to a client program to check for certificate errors and disconnect accordingly.
In this example, the two terminal windows will remain connected, despite the certificate error.

Client:

```bash
openssl s_client -connect 127.0.0.1:8000
```

If all goes well, the two terminals will be connected over a SSL/TLS encrypted connection.
However, s_client will have been unable to verify the identity of the server, so an error is shown.
Looking at the last few lines, you will see
`Verify return code: 21 (unable to verify the first certificate)`.
Despite the error, try typing in each terminal and the content will be echoed to the other terminal.

### Add verification of the server certificate

Stop and restart the s_server using the same command previously used.

Server:

```bash
  openssl s_server -port 8000 -cert server1.crt -key server1.key
```

In the other terminal, add the file name of the Certificate Authority (CA) file as shown.
In this case, during the TLS negotiation, the s_server certificate (server1.crt) is
sent to the s_client where the signature in the server1.crt will be checked for validity
using the CA cert (CA.crt) present in the client.

Client:

```bash
openssl s_client -CAfile CA.crt -connect 127.0.0.1:8000
```

Upon successful connection, s_client should show `Verify return code: 0 (ok)`
located a few lines up from the bottom of the screen. The zero return code indicates that
the signatures on the server certificate were verified using the CA certificate.
Try typing in each terminal and the content will be echoed to the other terminal.

### Add verification of the client certificate

In the previous example, the client used the CA.crt certificate to very the certificate signature of the
server. In the reverse direction, the previous example had no check on the identity
of the client.
In the previous example, the server identification verification was performed on the
client end. In the next example using client authentication, the verification of the
client identity is performed on the server end.

To do this, the CA certificate (CA.crt) must be added to the command used to start the
s_server program. In total 3 files are specified.
Stop and restart the s_server with the following command.

Add the switch "-Verify 1".
This switch tells the server to request client certificate.
The upper case V indicates the request is mandatory.

Note the upper case "V" in "-Verify".

Server:

```bash
openssl s_server -port 8000 -CAfile CA.crt -cert server1.crt -key server1.key -Verify 1
```

First, lets start s_client without client certificates and confirm the server will reject
the client connection. Start the client with the following command.

Client:

```bash
openssl s_client -CAfile CA.crt -connect 127.0.0.1:8000
```

The server should reject the connection with the message:
`...peer did not return a certificate...`.
The client will also shown an error: `...alert certificate required...`.
This is the expected result.

Next, stop and restart the server with the same command.

Server:

```bash
openssl s_server -port 8000 -CAfile CA.crt -cert server1.crt -key server1.key -Verify 1
```

Add the client certificate and private key to the s_client command.
A total of 3 files are specified as follows:

Client:

```bash
openssl s_client -CAfile CA.crt -cert client2.crt -key client2.key -connect 127.0.0.1:8000
```

In this case the s_client should display the message: "Verify return code: 0 (ok)".
The zero result indicated that a 2 way verification was successful. The s_client sent
the client certificate (client2.crt) to the s_server program which in turn used the
CA certificate (CA.crt) to verify the signature on the client certificate client2.crt.

Testing of two way certificate verification is now complete.

### IPV6

A couple notes on IPV6 addresses. The examples in this script use both IPV4 and
IPV6 addresses in the certificate. It is not necessary to use both.
The IPV6 environment variable can be safely omitted.

In some devices, the operating system can randomize the last 64 bits of the
IPV6 address for privacy purposes. If you are using IP addresses as part of identity
verification, the IPV6 hardware generated address should be used.
The privacy address may need to be disabled.

In some cases, the colon character is used in a URL to separate the port number.
It may be necessary to wrap the IPV6 address in square brackets.

If you want to test using IPV6 with openssl using s_client, it is necessary to wrap the
IPV6 address in brackets as follows.

Server:
```bash
openssl s_server -port 8000 -CAfile CA.crt -cert server1.crt -key server1.key -Verify 1
```

Client:

```bash
openssl s_client -CAfile CA.crt -cert client2.crt -key client2.key -connect [::1]:8000
```

Response: `Verify return code: 0 (ok)`

### Hostname Verification

The previous testing involved verification of valid certificates and valid digital signatures.
It did not include comparison of the actual IP address to the address specified in the v3 SAN.
It is up to the client program to check for this match. A client program may choose to disconnect
or ignore the identity mis-match error. In the above examples s_client did not include this check.
If you are curious and want to try checking for a mismatch, you can use the "curl" command.

In this case, client certificate verification is not involved, so the CA certificate and
the Verify switch can be removed from the server. Start the server with the following command.

Server:

```bash
openssl s_server -port 8000 -cert server1.crt -key server1.key
```

Similar to above, first try using curl without the CA certificate. An error is expected.
Run curl with the following command:

Client:

```bash
curl https://127.0.0.1:8000
```

curl returned the following error, the expected result.

```
curl: (60) SSL certificate problem: self signed certificate in certificate chain
```

This error could be ignored by adding the switch --insecure to the curl command,
such as `curl --insecure  https://127.0.0.1:8000`.
However, this simply ignores the certificate error, which is not secure.
Instead, we will add the CA certificate to the curl command.
Restart the server and then run curl with the following command:

Client:

```bash
curl --cacert CA.crt https://127.0.0.1:8000
```

Curl expects a web page to be returned. The s_client opens a socket, but does not respond
with any data. Therefore curl will hang, waiting for a web page to be sent. This is the normal result.
The main point to observe here is that no errors are printed. Stop curl by pressing ctrl-C.

Now, create an IP address mismatch. In the make-certs.sh script, change the number of the
localhost IP address from 127 to 128 in the server1 definition. The new line will look like this.

make-certs.sh:

```
reset ; TYPE="server" ; TLS_HOST="server1" ; TLS_IP1="128.0.0.1"    ; TLS_IP2="::1" ; create_cert_and_key
```

Erase old certificates and generate new certificates by typing:

```bash
rm -v *.crt *.key *.srl
./make-certs.sh
```
Restart s_server by typing:

Server:

```bash
openssl s_server -port 8000 -cert server1.crt -key server1.key
```

Now, try using curl to load the page using the CA file. Previously, no error occurred,
and curl was hung waiting for a server reply. Now type the same curl command:

Client:

```bash
curl --cacert CA.crt https://127.0.0.1:8000
```

Unlike the previous example, the IP address 127.0.0.1 did not match the v3 SAN
address 128.0.0.1, so a host verification error occurs, the expected result.

```
curl: (60) SSL: no alternative certificate subject name matches target host name '127.0.0.1'
```
