#!/bin/bash

set -e

if [ "$EUID" -ne 0 ]
    then echo "Please run as root"
    exit 1
fi


NEO4J_BACKUP=$1

if [ ! -f $NEO4J_BACKUP ]; then
    echo "Arg should be a backup file!"
    exit 1
fi


NOW=`date +%Y%m%d%H%M%S`
DB_DIR=/opt/webapps/data/neo4j/databases/graph.db
DUMP=$HOME/stage-backup-$NOW.pg_dump
export PGHOST=ehri-web-01

# backup PostgresQL:
echo Backing up existing staging PostgreSQL database...
pg_dump --format=c --create --user=docview_stage --host=$DB_HOST docview_stage > $DUMP

# load from prod
echo Loading PostgreSQL from prod...
# NB: This only works if the table schema has been 
psql -e docview_stage -U docview_stage -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
pg_dump --no-owner --no-acl --user=docview docview | psql --user=docview_stage docview_stage

echo Updating Neo4j...
tar zcf $HOME/stage-backup-$NOW-graph.db.tar.gz -C $DB_DIR $DB_DIR && \
    sudo rm -rf $DB_DIR/* && \
    sudo service neo4j-service stop && \
    tar zxf $NEO4J_BACKUP -C $DB_DIR && \
    sudo chown neo4j.webadm -R $DB_DIR && \
    sudo service neo4j-service start

echo Done
