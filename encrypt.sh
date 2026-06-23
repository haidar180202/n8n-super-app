#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./encrypt.sh <decryption_password>"
  exit 1
fi
openssl enc -aes-256-cbc -salt -in supreme.json -out supreme.json.enc -k "$1" -pbkdf2
echo "Success! supreme.json has been encrypted to supreme.json.enc."
