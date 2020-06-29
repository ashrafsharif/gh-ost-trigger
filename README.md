# gh-ost with auto backup/restore trigger

## Introduction

Github's gh-ost does not support tables that have triggers. The trick here is to delete the trigger before running gh-ost (of course, back it up first) then restore the trigger back into the table once complete.

Example output:


## Installation

Consider the following setup:

```
+--------------+                   +---------------+
|    Master    |    replication    |     Slave     |
| 192.168.0.81 | ----------------> | 192.168.0.82  |
+--------------+                   +---------------+
```

Instructions below for table mydatabase.mytable, gh-ost is installed on the slave server 192.168.0.82.

1) On Slave, download gh-ost from here, https://github.com/github/gh-ost/releases/latest :
```bash
wget https://github.com/github/gh-ost/releases/download/v1.0.48/gh-ost-1.0.48-1.x86_64.rpm
```

2) Install the package:

```bash
yum localinstall gh-ost-1.0.48-1.x86_64.rpm
```

3) On Master, create gh-ost database user if does not exist, and grant it with proper privileges:

```mysql
mysql> CREATE USER 'gh-ost'@'192.168.0.82' IDENTIFIED BY 'ghostP455';
mysql> GRANT ALTER, CREATE, DELETE, DROP, INDEX, INSERT, LOCK TABLES, SELECT, TRIGGER, UPDATE ON *.* TO 'gh-ost'@'192.168.0.82';
mysql> GRANT SUPER, REPLICATION SLAVE ON *.* TO 'gh-ost'@'192.168.0.82';
```

4) Create gh-ost configuration file to store the username and password under ``/root/.gh-ost.cnf``:

```bash
[client]
user=gh-ost
password=ghostP455
```
5) Get this script.

6) Update the relevant lines (lines 13 - 21).


## Usage

Two options: `test` or `run`. Example:

```bash
./gh-ost-trigger.sh test
```
