#!/bin/sh

echo "unsigned char $1[] = { "
xxd -i -
echo " };"
