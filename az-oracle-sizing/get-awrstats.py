"""
Script to evaluate AWR reports from Oracle workloads and output to csv format to ingest into the 
AWRsheet of the [AWR Analysis template spreadsheet](https://github.com/Azure/Oracle-Workloads-for-Azure/blob/main/az-oracle-sizing/AWR%20Analysis%20template%20spreadsheet.xlsx).

The script does not automatically distinguish between whether US or EU notation has been used, as that is not programmatically easily detectable in the AWR. Therefore a notation
parameter has been included allow users to specify whether the AWR is US or EU notation. This only affects the Read and Write throughput numbers.


Examples

python .\get-awrstats.py --directory .\awrs\ --notation us --outputfile .\awrout.csv

Todo:
    validate on other releases than 19
    Consider better way to determine whether us/eu notation is appropriate
"""

import os
import csv
from bs4 import BeautifulSoup
import pandas as pd
import argparse
# create the argument parser object
parser = argparse.ArgumentParser()
# add the named parameters with allowed values
parser.add_argument('--directory', type=str, help='Path to the directory containing AWRs')
parser.add_argument('--notation', type=str, help='Notation string, can be either us or eu', default='us', choices=['us', 'eu'])
parser.add_argument('--outputfile', type=str, help='Path to the output csv file', default='.\output.csv')
# parse the arguments
args = parser.parse_args()
# access the named parameters using the dot notation
directory = args.directory
notation = args.notation
outputfile = args.outputfile

# Column headers for output file
csvHeaders = ['DB Name', 'Instance Name', 'Hostname', 'Elapsed Time (mins)', 'DB Time (mins)', 'DB CPU(s)', 'CPUs', 'Cores', 'Memory (GB)', '%busy CPU', 'SGA use(MB)', 'PGA use(MB)', 'Read Throughput (MB/s)', 'Write Throughput (MB/s)', 'Read IOPS', 'Write IOPS', 'Database Version', 'RAC']

def get_tables_by_summary(summaryString):
    # Find all tables with summary=<summaryString>
    tables = soup.find_all('table', {'summary': summaryString})
    # Convert each table to a Pandas DataFrame and add it to a list
    dfs = []
    for table in tables:
        headers = []
        for th in table.find_all('th'):
            headers.append(th.text.strip())
        rows = []
        for tr in table.find_all('tr')[1:]:
            row = []
            for td in tr.find_all('td'):
                row.append(td.text.strip())
            rows.append(row)
        df = pd.DataFrame(rows, columns=headers)
        dfs.append(df)
    # Concatenate all dataframes into a single one
    merged_df = pd.concat(dfs, ignore_index=True)
    return merged_df

def parse_number(numValue):
    #Determin whether us or eu notation is used for numbers    
    if notation == 'us':
        numValue = numValue.replace(",","")
    elif notation == 'eu':
        numValue = numValue.replace(",",".")
    if numValue.endswith("M"):
        # Remove the 'M' suffix and convert to float
        float_value = float(numValue[:-1])
    elif numValue.endswith("G"):
        # Remove the 'G' suffix, convert to float and multiply by 1024 to get MB
        float_value = float(numValue[:-1]) * 1024
    else:
        float_value = float(numValue)
    return float_value
    

# Main
#Initialize output file
with open(outputfile, 'w', newline='') as csvfile:
    writer = csv.writer(csvfile, delimiter=',')
    writer.writerow(csvHeaders)
# For each file in input directory
for filename in os.listdir(directory):
   file_path = os.path.join(directory, filename)
   print(file_path)
   # Open file and parse with beautifulsoup
   with open(file_path) as f:
    soup = BeautifulSoup(f, 'html.parser')
    # Get basic dbinfo information
    dbinfo = get_tables_by_summary("This table displays database instance information")
    db_name = dbinfo.loc[0, 'DB Name']
    db_edition = dbinfo.loc[0, 'Edition']
    db_release = dbinfo.loc[0, 'Release']
    db_rac = dbinfo.loc[0, 'RAC']
    db_instance = dbinfo.loc[1, 'Instance']

    if db_release == '19.0.0.0.0':
        # Get basic host information
        hostinfo = get_tables_by_summary("This table displays host information")
        host_name = hostinfo.loc[0, 'Host Name']
        host_cpus = hostinfo.loc[0, 'CPUs']
        host_cores = hostinfo.loc[0, 'Cores']
        host_memory = hostinfo.loc[0, 'Memory (GB)']

        # Get snapshot information
        snapshotinfo = get_tables_by_summary("This table displays snapshot information")
        elapsed_time = snapshotinfo.loc[2, 'Snap Time'].replace(' (mins)','') 
        db_time = snapshotinfo.loc[3, 'Snap Time'].replace(' (mins)','') 

        # Get time model statistics
        timestatsinfo = get_tables_by_summary("This table displays different time model statistics. For each statistic, time and % of DB time are displayed")
        db_cpu = timestatsinfo.loc[timestatsinfo['Statistic Name'] == 'DB CPU', 'Time (s)'].iloc[0] # run through function to handle M or G ending, and handle european notation 

        # Get CPU Usage
        cpustats = get_tables_by_summary("This table displays CPU usage and wait statistics")
        busy_cpu = cpustats.loc[0, '%Busy CPU'] # run through function to handle M or G ending, and handle european notation 

        # Get Memory statistics
        memstats = get_tables_by_summary("This table displays memory statistics")
        mem_sga = memstats.iloc[memstats.index[memstats.iloc[:, 0] == 'SGA use (MB):'][0], 1]
        mem_pga1 = memstats.iloc[memstats.index[memstats.iloc[:, 0] == 'PGA use (MB):'][0], 1]
        mem_pga2 = memstats.iloc[memstats.index[memstats.iloc[:, 0] == 'PGA use (MB):'][0], 2]
        mem_pga = max(mem_pga1, mem_pga2)
        
        #Get IO Stats
        IOstats = get_tables_by_summary("This table displays IO Statistics for different file types, such as data files, control files, log files and temp files. IO Statistics include amount of reads and writes, requests per second, data per second, wait count and average wait time")
        total_row = IOstats[IOstats['Filetype Name'] == 'TOTAL:']
        read_thru = parse_number(total_row.iloc[0, 3]) # run through function to handle M or G ending, and handle european notation 
        read_iops = total_row.iloc[0, 2]
        write_thru = parse_number(total_row.iloc[0, 6]) # run through function to handle M or G ending, and handle european notation 
        write_iops = total_row.iloc[0, 5]
        
        row = [db_name, db_instance, host_name, elapsed_time, db_time, db_cpu, host_cpus, host_cores, host_memory, busy_cpu, mem_sga, mem_pga, read_thru, write_thru, read_iops, write_iops]
        print(row)
        with open(outputfile, 'a', newline='') as csvfile:
            writer = csv.writer(csvfile, delimiter=',')
            writer.writerow(row)
