# gh-ost with auto backup/restore trigger

## Introduction

Github's gh-ost does notsupport tables that have triggers. The trick here is to delete the trigger before running gh-ost (of course, back it up first) then restore the trigger back into the table once complete. 

Example output:

Instructions below for table eeziepay.fundindetails, gh-ost is running on the slave server 10.2.0.80 (it's a slave of 10.2.0.81).

## Installation

1) Download gh-ost from here, https://github.com/github/gh-ost/releases/latest : 
```bash
wget https://github.com/github/gh-ost/releases/download/v1.0.48/gh-ost-1.0.48-1.x86_64.rpm
```

2) Install the package:

```bash
yum localinstall gh-ost-1.0.48-1.x86_64.rpm 
```

3) Create gh-ost database user if does not exist, and grant it with proper privileges:

```mysql
mysql> CREATE USER 'gh-ost'@'10.2.0.80' IDENTIFIED BY 'ghostP455';
mysql> GRANT ALTER, CREATE, DELETE, DROP, INDEX, INSERT, LOCK TABLES, SELECT, TRIGGER, UPDATE ON *.* TO 'gh-ost'@'10.2.0.80';
mysql> GRANT SUPER, REPLICATION SLAVE ON *.* TO 'gh-ost'@'10.2.0.80';
```

4) Create gh-ost configuration file to store the username and password under /root/.gh-ost.cnf:

```bash
[client]
user=gh-ost
password=ghostP455
```
5) Update the script from

## Usage

Two options: `test` or `run`. Example:

```bash
./gh-ost-trigger.sh test
```
