# Testing the final configuration for Data Guard installation


1. From the compute source, ssh into any of the Azure VMs:
```
$ ssh -i ~/.ssh/lza-oracle-data-guard  oracle@<PUBLIC_IP_ADDRESS>
```

2. Check the Oracle related environment variables:
```
$ env | grep -i oracle
```

3. Connect to the database:
```
$ sqlplus / as sysdba
SQL> show user
```

<img src="../media/test.jpg" />


Congratulations!!! Now, you have a functional Oracle DBs running on the Azure VM with Data Guard replication.