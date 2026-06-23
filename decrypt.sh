#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: ./decrypt.sh <decryption_password>"
  exit 1
fi
openssl enc -d -aes-256-cbc -in supreme.json.enc -out supreme.json -k "$1" -pbkdf2
echo "Success! supreme.json.enc has been decrypted to supreme.json."
