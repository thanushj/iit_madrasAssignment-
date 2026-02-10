#!/usr/bin/env bash
set -e
mkdir -p keys
openssl genpkey -algorithm RSA -out keys/private.pem -pkeyopt rsa_keygen_bits:2048
openssl rsa -in keys/private.pem -pubout -out keys/public.pem
echo "Generated keys/private.pem and keys/public.pem (move private.pem to secure storage)."
