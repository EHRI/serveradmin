#!/bin/bash

set -e

if [[ $EUID != 0 ]]; then
    echo "Please run using sudo"
    exit 1
fi

if [ -z "$PGHOST" ]; then
  echo "Error: PGHOST not set in environment"
  exit 1
fi

NEO4J_BACKUP=$1
if [ ! -f "$NEO4J_BACKUP" ]; then
    echo "Arg should be a backup file!"
    exit 1
fi

NOW=$(date +%Y%m%d%H%M%S)
DB_DIR=/opt/webapps/data/neo4j/databases/graph.db
BACKUP=$HOME/stage-backup-$NOW

# backup PostgresQL as a restore-friendly dump and also as INSERT statements...
echo Backing up existing staging PostgreSQL database...
pg_dump --create --user=docview_stage docview_stage --file "$BACKUP.pg_dump" --format=custom
pg_dump --create --user=docview_stage docview_stage --file "$BACKUP.sql.gz" --format=plain --inserts --compress=9

# load from prod
echo Loading PostgreSQL from prod...
# Drop the table schema first...
psql -e docview_stage -U docview_stage -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
pg_dump --no-owner --no-acl --user=docview docview | psql --user=docview_stage docview_stage

echo "Updating Neo4j..."
tar zcf "$HOME/stage-backup-$NOW-graph.db.tar.gz" -C $DB_DIR $DB_DIR

echo "Deleting existing DB $DB_DIR..."
rm -rf ${DB_DIR:?}/*

echo "Stopping service..."
service neo4j-service stop

echo "Extracting database $NEO4J_BACKUP to $DB_DIR..."
tar zxf "$NEO4J_BACKUP" -C $DB_DIR

echo "Setting permissions..."
chown neo4j.webadm -R $DB_DIR

echo "Restarting Neo4j..."
service neo4j-service start

echo "Done"
exit
