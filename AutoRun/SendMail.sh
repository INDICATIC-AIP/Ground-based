#!/bin/bash
source .env
#Send email in case of error.

echo "$2" | mail -s "$1" "$JJAEN_EMAIL"
#echo "$2" | mail -s "$1" "$JROBLES_EMAIL"




