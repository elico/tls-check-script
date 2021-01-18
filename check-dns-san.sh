#!/usr/bin/env bash

# OpenSSL requires the port number.
SERVER="$1"
PORT="$2"
SNI="$3"
if [ -z "${SERVER}" ];then
  echo "Missing destination server/domain/ip"
  exit 1
fi

if [ -z "${PORT}" ];then
  echo "Missing port"
  exit 1
fi

if [ -z "${SNI}" ];then
	openssl s_client -connect ${SERVER}:${PORT} </dev/null | openssl x509 -noout -ext subjectAltName
else
	openssl s_client -connect ${SERVER}:${PORT} -servername ${SNI} </dev/null | openssl x509 -noout -ext subjectAltName

fi
