#!/bin/bash

####################################################################
# add_postgres_dbs_roles ()
# adds postgres db, roles, role limit and permissions for known applications
# example usage after loading function into the buffer:
# ./PostgreSQLaddroleanddbs.sh tst-psql tst-rg tstcorekv pgSecret
#####################################################################
    PSQLSERVER=$1
    RESOURCE_GROUP=$2
    PGKEYVAULT=$3
    PGSECRET=$4
    DATE=$(date +"%Y%m%d%H%M%S")
    LOGFILE=/tmp/psql_dbroles${DATE}.log

#Install psql on the on Ubuntu
echo "Running update and installing psql"
sudo apt-get update -y
sudo apt-get install postgresql -y
#Get the password for the instance
SECRETID=$(az keyvault secret list --vault-name "$PGKEYVAULT" --query "[?name=='$PGSECRET'].{id:id}" -o tsv)
PSPASS=$(az keyvault secret show --id "$SECRETID" --query value -o tsv)
export PGPASSWORD=$PSPASS
#Need to get the hostname and login
LOGIN=$(az postgres flexible-server list --query "[?name=='$PSQLSERVER'].{administratorLogin:administratorLogin}" -o tsv)
FQDN=$(az postgres flexible-server list --query "[?name=='$PSQLSERVER'].{fullyQualifiedDomainName:fullyQualifiedDomainName}" -o tsv)
#Loop through the known roles and databases  
dbs=( db list)
for db in ${dbs[@]}  
do
#Set the password for the role 
PASS=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)
#add the password secret to the vault
#clean up the quotes 
DBCLEAN=$(echo "$db" | tr '"' ' ')
#clean the space off the end
DB=$(echo ${DBCLEAN% *})

DBSECRETNAME=$(echo "$DB""-admin-password")

az keyvault secret set --name "$DBSECRETNAME" --vault-name "$PGKEYVAULT" --value "$PASS" --tags "type=pgdbpass"
#Create the db and role
echo "
		CREATE ROLE $db LOGIN PASSWORD '$PASS';
        grant $db to postgres;
        alter role $db with login;
        ALTER role $db CONNECTION LIMIT 250;
		create database $db with owner $db;
        GRANT CONNECT ON DATABASE $db TO $db;
        GRANT USAGE ON SCHEMA public TO $db;
        GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $db;
        GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $db;
        " > /tmp/dbroles.sql
        echo "adding db and role for $db" | tee -a "$LOGFILE"
        psql -h "$FQDN" -U "$LOGIN" -p 5432 -d postgres -f /tmp/dbroles.sql | tee -a "$LOGFILE"
done
    #Clean up the dbroles.sql file
    rm -f /tmp/dbroles.sql

    #output database listings
    echo "Listing databases added to instance" | tee -a "$LOGFILE"
    psql -h "$FQDN" -U "$LOGIN" -p 5432 -d postgres -c '\l'| tee -a "$LOGFILE"
    echo "Listing roles added to instance" | tee -a "$LOGFILE"
    psql -h "$FQDN" -U "$LOGIN" -p 5432 -d postgres -c '\dg'| tee -a "$LOGFILE"

    echo "Successfully added roles, dbs, extensions, and needed permissions ""$PSQLSERVER""."
    echo "If this script is run more than once, a few of the psql calls will cause errors that a resource is already created or exists. This can safely be ignored."
}
