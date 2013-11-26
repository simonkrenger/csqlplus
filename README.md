csqlplus
========

Cluster SQL\*Plus to query multiple Oracle databases in large environments

Description
-----------

This BASH script functions as a wrapper for Oracle SQL\*Plus to query multiple databases at once. It allows you to manage large environments with SQL\*Plus commands and can be used to generate reports, automate queries over many databases or just to fiddle around.

Usage
-----

The script can be used by either specifying the query to be run on the command line or use an SQL script as input.

The following example shows how to query multiple databases by specifying the query on the command line:

    ./csqlplus.sh  -q "SELECT username,account_status FROM dba_users WHERE account_status like '%LOCKED%';" -i sample/inventory.txt -p "tiger" -v

Here is another example that uses an SQL script as input:

    ./csqlplus.sh  -f sample/query.sql -i sample/inventory.txt -u "simon" -p "tiger" -v


Pitfalls
--------
Be careful when querying dynamic performance views such as "v$instance", as BASH will try to replace the "$instance" part. Instead, either escape the dollar sign or use single quotes:

    ./csqlplus.sh -q "SELECT * FROM v\$instance;" -i sample/inventory.txt -p "tiger" -v

or

    ./csqlplus.sh -q 'SELECT * FROM v$instance;' -i sample/inventory.txt -p "tiger" -v
