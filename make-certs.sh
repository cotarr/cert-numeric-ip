#!/bin/bash
#
# MIT License
#
# Copyright (c) 2021 Dave Bolenbaugh

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# ----------------------------------------------------------------
#
# See README.md for instructions
#
# This will only create certificates and keys that do not exist.
# At the end of the file is a list of host/ip lines.
#
# 1) Copy and edit openssl.conf as described
# 2) Edit script to provide TLS Organization name (any is ok)
# 3) Edit script at the bottom to add new certificate for each IP address
# 4) Before running, export CA password to unix environment variables
#
# ----------------------------------------------------------------

if [ ! -f "my_openssl.cnf" ] ; then
  echo "--------------------------------------------------"
  echo "A modified copy of openssl.cnf is needed."
  echo "cp -v /etc/ssl/openssl.cnf my_openssl.cnf"
  echo "Search: \"[ v3_ca ]\""
  echo "1) Add \"pathlen:0\" to basic constraints, example:"
  echo "  basicConstraints = critical,CA:true,pathlen:0"
  echo "2) Uncomment line: \"keyUsage = cRLSign, keyCertSign\""
  echo "--------------------------------------------------"
  exit 1
fi

# -------------------------------------
# You must provide an Organizaton name
# -------------------------------------
#TLS_ORG="My Organization Name"

if [ -z "$TLS_ORG" ] ; then
  echo "You must edit the script to set the TLS Organiztion variable TLS_ORG in line 54"
  exit 1
fi

if [ -z "$CA_KEY_PW" ] ; then
  echo "CA key password environment variable: export CA_KEY_PW=xxxxxxx ; history -c"
  exit 1
fi

TLS_DAYS=365
TLS_RSA_SIZE=2048
TLS_CA_FILENAME="CA"
DELETE_TEMP="Defined"

#-----------------
# Create CA key
#-----------------

if [ ! -f $TLS_CA_FILENAME.key ]
then
  echo "Creating CA key $TLS_CA_FILENAME.key"
  openssl genrsa \
    -aes256 \
    -passout env:CA_KEY_PW \
    -out "$TLS_CA_FILENAME.key" \
  $TLS_RSA_SIZE
fi

# Optional verify the CA private key
# In previously created key, this will check the password
echo "Checking CA key "
if ! openssl rsa \
  -in "$TLS_CA_FILENAME.key" \
  -passin env:CA_KEY_PW \
  -check \
  -noout
then
  echo ""
  echo "Error: Unable to verify CA certificate $TLS_CA_FILENAME.key"
  echo "Perhaps the env variable CA_KEY_PW does not match existing CA certificate"
  exit 1
fi

#-----------------
# Create CA certificate
#-----------------

if [ ! -f $TLS_CA_FILENAME.crt ] ; then
  echo "Creating CA certificate $TLS_CA_FILENAME.crt"
  openssl req -x509 -new \
    -key $TLS_CA_FILENAME.key \
    -passin env:CA_KEY_PW \
    -sha256 \
    -days $TLS_DAYS \
    -out $TLS_CA_FILENAME.crt \
    -subj "/O=$TLS_ORG/CN=$TLS_ORG-CA" \
    -config my_openssl.cnf
fi

# ------------------------------------
# Generate certificate and key pair
# -----------------------------------

function create_cert_and_key
{
  # Part 1, create the extension file with unique IP addresses or hostname
  #
  if [ ! -f $TLS_HOST.crt ] ; then

    # Option;
    #  "keyid,issuer" --> Do not copy Issuer and Issuer Serial if Subject Key Identifier copied
    #  "keyid,issuer:always" --> Always copy Issuer and Serial Number (Easy-rsa does this)
    echo "authorityKeyIdentifier=keyid,issuer" > SAN.ext

    echo "basicConstraints=CA:FALSE" >> SAN.ext

    # Different key usage settings for server, client or single cert both server and client
    if [[ "$TYPE" == "both" ]] ; then
      echo "keyUsage=digitalSignature,keyEncipherment" >> SAN.ext
      echo "extendedKeyUsage=serverAuth,clientAuth" >> SAN.ext
    elif [[ "$TYPE" == "server" ]] ; then
      echo "keyUsage=digitalSignature,keyEncipherment" >> SAN.ext
      echo "extendedKeyUsage=serverAuth" >> SAN.ext
    elif [[ "$TYPE" == "client" ]] ; then
      echo "keyUsage=digitalSignature" >> SAN.ext
      echo "extendedKeyUsage=clientAuth" >> SAN.ext
    fi
    echo "subjectKeyIdentifier=hash" >> SAN.ext

    # Subject Alternative Name
    echo "subjectAltName=@alt_names" >> SAN.ext
    echo "[alt_names]" >> SAN.ext
    if [ -n "$TLS_DNS1" ] ; then
      echo "DNS.1=$TLS_DNS1" >> SAN.ext
    fi
    if [ -n "$TLS_DNS2" ] ; then
      echo "DNS.2=$TLS_DNS2" >> SAN.ext
    fi
    if [ -n "$TLS_IP1" ] ; then
      echo "IP.1=$TLS_IP1" >> SAN.ext
    fi
    if [ -n "$TLS_IP2" ] ; then
      echo "IP.2=$TLS_IP2" >> SAN.ext
    fi
    if [ -n "$TLS_IP3" ] ; then
      echo "IP.3=$TLS_IP3" >> SAN.ext
    fi
    if [ -n "$TLS_IP4" ] ; then
      echo "IP.4=$TLS_IP4" >> SAN.ext
    fi
    # cat ./SAN.ext
  fi

  # Part 2, create the host key
  if [ ! -f $TLS_HOST.key ] ; then
    echo "Creating key $TLS_HOST.key"
    openssl genrsa \
      -out "$TLS_HOST.key" \
      $TLS_RSA_SIZE
  fi

  # Part 3, create the host CSR
  if [ ! -f $TLS_HOST.crt ] ; then
    echo "Creating certificate request $TLS_HOST.csr"
    openssl req -new \
      -key "$TLS_HOST.key" \
      -out "$TLS_HOST.csr" \
      -subj "/O=$TLS_ORG/CN=$TLS_HOST"

    # Part 4, create the host certificate
    #
    # Option: add "-text \" before "-out" to prepend decoded certificate
    #
    echo "Creating certificate $TLS_HOST.crt"
    openssl x509 -req \
      -in "$TLS_HOST.csr" \
      -CA CA.crt \
      -passin env:CA_KEY_PW \
      -CAkey "$TLS_CA_FILENAME.key" \
      -CAcreateserial \
      -out "$TLS_HOST".crt \
      -days $TLS_DAYS \
      -sha256 \
      -extfile SAN.ext

    # part 5, cat together full chain.
    echo "Aggregating $TLS_HOST-fullchain.crt"
    cat $TLS_HOST.crt CA.crt > $TLS_HOST-fullchain.crt

    # Delete CSR
    if [ -n "$DELETE_TEMP" ] ; then
      rm -v $TLS_HOST.csr SAN.ext
    fi
  fi
}

function reset
{
  unset TLS_HOST
  unset TYPE
  unset TLS_DNS1
  unset TLS_DNS2
  unset TLS_IP1
  unset TLS_IP2
  unset TLS_IP3
  unset TLS_IP4
}

# ------------------------------------------------------------------------------------------
#               Server list
# ------------------------------------------------------------------------------------------
# Each line is a semi-colon separated list of bash statements.
# Only missing certificates will be created.
# env variable TYPE:  "client", "server", "both".
# env variable TLS_HOST: used to construct certificate filenames and
#      in the certificate common name (CN).
# env variables for host verification: TLS_IP1, TLS_IP2, TLS_IP3, TLS_IP4, TLS_DNS1, TLS_DNS2
# Internal bash function: create_cert_and_key
# ------------------------------------------------------------------------------------------

# Example server certificate with numeric IP address
reset ; TYPE="server" ; TLS_HOST="server1" ; TLS_IP1="127.0.0.1"    ; TLS_IP2="::1" ; create_cert_and_key

# Example client certificate with numeric IP address
reset ; TYPE="client" ; TLS_HOST="client2" ; TLS_IP1="127.0.0.1"    ; TLS_IP2="::1" ; create_cert_and_key

# Example with both client and server in single certificate
#reset ; TYPE="both"   ; TLS_HOST="both3"   ; TLS_IP1="192.168.1.99" ; TLS_IP2="fc00:1::1111:2222:3333:4444" ; create_cert_and_key

# Example with Single IP address (omit TLS_IP2)
#reset ; TYPE="client" ; TLS_HOST="client4" ; TLS_IP1="127.0.0.1" ; create_cert_and_key

# showing domain name using TLS_DNS1
#reset ; TYPE="client" ; TLS_HOST="server5" ; TLS_DNS1="server5.example.com" ; create_cert_and_key

exit 0
