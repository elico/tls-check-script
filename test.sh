#!/usr/bin/env bash

# OpenSSL requires the port number.
SERVER="$1"
PORT="$2"

if [ -z "${SERVER}" ];then
  echo "Missing destination server/domain/ip"
  exit 1
fi

if [ -z "${PORT}" ];then
  echo "Missing port"
  exit 1
fi


DELAY=1
ciphers=$(openssl ciphers 'ALL:eNULL' | sed -e 's/:/ /g')

echo Obtaining cipher list from $(openssl version).

for cipher in ${ciphers[@]}
do
  echo -n Testing $cipher...
  result=$( echo -n| openssl s_client -cipher ${cipher} -connect ${SERVER}:${PORT} 2>&1)
  if [[ "$result" =~ ":error:" ]] ; then
    error=$(echo -n $result | cut -d':' -f6)
    echo NO \($error\)
  else
    if [[ "$result" =~ "Cipher is ${cipher}" || "$result" =~ "Cipher    :" ]] ; then
      echo YES
    else
      echo UNKNOWN RESPONSE
      echo $result
    fi
  fi
  sleep $DELAY
done
