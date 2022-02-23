## Sizing Azure resources based on an Oracle AWR report

This package consists of a PDF (i.e. "`AWR Sizing Instructions.pdf`") containing a set of instructions for extracting a small set of metrics from an Oracle AWR report into a spreadsheet.  The spreadsheet (i.e. "`AWR Analysis (template) YYYYMMDD.xls`") will then summarize and extrapolate these metrics into estimates used for sizing the on-prem database on Azure virtual machines and storage.

At present, the spreadsheet does not use the estimated recommendations for CPU, RAM, IOPS, and I/O throughput to automatically pull recommended Azure instance types and storage options;  creating recommendations from the calculations is still quite manual, unfortunately.

To obtain the most accurate observed information from an AWR report, please consider using output from the SQL script "`busiest_awr.sql`" to find peak workloads with the Oracle AWR repository from which to calculate sizing, using a minimum of extrapolation and guesswork.

Because the Oracle AWR report does not contain any information about database size, please consider running and sharing output from the SQL\*Plus script "`dbspace.sql`", which summarizes datafile, tempfile, controlfile, online redo logfile, and block change tracking file sizes.  It also summarizes information about archived redo logfiles and RMAN backupsets by day, to provide a sense of the actual data change rate in the database.
