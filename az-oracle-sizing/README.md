# Sizing Azure resources based on an Oracle AWR report

This package consists of a PDF (i.e. "`AWR Sizing Instructions.pdf`") containing a set of instructions for extracting a small set of metrics from an Oracle AWR report into a spreadsheet.  The spreadsheet (i.e. "`AWR Analysis (template) YYYYMMDD.xls`") will then summarize and extrapolate these metrics into estimates used for sizing the on-prem database on Azure virtual machines and storage.

At present, the spreadsheet does not use the estimated recommendations for CPU, RAM, IOPS, and I/O throughput to automatically pull recommended Azure instance types and storage options;  creating recommendations from the calculations is still quite manual, unfortunately.

### Assist finding "peak" workload for most-effective sizing in Azure

To obtain the most accurate observed information from an AWR report, please consider using output from the SQL script "`busiest_awr.sql`" to find peak workloads with the Oracle AWR repository from which to calculate sizing, using a minimum of extrapolation and guesswork.  Same is true with Oracle STATSPACK, the open-source replacement package for AWR -- use the SQL script "`busiest_statspack`" to find peak workloads in the STATSPACK repository.  Sizing new resources in Azure from peak workloads is REALLY important;  non-peak workloads can be misleading.  If you don't already know what snapshots contain peak workloads, then please consider downloading and using "`busiest_awr.sql`" (for AWR) or "`busiest_statspack.sql`" for STATSPACK.

# Finding database capacity info not found in AWR/STATSPACK

Because the Oracle AWR report does not contain any information about database size, or any information at all regarding the size of any structures in storage, please consider running and sharing output from the SQL\*Plus script `dbspace.sql`, which summarizes datafile, tempfile, controlfile, online redo logfile, and block change tracking file sizes.  It also summarizes information about archived redo logfiles and RMAN backupsets by day, to provide a sense of the actual data change rate in the database.

There are several sections in the output of the `dbspace.sql` script, which are explained in detail below...

## 1. Display database file structure sizes...

This first section displays the total size (in MiB) of various data structures in the Oracle database...
```
  File type     DB Size (MB)
  ---------- ---------------
  Ctlfile             234.28
  Datafile      6,759,033.13
  OnlineRedo      327,680.00
  Tempfile      1,048,576.00
             ---------------
  sum           8,135,523.41
```
In this example, the total Oracle database is 8,135,523.41 MiB in size, or about 7.75 TiB.

## 2. Information about Exadata Hybrid-Columnar Compression (HCC)

This section displays information about compressed table segments by any of the forms of compression available within Oracle.  BASIC and ADVANCED compression is noted although it does not impact overall database sizing.

However, Exadata hybrid-columnar compression (HCC) is available only within Oracle Exadata platforms, and HCC compressed table segments are unusable outside of Exadata.  So any database that uses HCC and is migrated away from Exadata will need to use the Oracle ALTER TABLE ... COMPRESS ... command to recompress any HCC tables as either BASIC or ADVANCED (a.k.a. OLTP) compressed table segments.  In general, this means that the segments will grow in size, as the compression ratio for BASIC and ADVANCED compression is far less than for HCC (i.e. QUERY LOW, QUERY HIGH, ARCHIVE LOW, and ARCHIVE HIGH compression).  Here is a rough estimation of the usual expected compression ratios for each type of Oracle table compression method...

  ARCHIVE HIGH           = 18:1 compression ratio
  ARHIVE LOW             = 15:1 compression ratio
  QUERY HIGH             = 10:1 compression ratio
  QUERY LOW              =  6:1 compression ratio
  ADVANCED (a.k.a. OLTP) =  3:1 compression ratio
  BASIC                  =  3:1 compression ratio

Of course, actual compression ratios will vary dependent on the data itself, but these are reasonable values for setting expectations.

Here is sample output of this information from a "dbspace.sql" script...
```
                                                                                          Addl MB after
  Segment Type       Enabled? Compression Type               Read-Only   Seg Size (MB)   Recompression   # Segs
  ------------------ -------- ------------------------------ --------- --------------- --------------- --------
  TABLE              DISABLED                                             4,259,629.25                    2,361
                     ENABLED  ADVANCED                                    2,242,942.91                    3,416
                              ARCHIVE HIGH                                   85,285.56    1,279,283.40      111
  TABLE PARTITION    DISABLED                                             8,428,884.00                    1,926
                     ENABLED  ADVANCED                                    3,027,607.06                    9,558
  TABLE SUBPARTITION DISABLED                                             2,595,070.00                    3,225
                     ENABLED  ADVANCED                                      909,540.00                      990
  ****************** ******** ****************************** ********* --------------- --------------- --------
  sum                                                                    21,548,958.78    1,279,283.40   21,587
```
Above, we see that most tables, table partitions, and table subpartitions are not compressed (i.e. DISABLED).

We also see that there are 3,416 tables, as well as 1,926 table partitions, and 3,225 table subpartitions that are compressed using ADVANCED (a.k.a. OLTP) compression.  The BASIC and ADVANCED levels of compression are available to non-Exadata Oracle, so there is no need to calculate additional space for these tables.

But please notice that there are 111 tables that are compressed using ARCHIVE HIGH, which is one of the four levels of HCC (i.e. QUERY LOW, QUERY HIGH, ARCHIVE LOW, and ARCHIVE HIGH).  Since HCC compression is available only in Exadata, these 111 tables must be recompressed to BASIC or ADVANCED compression, which will possibly increase the amount of space needed by the database by 1,279,283.40 MB or a little over 1 TB.  Given that the total amount of space consumed by table data is shown to be 21 TB, an additional 1 TB would increase the storage needed significantly, which is good information to have in advance.

## 3. Display information about online redo log files

Although the storage capacity for the online redo log files are included in the summary of database size at the top of the report, it is occassionally useful to know how the online redo log files have been configured.  For example, it is possible to cripple the performance of the database by making the online redo log file groups too small (i.e. less than 500 MB each), thus possibly forcing "log switch" operations several times per second, or every few seconds.  Ideally, the frequency of "log switch" operations should be no more than once every 1-5 minutes or so, as a rough "rule of thumb".

Here we see an example from a two-node Oracle RAC database...
```
      Thread      Group    Members Member Size (MB)
  ---------- ---------- ---------- ----------------
           1          1          2         4,096.00
                      2          2         4,096.00
                      5          2         4,096.00
                      6          2         4,096.00
           2          3          2         4,096.00
                      4          2         4,096.00
                      7          2         4,096.00
                      8          2         4,096.00
  ********** ********** ********** ----------------
  sum                                     32,768.00
```
This depicts two instances (i.e. expressed as "threads of redo").  Each database instance (or "thread of redo") in the RAC cluster has 4 groups of online redo log files, and each group consists of two mirrored members, each member sized 4 GiB.  The summation of the column headed "Member Size (MB)" is inaccurate, as it does not take into account that each group has two members.  So, in reality, there is 65,536 MiB of storage consumed by online redo log files, not 32,768 MiB as implied by the simple SUM function of Oracle SQL\*Plus.

## 4. Display information about RMAN backups...

The script dumps information about RMAN backups stored within the database's control files, known as the recovery catalog.  The recovery catalog stores information about full backups, incremental backups, and archivelog backups for a period of days configured by the Oracle initialization parameter CONTROLFILE_RECORD_KEEP_TIME.  An example for this section might look like...

```
                                         Source              Backup       Database file
              Bkup     Incr            database                read      backup written
  Day         Type      Lvl          files (MB)                (MB)                (MB)
  ----------- ------- ----- ------------------- ------------------- -------------------
  29-JAN-2023 IncrBkp     1       37,796,656.00          405,581.19          405,581.19
  30-JAN-2023 IncrBkp     1       40,819,504.00          217,334.31          217,334.31
  31-JAN-2023 IncrBkp     1       40,819,504.00          614,861.34          614,861.34
  01-FEB-2023 IncrBkp     1       40,819,504.00          324,451.88          324,451.88
  02-FEB-2023 IncrBkp     0       27,254,752.00       27,254,752.00       22,880,853.03
  03-FEB-2023 IncrBkp     0       13,564,752.00       13,564,752.00       12,326,881.38
              IncrBkp     1       40,819,504.00          616,958.63          616,958.63
  04-FEB-2023 IncrBkp     1       40,819,504.00          459,816.25          459,816.25
  05-FEB-2023 IncrBkp     1       40,819,504.00          456,057.38          456,057.38
  06-FEB-2023 IncrBkp     1       40,819,504.00          797,272.56          797,272.56
  07-FEB-2023 IncrBkp     1       40,819,504.00        1,448,852.25        1,448,852.25
  08-FEB-2023 IncrBkp     1       40,819,504.00          292,773.28          292,773.28
  09-FEB-2023 IncrBkp     0       32,174,048.00       32,174,048.00       27,539,083.53
  10-FEB-2023 IncrBkp     0        8,645,456.00        8,645,456.00        7,988,235.69
              IncrBkp     1       40,819,504.00        1,156,743.75        1,156,743.75
  11-FEB-2023 IncrBkp     1       40,819,504.00          989,997.72          989,997.72
  12-FEB-2023 IncrBkp     1       40,819,504.00          508,188.78          508,188.78
  13-FEB-2023 IncrBkp     1       40,819,504.00          656,777.56          656,777.56
  14-FEB-2023 IncrBkp     1       40,819,504.00          553,422.97          553,422.97
  15-FEB-2023 IncrBkp     1       40,880,944.00          510,532.81          449,893.00
  16-FEB-2023 IncrBkp     0       24,453,088.00       24,453,088.00       20,743,186.19
  17-FEB-2023 IncrBkp     0       16,427,856.00       16,427,856.00       14,849,655.81
              IncrBkp     1       40,880,944.00          644,308.72          644,308.72
  18-FEB-2023 IncrBkp     1       40,880,944.00          687,478.28          687,478.28
  19-FEB-2023 IncrBkp     1       40,880,944.00          229,858.72          229,858.72
  20-FEB-2023 IncrBkp     1       40,880,944.00          469,111.13          469,111.13
  21-FEB-2023 IncrBkp     1       40,880,944.00          526,640.00          526,640.00
  22-FEB-2023 IncrBkp     1       40,880,944.00          353,403.47          353,403.47
  23-FEB-2023 IncrBkp     0       29,716,448.00       29,716,448.00       25,282,737.91
  24-FEB-2023 IncrBkp     0       11,164,496.00       11,164,496.00       10,314,248.34
              IncrBkp     1       40,880,944.00          502,596.50          502,596.50
  25-FEB-2023 IncrBkp     1       40,880,944.00          359,052.13          359,052.13
  26-FEB-2023 IncrBkp     1       40,880,944.00          430,084.03          430,084.03
  27-FEB-2023 IncrBkp     1       40,880,944.00          516,415.31          516,415.31
  28-FEB-2023 IncrBkp     1       40,880,944.00        1,015,916.16        1,015,916.16
  01-MAR-2023 IncrBkp     1       40,880,944.00          667,853.25          667,853.25
  02-MAR-2023 IncrBkp     0       24,227,808.00       24,227,808.00       20,576,231.41
  03-MAR-2023 IncrBkp     0       16,653,136.00       16,653,136.00       15,140,953.09
              IncrBkp     1       40,880,944.00          625,086.28          625,086.28
  04-MAR-2023 IncrBkp     1       40,880,944.00          530,576.28          530,576.28
  05-MAR-2023 IncrBkp     1       40,880,944.00          284,922.22          284,922.22
  06-MAR-2023 IncrBkp     1       40,885,040.00          715,624.91          715,624.91
  07-MAR-2023 IncrBkp     1       40,885,040.00        1,029,670.75        1,029,670.75
  08-MAR-2023 IncrBkp     1       40,885,040.00        1,110,946.41        1,110,946.41
  09-MAR-2023 IncrBkp     0       30,320,608.00       30,320,608.00       25,904,667.31
  10-MAR-2023 IncrBkp     0       10,564,432.00       10,564,432.00        9,915,207.25
              IncrBkp     1       40,885,040.00          761,433.25          761,433.25
  11-MAR-2023 IncrBkp     1       41,253,680.00        1,016,602.66          651,588.41
  12-MAR-2023 IncrBkp     1       41,253,680.00          607,314.94          607,314.94
  13-MAR-2023 IncrBkp     1       41,253,680.00          609,527.91          609,527.91
  14-MAR-2023 IncrBkp     1       41,253,680.00          837,074.72          837,074.72
  15-MAR-2023 IncrBkp     1       41,253,680.00          278,564.97          278,564.97
  16-MAR-2023 IncrBkp     0       30,235,968.00       30,235,968.00       25,829,247.84
  17-MAR-2023 IncrBkp     0       11,017,712.00       11,017,712.00       10,065,311.81
              IncrBkp     1       41,253,680.00          331,136.72          331,136.72
  18-MAR-2023 IncrBkp     1       41,253,680.00          414,660.84          414,660.84
  19-MAR-2023 IncrBkp     1       41,253,680.00          579,187.59          579,187.59
  20-MAR-2023 IncrBkp     1       41,253,680.00          536,361.97          536,361.97
  21-MAR-2023 IncrBkp     1       41,253,680.00          439,031.84          439,031.84
  22-MAR-2023 IncrBkp     1       41,253,680.00          263,723.63          263,723.63
  23-MAR-2023 IncrBkp     0       15,704,960.00       15,704,960.00       14,220,227.13
  24-MAR-2023 IncrBkp     0       25,548,720.00       25,548,720.00       21,702,067.78
              IncrBkp     1       41,253,680.00          314,852.19          314,852.19
  25-MAR-2023 IncrBkp     1       41,253,680.00          268,959.88          268,959.88
```
<i>(...several dozen lines removed for brevity...)</i>
```
  29-APR-2023 IncrBkp     1       41,868,080.00          471,231.09          471,231.09
  30-APR-2023 IncrBkp     1       41,868,080.00          657,324.09          657,324.09
  01-MAY-2023 IncrBkp     1       41,868,080.00          706,481.19          706,481.19
  02-MAY-2023 IncrBkp     1       41,868,080.00        1,245,495.94        1,245,495.94
  03-MAY-2023 IncrBkp     1       41,868,080.00          521,086.72          521,086.72
  ***********               ------------------- ------------------- -------------------
                               3,917,833,936.00      587,009,105.59      517,632,399.88
```
Besides displaying information about the incremental backup strategy shown here, where full "level=0" backups are started each Thursday, followed by incremental "level=1" backups the other six (6) days of the week, we also get a good idea about the volume of data being changed each day.

For example, focusing on a seven (7) day period from the report...
```
                                         Source              Backup       Database file
              Bkup     Incr            database                read      backup written
  Day         Type      Lvl          files (MB)                (MB)                (MB)
  ----------- ------- ----- ------------------- ------------------- -------------------
  16-MAR-2023 IncrBkp     0       30,235,968.00       30,235,968.00       25,829,247.84
  17-MAR-2023 IncrBkp     0       11,017,712.00       11,017,712.00       10,065,311.81
              IncrBkp     1       41,253,680.00          331,136.72          331,136.72
  18-MAR-2023 IncrBkp     1       41,253,680.00          414,660.84          414,660.84
  19-MAR-2023 IncrBkp     1       41,253,680.00          579,187.59          579,187.59
  20-MAR-2023 IncrBkp     1       41,253,680.00          536,361.97          536,361.97
  21-MAR-2023 IncrBkp     1       41,253,680.00          439,031.84          439,031.84
  22-MAR-2023 IncrBkp     1       41,253,680.00          263,723.63          263,723.63
```
We see that the "level = 0" or full incremental backup started on 16-March, but continued running into 17-March.  About 30 TB or about 75% of the full level=0 backup was completed on 16-March, while the remaining 11 TB or about 25% of the full level=0 backup was completed on the morning of 17-March.  As a result, we see two lines in the report, for 16-March and 17-March, that might look like two separates backup jobs, but were in fact a single backup job extending across the two days.

Following that, each daily incremental "level=1" backup is shown scanning all 41 TB of the database.  However, each day only shows between 330 GB and 579 GB of "Backup read (MB)" and "Database file backup written (MB)", despite 41 TB of database being scanned.  This is due to the nature of level=1 incremental backups.  The entire database was scanned, but only 330-579 GB of data was backed up, because that was the volume of data changes for that 24-hour period.

This gives us an indication of the daily rate of change for the database.  If use an average figure of 512 GB for the range between 330 GB and 579 GB, which is convenient because 512 GB is half a terabyte, then we can easily figure out that 512 GB out of a total of 41 TB is a rate of change of about 1.2%.  This information can help us project the possible growth rate of the database over the upcoming months and years.  Of course, it is important to bear in mind that not all data changes captured by RMAN incremental backups are due to INSERT operations, and many might in fact be UPDATE operations (which probably do not change the volume of data significantly), or even DELETE operations (which can reduce the volume of data).  Some knowledge of the behavior of the application is helpful, as many OLTP/transactional applications are probably only 33% - 50% INSERTs, while most analytic applications are likely 80-95% INSERT operations.

## 5. Display information from V$ARCHIVED_LOG

The last bit of information that is important to know for sizing Oracle databases is the daily volume of transactions generated, in the form of archived redo log files generated from the database instance.  Earlier forms of this report would simply list each day's total of archived redo log files, which made for a too-lengthy report as well as required some guesswork from the user to determine a good value to use for sizing.

The current form of this report now summarizes all of the daily information and produces a range of values that can be used for sizing, dependent on preference.

Here we use the [Empirical Rule](https://en.wikipedia.org/wiki/68%E2%80%9395%E2%80%9399.7_rule), also known as the 68-95-99.7 rule, to provide possible values for daily volume of transactions generated using the following percentiles...

- 50th percentile (a.k.a. average or mean value)
- 68th percentile (a.k.a. average or mean value, plus one standard deviation)
- 95th percentile (a.k.a. average or mean value, plus two standard deviations)
- 99.7th percentile (a.k.a. average or mean value, plus three standard deviations)
- 100th percentile (a.k.a. maximum value)

Most with some statistical training will not use average values because they just as likely to be too low as too high, and the same assumption might apply for the value at the 68th percentile as well.

Likewise, most with some statistical training will not use the maximum values because they are bound to be unrealistically high, and the same assumption might apply for the value at the 99.7th percentile as well.

That leaves the value at the 95th percentile as the best value to use when sizing the daily volume of transactions generated.

Therefore, given the following output...
```
                       Avg         Avg+1sd         Avg+2sd         Avg+3sd             Max
             (50th pctile)   (68th pctile)   (95th pctile) (99.7th pctile)  (100th pctile)
                  Archived        Archived        Archived        Archived        Archived
    # days  redo Size (MB)  redo Size (MB)  redo Size (MB)  redo Size (MB)  redo Size (MB)
  -------- --------------- --------------- --------------- --------------- ---------------
        62    2,194,153.67    3,710,167.20    5,226,180.74    6,742,194.27    7,639,722.97
```
...the value of 5,226,180.74 MB (or about 5 TB) per day would be a responsible sizing estimate.

## 6. Display information from V$BACKUP_REDOLOG

The last section reported by the "dbspace.sql" script is included merely for informational purposes.  It is of course related to the information in the section above, but this section has to do with RMAN backups of the archived redo log files.  So, depending on whether such backups are being performed, or how they are being performed, we might see the information in this section approximately match the information in the section above, or we might see something like this...
```
                       Avg         Avg+1sd         Avg+2sd         Avg+3sd             Max
             (50th pctile)   (68th pctile)   (95th pctile) (99.7th pctile)  (100th pctile)
                  Archived        Archived        Archived        Archived        Archived
    # days  redo Size (MB)  redo Size (MB)  redo Size (MB)  redo Size (MB)  redo Size (MB)
  -------- --------------- --------------- --------------- --------------- ---------------
        96      743,772.17    1,230,025.09    1,716,278.01    2,202,530.93    2,546,574.32
```
...the most prominent thing about the information seen above is that is significantly smaller than the information shown in the section above.  The reason for this difference is almost certainly due to the use of compressed RMAN backups of the archived redo log files.

Again, this last section in the report doesn't usually share information useful for sizing Oracle databases in Azure, but it is included simply because the information might be useful in troubleshooting or other situations.

## Summary - how to use this information during a sizing exercise

Sizing an Oracle database in Azure requires at least eight (8) metrics to be captured...

1. Actual observed CPU utilization by the Oracle database instance(s) <i>(captured in standard Oracle AWR or STATSPACK report)</i>
2. Actual observed memory utilization by the Oracle database instance(s)<i>(captured in standard Oracle AWR or STATSPACK report)</i>
3. Actual observed I/O utilization by the Oracle database instance(s)<i>(captured in standard Oracle AWR or STATSPACK report)</i>
4. Size of the database <i>(captured by the "dbspace.sql" report)</i>
    - Please use the information as described in section 1 above
5. Daily volume of transactions <i>(captured by the "dbspace.sql" report)</i>
    - Please use the information as described in section 4 above
6. Estimated annual growth rate <i>(captured by the "dbspace.sql" report)</i>
    - Please use the information as described in section 5 above
7. Recovery point objective (RPO) <i>(determined from application end-user management)</i>
    - also known as the <i>tolerance for data loss following a failure</i>
8. Recovery time objective (RTO) <i>(determined from application end-user management)</i>
    - also known as the <i>expectation for return-to-service following an outage</i>
