# Install Oracle Database 19c with Ansible

These roles configure Oracle Database prerequisites and install it for CentOS 7.

## Requirements

- CentOS 7.7 or later
- Ansible 2.9
- Installation media file distributed by oracle.com

## Install the Oracle Database software to a target host

Place the installation media file into roles/oracle19c/files/, configure your inventory and run ansible-playbook.

```
$ cp /foo/bar/LINUX.X64_193000_db_home.zip roles/oracle19c/files/
$ ansible-playbook -i inventory.yml playbook.yml oracle -k -K
```

# After installation

You can use the database with SID `orcl19c`.
The default password for SYS and SYSTEM is `oracle123`.

```
$ export ORACLE_SID=orcl19c
$ sqlplus system/oracle123
SQL> quit
```

