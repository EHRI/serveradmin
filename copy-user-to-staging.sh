#!/bin/bash

set -e

USER=$1
DB_HOST=ehri-web-01
NEO4J_HOST=ehri-portal-01
EHRI_URL=http://localhost:7474/ehri/classes/UserProfile

psql -h $DB_HOST docview -c \
    "\copy (SELECT * from users where id = '$1') TO STDOUT" | psql -h $DB_HOST docview_stage -c \
    "\copy users from stdin"

ssh $NEO4J_HOST "curl $EHRI_URL/$1" | curl -H X-User:admin -H Content-Type:application-json --data-binary @- $EHRI_URL

