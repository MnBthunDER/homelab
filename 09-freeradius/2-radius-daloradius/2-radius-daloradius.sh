# Daloradius creates a web interface for managing FreeRADIUS users and settings.
# [Worked] How to Install FreeRADIUS and daloRADIUS on Ubuntu 22.04 | VPS Tutorial
https://www.youtube.com/watch?v=B72VhIFnubU

# Make sure FreeRADIUS is configured to use MySQL/MariaDB
# daloRADIUS stores its users and configuration in a database, so FreeRADIUS must be using the SQL module.

# Check 
nano /etc/freeradius/3.0/mods-enabled/sql

server = "localhost"
login = "daloradius"
password = "YOUR_DB_PASSWORD"
radius_db = "radius"

authorize {
    ...
    sql
    ...
}

accounting {
    ...
    sql
    ...
}

session {
    ...
    sql
    ...
}


# 1. Enable the SQL module
cd /etc/freeradius/3.0/mods-available/
ls | grep sql

# You should see a file named sql.

# Then enable it:

ln -s ../mods-available/sql ../mods-enabled/sql

# 2. Configure SQL module

# Edit /etc/freeradius/3.0/mods-enabled/sql:

driver = "rlm_sql_mysql"

server = "localhost"
login = "daloradius"
password = "YOUR_DB_PASSWORD"
radius_db = "radius"
port = 3306

# Make sure rlm_sql_mysql is installed:

sudo apt install freeradius-mysql

# 3. Update sites to use SQL

# Edit /etc/freeradius/3.0/sites-enabled/default and inner-tunnel:

# Find the authorize {} section and add sql:

authorize {
    ...
    sql
    ...
}


# Do the same for accounting {} and optionally session {}.

# 1️⃣ Enable the SQL module
ln -s /etc/freeradius/3.0/mods-available/sql /etc/freeradius/3.0/mods-enabled/sql


# Check it’s linked:
ls -l /etc/freeradius/3.0/mods-enabled/ | grep sql


# You should see sql -> ../mods-available/sql.

# 2️⃣ Configure the SQL module
nano /etc/freeradius/3.0/mods-enabled/sql:

driver = "rlm_sql_mysql"

server = "localhost"
login = "daloradius"
password = "YOUR_DB_PASSWORD"
radius_db = "radius"
port = 3306

# Optional: make sure connection pool is enabled
pool {
    start = 5
    min = 3
    max = 32
    spare = 3
    retry_delay = 5
}

# Solutions
# Option 1 — Disable TLS for MySQL (easiest since everything is hosted locally on the same VM)

# Edit /etc/freeradius/3.0/mods-enabled/sql:

nano /etc/freeradius/3.0/mods-enabled/sql


# Find the tls block and comment it out or disable it:

# tls {
#    ca_file = "/etc/ssl/certs/my_ca.crt"
# }


# Save, then test:

freeradius -X