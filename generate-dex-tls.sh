#!/bin/sh
OUTPUT_DIR=output

set -e
set -x

# generate a pair of key and certificate for CA
openssl genrsa -out $OUTPUT_DIR/dex-ca.key 2048
openssl req -new -key $OUTPUT_DIR/dex-ca.key -out $OUTPUT_DIR/dex-ca.csr -subj "/CN=dex-ca" -config openssl.cnf
openssl x509 -req -in $OUTPUT_DIR/dex-ca.csr -signkey $OUTPUT_DIR/dex-ca.key -out $OUTPUT_DIR/dex-ca.crt -days 10

# generate a pair of key and certificate for TLS server
openssl genrsa -out $OUTPUT_DIR/dex-server.key 2048
openssl req -new -key $OUTPUT_DIR/dex-server.key -out $OUTPUT_DIR/dex-server.csr -subj "/CN=dex-server" -config openssl.cnf
openssl x509 -req -in $OUTPUT_DIR/dex-server.csr \
  -CA $OUTPUT_DIR/dex-ca.crt -CAkey $OUTPUT_DIR/dex-ca.key -CAcreateserial \
  -out $OUTPUT_DIR/dex-server.crt -sha256 -days 10 -extensions v3_req -extfile openssl.cnf
