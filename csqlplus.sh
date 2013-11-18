#!/bin/bash

# Cluster SQL*Plus
# Tool to query multiple databases in one command, useful in large environments
#
# Copyright (C) 2013 Simon Krenger <simon@krenger.ch>
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

QUERY=
QUERY_FILE=
VERBOSE=0
USERNAME=simon
PASSWORD=
INVENTORY_FILE=

usage()
{
cat << EOF
usage: $0 <-q "query"|-f "filename"> <-i "inventory_file"> <-p "password">
	  [-u "username"] [-v] [-h] [-?]

Tool to query multiple databases in one command, useful in large environments

OPTIONS:
   -h      Show this message
   -q	   Query to be executed. Provide this in quotes (""), don't forget ";"
   -f	   File that contains the query
   -i	   Inventory file containing all databases to be queried
   -u	   Username to be used for queries (Defaults to '$USERNAME')
   -p	   Password to be used for queries
   -v      Verbose
EOF
}


while getopts "hq:f:i:u:p:v" OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         q)
             QUERY=$OPTARG
             ;;
	 f)
	     QUERY_FILE=$OPTARG
	     ;;
	 i)
	     INVENTORY_FILE=$OPTARG
	     ;;
	 u)
	     USERNAME=$OPTARG
	     ;;
	 p)
	     PASSWORD=$OPTARG
             ;;
	 v)
	     VERBOSE=1
	     ;;
         ?)
             usage
             exit
             ;;
     esac
done

# Prepare query

if [[ ! -z "$QUERY_FILE" ]]
then
	if [ $VERBOSE -eq 1 ]; then
		echo "Reading query from ${QUERY_FILE}..."
	fi
	QUERY=$(cat $QUERY_FILE) # This is only temporary (to perform some checks)
fi

# Make sure every parameter is set as needed

if [[ -z "$QUERY" ]]
then
	echo 'ERROR: Query string (-q or -f) not provided'
	usage
	exit 1
fi

if [[ -z "$INVENTORY_FILE" ]]
then
        echo 'ERROR: Inventory file (-i) not provided or does not exist'
        usage
        exit 1
fi

if [[ -z "$USERNAME" ]]
then
        echo 'ERROR: Username (-u) not provided'
        usage
        exit 1
fi

if [[ -z "$PASSWORD" ]]
then
        echo 'PASSWORD: Password (-p) not provided'
        usage
        exit 1
fi

if [ $(echo "$QUERY" | grep -i -E "INSERT|DELETE|UPDATE|MERGE|CREATE|ALTER|DROP|TRUNCATE|COMMIT" | wc -l) -gt 0 ]; then
	echo "ERROR: Query contains DML/DDL statements"
	echo "ERROR: You shouldn't use this tool to execute DML/DDL"
	exit 1
fi

# Check software prereqs
command -v sqlplus >/dev/null 2>&1 || { echo >&2 "ERROR: I require sqlplus but it's not installed.  Aborting."; exit 1; }
command -v tnsping >/dev/null 2>&1 || { echo >&2 "ERROR: I require tnsping it's not installed.  Aborting."; exit 1; }

## Alright, we're ready to go
## Main part of script starts here

# Prepare SQL script
SQLFILE=$(mktemp) || exit 1
if [[ -z "$QUERY_FILE" ]]; then
	# Prepare SQL script
	echo "set linesize `tput cols`" >> $SQLFILE
	echo "set pagesize 1000" >> $SQLFILE
	echo "$QUERY" >> $SQLFILE
	echo "quit" >> $SQLFILE # Append "quit"
else
	# We assume that everything is set as needed in the SQL file
	cp "$QUERY_FILE" "$SQLFILE"
fi

# Prepare "clean" inventory file
CLEAN_INVENTORY=$(mktemp) || exit 1

# Before executing queries, tnsping every DB and make a new CLEAN_INVENTORY
while read TNSNAME
do
	tnsping $TNSNAME >/dev/null 2>&1
	if [ $? -eq 0 ]; then
		echo $TNSNAME >> $CLEAN_INVENTORY	
	else
		echo "WARN: 'tnsping $TNSNAME' did return something other than 0, ommitting $TNSNAME..."
	fi
done < "$INVENTORY_FILE"

if [ $VERBOSE -eq 1 ]; then
	echo "Validation complete, now executing queries..."
fi

## Main loop
while read TNSNAME
do
	if [ $VERBOSE -eq 1 ]; then
		echo "$USERNAME@$TNSNAME:"
	fi
	sqlplus -S $USERNAME/$PASSWORD@$TNSNAME @${SQLFILE}

done < "$CLEAN_INVENTORY"

# Clean up
rm $SQLFILE
rm $CLEAN_INVENTORY
