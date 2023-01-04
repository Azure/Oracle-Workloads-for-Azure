## Sizing Azure resources based on an Oracle AWR report

This package consists of a PDF (i.e. "`AWR Sizing Instructions.pdf`") containing a set of instructions for extracting a small set of metrics from an Oracle AWR report into a spreadsheet.  The spreadsheet (i.e. "`AWR Analysis (template) YYYYMMDD.xls`") will then summarize and extrapolate these metrics into estimates used for sizing the on-prem database on Azure virtual machines and storage.

At present, the spreadsheet does not use the estimated recommendations for CPU, RAM, IOPS, and I/O throughput to automatically pull recommended Azure instance types and storage options;  creating recommendations from the calculations is still quite manual, unfortunately.

To assist with the often-onerous data entry task of copying the correct fields from the Oracle AWR report into the first worksheet of the spreadsheet, the bash script "`awr_capture.sh`" parses the AWR reports in the present working directory, whether in text format or in HTML format AWR, and populates a comma-separated values (".csv") file named "fixed_output.csv".  This script has been tested against AWR reports from the following Oracle database versions: 11.1.0.7.0, 11.2.0.3.0, 11.2.0.4.0, 12.1.0.2.0, 12.2.0.1.0, 18.0.0.0.0, and 19.0.0.0.0.

To obtain the most accurate observed information from an AWR report, please consider using output from the SQL script "`busiest_awr.sql`" to find peak workloads with the Oracle AWR repository from which to calculate sizing, using a minimum of extrapolation and guesswork.

Because the Oracle AWR report does not contain any information about database size, please consider running and sharing output from the SQL\*Plus script "`dbspace.sql`", which summarizes datafile, tempfile, controlfile, online redo logfile, and block change tracking file sizes.  It also summarizes information about archived redo logfiles and RMAN backupsets by day, to provide a sense of the actual data change rate in the database.
