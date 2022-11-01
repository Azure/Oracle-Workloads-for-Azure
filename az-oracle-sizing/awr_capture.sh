#!/bin/bash
#================================================================================
# Name: awr_capture.sh
# Type: bash script
# Date: 14-February 2022
# From: Customer Success - Azure Infrastructure - Microsoft
#
# Copyright and license:
#
#       Licensed under the Apache License, Version 2.0 (the "License"); you may
#       not use this file except in compliance with the License.
#
#       You may obtain a copy of the License at
#
#               http://www.apache.org/licenses/LICENSE-2.0
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#       See the License for the specific language governing permissions and
#       limitations under the License.
#
#       Copyright (c) 2022 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#       This script is offered without warranty by Microsoft. Anyone using this
#       script accepts full responsibility for use, effect, and maintenance.
#       Please do not contact Microsoft support for help, but instead use the
#       support methods through GitHub.
#
# Description:
#
#       Bash shell script to automate the capture of metrics from Oracle AWR
#       reports, to be used for sizing Oracle database resources within Azure.
#
# Command-line Parameters:
#
#       (none)
#
# Expected command-line output:
#
#       CSV text
#
# Usage notes:
#
#       This script examines all HTML files (with ".html" file-extensions) in the
#       present working directory, and determines whether it can identify them as
#       Oracle AWR reports.  There are two types of AWR reports in HTML that the
#       script has been written to parse:
#
#               1) "global" AWR reports displaying all instances of a RAC database
#               2) standard AWR reports displaying one instance of any Oracle database
#                  (RAC or non-RAC)
#
#       After all ".html" files have been processed, then the script examines all
#       files with the ".txt" extension, to determine if they are text-formatted
#       standard AWR reports displaying one instance of any Oracle database (RAC or
#       non-RAC).
#
#       Output from parsing of the ".html" and ".txt" files will be output in CSV
#       (comma separated values) format.
#
# Modifications:
#       TGorman 14feb22 v0.1    written
#       TGorman 12oct22 v0.2    added 18c as a tested version
#       TGorman 31oct22 v0.3    fixed special conditions for 12.2.0.1.0 and 18c
#                               and added header labels with date and version
#================================================================================
#
#--------------------------------------------------------------------------------
# Set global environment variables with default values...
#--------------------------------------------------------------------------------
_progVersion="0.3"
#
for _file in `ls -1 *.html 2> /dev/null`
do
        #
        if `grep -q '<head><title>AWR RAC Report for DB: ' ${_file}`
        then    # global RAC version of AWR report...
                _line=`grep '^<tr><td align="right" headers="Database Id" class=' ${_file} | sed 's/[<>]/~/g'`
                _dbName=`echo "${_line}" | awk -F~ '{print $9}'`
                _dbUnqName=`echo "${_line}" | awk -F~ '{print $13}'`
                typeset -l _lowerDbName=${_dbName}
                typeset -l _lowerDbUnqName=${_dbUnqName}
                if [[ "${_lowerDbName}" = "${_lowerDbUnqName}" ]]
                then
                        _nbrInst=`echo "${_line}" | awk -F~ '{print $45}'`
                else
                        _nbrInst=`echo "${_line}" | awk -F~ '{print $29}'`
                fi
                unset _dbUnqName
                typeset -i _i=1
                while (( ${_i} <= ${_nbrInst} ))
                do
                        _line=`grep -A${_i} '^<table .*Database Instances Included In Report. . Listed in order of instance number, I#' ${_file} | sed 's/[<>]/~/g' | tail -1`
                        _instNbr=`echo "${_line}" | awk -F~ '{print $5}'`
                        _dbInstName=`echo "${_line}" | awk -F~ '{print $9}'`
                        _hostName=`echo "${_line}" | awk -F~ '{print $13}'`
                        _dbVersion=`echo "${_line}" | awk -F~ '{print $29}'`
                        _elaTime=`echo "${_line}" | awk -F~ '{print $33}' | sed 's/[ ,]//g'`
                        _dbTime=`echo "${_line}" | awk -F~ '{print $37}' | sed 's/[ ,]//g'`
                        #
                        case "${_dbVersion}" in
                                "11.1.0.7.0")   ;;
                                "11.2.0.3.0")   ;;
                                "11.2.0.4.0")   ;;
                                "12.1.0.2.0")   ;;
                                "12.2.0.1.0")   ;;
                                "18.0.0.0.0")   ;;
                                "19.0.0.0.0")   ;;
                                *)              echo "File \"${_file}\": database version not supported by this script; not processed..."
                                                continue
                                                ;;
                        esac
                        #
                        _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*c'>${_instNbr}</td><td align=.* headers=\"MemoryTarget Begin\"" ${_file} | sed 's/[<>]/~/g' | head -1`
                        _sgaUsed=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                        if [[ "${_sgaUsed}" =~ "&" ]]; then _sgaUsed="0"; fi
                        if (( ${_sgaUsed} == 0 ))
                        then
                                _sgaUsed=`echo "${_line}" | awk -F~ '{print $17}' | sed 's/[ ,]//g'`
                        fi
                        if (( ${_sgaUsed} == 0 ))
                        then
                                _line=`grep "^<tr><td scope=\"row\" class='awr.*c'>sga_max_size</td>" ${_file} | sed 's/[<>]/~/g'`
                                _sgaUsed=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g' | awk '{printf("%d\n",$1/1048576)}'`
                        fi
                        #
                        if [[ "${_dbVersion}" = "12.1.0.2.0" ]]
                        then
                                _line=`grep -A${_i} "^<table border=\"0\" class=\"tdiff\" summary=\"OS Statistics By Instance" ${_file} | sed 's/[<>]/~/g' | tail -1`
                                _CPUs=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                                _cores=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                                _pctBusy=`echo "${_line}" | awk -F~ '{print $29}' | sed 's/[ ,]//g'`
                                _memory=`echo "${_line}" | awk -F~ '{print $61}' | sed 's/[ ,]//g'`
                        else
                                _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*c'>${_instNbr}</td><td align=\"right\"" ${_file} | grep -iv "memorytarget" | sed 's/[<>]/~/g' | head -1`
                                _CPUs=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                                _cores=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                                _pctBusy=`echo "${_line}" | awk -F~ '{print $29}' | sed 's/[ ,]//g'`
                                _memory=`echo "${_line}" | awk -F~ '{print $61}' | sed 's/[ ,]//g'`
                        fi
                        #
                        _line=`grep -A${_i} "^<table border=\"0\" class=\"tdiff\" summary=\"Time Model\">" ${_file} | sed 's/[<>]/~/g' | tail -1`
                        _dbCpu=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                        #
                        _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*c'>${_instNbr}</td><td align=\"right\" headers=\"PGAAggrTarget Begin\"" ${_file} | sed 's/[<>]/~/g'`
                        _pgaAllocBegin=`echo "${_line}" | awk -F~ '{print $25}' | sed 's/[ ,]//g'`
                        _pgaAllocEnd=`echo "${_line}" | awk -F~ '{print $29}' | sed 's/[ ,]//g'`
                        _pgaUsed=`echo ${_pgaAllocBegin} ${_pgaAllocEnd} | awk '{if($1>$2){print $1}else{print $2}}'`
                        #
                        if [[ "${_dbVersion}" = "12.1.0.2.0" ]]
                        then
                                _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*'>${_instNbr}</td><td align=\"right\" headers=\"ReadsMB/sec Total\"" ${_file} | sed 's/[<>]/~/g' | tail -1`
                                _readIOPS=`echo "${_line}" | awk -F~ '{print $37}' | sed 's/[ ,]//g'`
                                _writeIOPS=`echo "${_line}" | awk -F~ '{print $49}' | sed 's/[ ,]//g'`
                                _readMBPS=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                                _writeMBPS=`echo "${_line}" | awk -F~ '{print $21}' | sed 's/[ ,]//g'`
                        else

                                _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*'>${_instNbr}</td><td .*Total\"" ${_file} | sed 's/[<>]/~/g' | tail -1`
                                if [[ "${_line}" != "" ]]
                                then
                                        if [[ "${_dbVersion}" = "18.0.0.0.0" || "${_dbVersion}" = "12.2.0.1.0" ]]
                                        then
                                                _readIOPS=`echo "${_line}" | awk -F~ '{print $21}' | sed 's/[ ,]//g'`
                                                _writeIOPS=`echo "${_line}" | awk -F~ '{print $25}' | sed 's/[ ,]//g'`
                                                _readMBPS=`echo "${_line}" | awk -F~ '{print $37}' | sed 's/[ ,]//g'`
                                                _writeMBPS=`echo "${_line}" | awk -F~ '{print $41}' | sed 's/[ ,]//g'`
                                        else
                                                _readIOPS=`echo "${_line}" | awk -F~ '{print $37}' | sed 's/[ ,]//g'`
                                                _writeIOPS=`echo "${_line}" | awk -F~ '{print $49}' | sed 's/[ ,]//g'`
                                                _readMBPS=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                                                _writeMBPS=`echo "${_line}" | awk -F~ '{print $21}' | sed 's/[ ,]//g'`
                                        fi
                                else
                                        _line=`grep "^<tr><td align=\"right\" scope=\"row\" class='awr.*'>${_instNbr}</td><td class='awr.*'>Total</td>" ${_file} | sed 's/[<>]/~/g' | tail -1`
                                        _readIOPS=`echo "${_line}" | awk -F~ '{print $21}' | sed 's/[ ,]//g'`
                                        _writeIOPS=`echo "${_line}" | awk -F~ '{print $25}' | sed 's/[ ,]//g'`
                                        _readMBPS=`echo "${_line}" | awk -F~ '{print $37}' | sed 's/[ ,]//g'`
                                        _writeMBPS=`echo "${_line}" | awk -F~ '{print $41}' | sed 's/[ ,]//g'`
                                fi
                        fi
                        #
                        typeset -i _i=${_i}+1
                        #
                        if [[ "${_hdrPrinted}" = "" ]]
                        then
                                _hdrPrinted="true"
                                echo "Generated on `date '+%Y-%m-%d %H:%M:%S'` by script \"awr_capture.sh\" version ${_progVersion}" | tee fixed_output.csv
                                echo "DB Name,Instance Name,Hostname,Elapsed Time (mins),DB Time (mins),DB CPU(s),CPUs,Cores,Memory (GB),%busy CPU,SGA use(MB),PGA use(MB),Read Throughput (MB/s),Write Throughput (MB/s),Read IOPS,Write IOPS " | tee -a fixed_output.csv
                        fi
                        echo "$_dbName,$_dbInstName,$_hostName,$_elaTime,$_dbTime,$_dbCpu,$_CPUs,$_cores,$_memory,$_pctBusy,$_sgaUsed,$_pgaUsed,$_readMBPS,$_writeMBPS,$_readIOPS,$_writeIOPS" | tee -a fixed_output.csv
                        #
                        # Unset variables to empty for next run
                        unset _dbInstName
                        unset _hostName
                        unset _elaTime
                        unset _dbTime
                        unset _dbCpu
                        unset _CPUs
                        unset _cores
                        unset _memory
                        unset _pctBusy
                        unset _sgaUsed
                        unset _pgaUsed
                        unset _readMBPS
                        unset _writeMBPS
                        unset _readIOPS
                        unset _writeIOPS
                done
                unset _dbName
                continue
        else    # non-RAC version of AWR report...
                _line=`grep -A1 '^<tr><th class="awrbg".*>DB Name</th>' ${_file} | tail -1 | sed 's/[<>]/~/g'`
                _dbName=`echo "${_line}" | awk -F~ '{print $5}'`
                _dbVersion=`echo "${_line}" | awk -F~ '{print $25}'`
                #
                case "${_dbVersion}" in
                        "11.1.0.7.0")   ;;
                        "11.2.0.3.0")   ;;
                        "11.2.0.4.0")   ;;
                        "12.1.0.2.0")   ;;
                        "12.2.0.1.0")   ;;
                        "18.0.0.0.0")   ;;
                        "19.0.0.0.0")   ;;
                        *)              echo "File \"${_file}\": database version not supported by this script; not processed..."
                                        continue
                                        ;;
                esac
                #
                if [[ "${_dbVersion}" =~ "11." || "${_dbVersion}" = "12.1.0.2.0" ]]
                then
                        _dbInstName=`echo "${_line}" | awk -F~ '{print $13}'`
                else
                        _line=`grep -A1 '^<tr><th class="awrbg" scope="col">Instance</th>' ${_file} | tail -1 | sed 's/[<>]/~/g'`
                        _dbInstName=`echo "${_line}" | awk -F~ '{print $5}'`
                fi
                #
                _line=`grep -A1 '^<tr><th class="awrbg".*>Host Name</th>' ${_file} | tail -1 | sed 's/[<>]/~/g'`
                _hostName=`echo "${_line}" | awk -F~ '{print $5}'`
                typeset -i _CPUs=`echo "${_line}" | awk -F~ '{print $13}'`
                typeset -i _cores=`echo "${_line}" | awk -F~ '{print $17}'`
                _memory=`echo "${_line}" | awk -F~ '{print $25}' | sed 's/[ ,]//g'`
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td.*class=|awr.*c|>Elapsed:</td>' | sed 's/[<>]/~/g'`
                _elaTime=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g' | sed 's/(mins)//'`
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td.*class=|awrc|>DB Time:</td>' | sed 's/[<>]/~/g'`
                _dbTime=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g' | sed 's/(mins)//'`
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td.*class=|awr.*c|>DB CPU</td>' | head -1 | sed 's/[<>]/~/g'`
                if [[ "${_dbVersion}" = "11.1.0.7.0" ]]
                then
                        _dbCpu=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                else
                        _dbCpu=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                fi
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep -A1 '^<tr><th class=|awrbg|.*>%Total CPU</th><th class=|awrbg|.*>%Busy CPU</th>' | tail -1 | sed 's/[<>]/~/g'`
                _pctBusy=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td .*class=|awr.*c|>SGA use (MB):</td>' | sed 's/[<>]/~/g'`
                _sgaUsed=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td .*class=|awr.*c|>PGA use (MB):</td>' | sed 's/[<>]/~/g'`
                _pgaUsedBegin=`echo "${_line}" | awk -F~ '{print $9}' | sed 's/[ ,]//g'`
                _pgaUsedEnd=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                if [[ "${_pgaUsedBegin}" > "${_pgaUsedEnd}" ]]
                then
                        _pgaUsed=${_pgaUsedBegin}
                else
                        _pgaUsed=${_pgaUsedEnd}
                fi
                #
                _line=`sed 's/"/|/g' ${_file} | sed "s/'/|/g" | grep '^<tr><td .*class=|awr.*c|>TOTAL:</td>' | tail -1 | sed 's/[<>]/~/g'`
                _readIOPS=`echo "${_line}" | awk -F~ '{print $13}' | sed 's/[ ,]//g'`
                _rawReadMBPS=`echo "${_line}" | awk -F~ '{print $17}' | sed 's/[ ,]//g'`
                _x=`echo ${_rawReadMBPS} | sed 's/[Gg]//g'`
                if [[ "${_rawReadMBPS}" != "${_x}" ]]
                then
                        _readMBPS=`echo ${_x} | awk '{print ($1*1024)}'`
                else
                        _x=`echo ${_rawReadMBPS} | sed 's/[Mm]//g'`
                        if [[ "${_rawReadMBPS}" != "${_x}" ]]
                        then
                                _readMBPS=${_x}
                        else
                                _x=`echo ${_rawReadMBPS} | sed 's/[Kk]//g'`
                                if [[ "${_rawReadMBPS}" != "${_x}" ]]
                                then
                                        _readMBPS=`echo ${_x} | awk '{print ($1/1024)}'`
                                else
                                        _readMBPS=${_rawReadMBPS}
                                fi
                        fi
                fi
                _writeIOPS=`echo "${_line}" | awk -F~ '{print $25}' | sed 's/[ ,]//g'`
                _rawWriteMBPS=`echo "${_line}" | awk -F~ '{print $29}' | sed 's/[ ,]//g'`
                _x=`echo ${_rawWriteMBPS} | sed 's/[Gg]//g'`
                if [[ "${_rawWriteMBPS}" != "${_x}" ]]
                then
                        _writeMBPS=`echo ${_x} | awk '{print ($1*1024)}'`
                else
                        _x=`echo ${_rawWriteMBPS} | sed 's/[Mm]//g'`
                        if [[ "${_rawWriteMBPS}" != "${_x}" ]]
                        then
                                _writeMBPS=${_x}
                        else
                                _x=`echo ${_rawWriteMBPS} | sed 's/[Kk]//g'`
                                if [[ "${_rawWriteMBPS}" != "${_x}" ]]
                                then
                                        _writeMBPS=`echo ${_x} | awk '{print ($1/1024)}'`
                                else
                                        _writeMBPS=${_rawWriteMBPS}
                                fi
                        fi
                fi
        fi
        #
        if [[ "${_dbVersion}" =~ "11.1.0" ]]
        then
                if [[ "${_readIOPS}" = "" ]]
                then    _readIOPS="n/a"
                fi
                if [[ "${_readMBPS}" = "" ]]
                then    _readMBPS="n/a"
                fi
                if [[ "${_writeIOPS}" = "" ]]
                then    _writeIOPS="n/a"
                fi
                if [[ "${_writeMBPS}" = "" ]]
                then    _writeMBPS="n/a"
                fi
        fi
        #
        if [[ "${_hdrPrinted}" = "" ]]
        then
                _hdrPrinted="true"
                echo "Generated on `date '+%Y-%m-%d %H:%M:%S'` by script \"awr_capture.sh\" version ${_progVersion}" | tee fixed_output.csv
                echo "DB Name,Instance Name,Hostname,Elapsed Time (mins),DB Time (mins),DB CPU(s),CPUs,Cores,Memory (GB),%busy CPU,SGA use(MB),PGA use(MB),Read Throughput (MB/s),Write Throughput (MB/s),Read IOPS,Write IOPS" | tee -a fixed_output.csv
        fi
        echo "$_dbName,$_dbInstName,$_hostName,$_elaTime,$_dbTime,$_dbCpu,$_CPUs,$_cores,$_memory,$_pctBusy,$_sgaUsed,$_pgaUsed,$_readMBPS,$_writeMBPS,$_readIOPS,$_writeIOPS" | tee -a fixed_output.csv
        #
        # Unset variables to empty for next run
        unset _dbName
        unset _dbInstName
        unset _hostName
        unset _elaTime
        unset _dbTime
        unset _dbCpu
        unset _CPUs
        unset _cores
        unset _memory
        unset _pctBusy
        unset _sgaUsed
        unset _pgaUsed
        unset _readMBPS
        unset _writeMBPS
        unset _readIOPS
        unset _writeIOPS
        #
done
#
for _file in `ls -1 *.txt 2> /dev/null`
do
        _dbName=$(grep -A2 "DB Name" ${_file} | tail -n1 | awk '{print $1}' | sed 's/,//g')
        _dbInstName=$(grep -A2 "Instance" ${_file} | head -n3 | awk '{print $1}' | tail -n1 | sed 's/,//g')
        _hostName=$(grep -A2 "Host Name" ${_file} | tail -n1 | awk '{print $1}' | sed 's/,//g')
        _elaTime=$(grep -A2 "Elapsed" ${_file}| head -n1 | awk '{print $2}' | sed 's/,//g')
        _dbTime=$(grep -A2 "DB Time" ${_file} | head -n1 | awk '{print $3}' | sed 's/,//g')
        _dbCpu=$(grep -A2 "DB CPU time" ${_file} | tail -n3 | awk '{print $11}' | sed 's/,//g')
        _CPUs=$(grep -A2 "CPUs" ${_file} | head -n3 | tail -n1 | awk '{print $(NF-3)}' | sed 's/,//g')
        _cores=$(grep -A2 "Cores" ${_file} | head -n3 | tail -n1 | awk '{print $(NF-2)}' | sed 's/,//g')
        _memory=$(grep -A2 "Memory" ${_file} | head -n3 | tail -n1 | awk '{print $NF}' | sed 's/,//g')
        _pctBusy=$(grep -A2 "% of busy  CPU for Instance" ${_file} | head -n1 | awk '{print $7}' | sed 's/,//g')
        _sgaUsed=$(grep -A2 "SGA use (MB):" ${_file} | head -n1 | awk '{print $5}' | sed 's/,//g')
        _pgaUsed=$(grep -A2 "PGA use (MB):" ${_file} | head -n1 | awk '{print $5}' | sed 's/,//g')
        _readMBPS=$(grep -A2 "  Total (MB): " ${_file} | head -n1 | awk '{print $4}' | sed 's/,//g')
        _writeMBPS=$(grep -A2 "  Total (MB): " ${_file} | head -n1 | awk '{print $5}' | sed 's/,//g')
        _readIOPS=$(grep -A2 "  Total Requests: " ${_file} | head -n1 | awk '{print $4}' | sed 's/,//g')
        _writeIOPS=$(grep -A2 "  Total Requests: " ${_file} | head -n1 | awk '{print $5}' | sed 's/,//g')

        if [[ "${_hdrPrinted}" = "" ]]
        then
                _hdrPrinted="true"
                echo "Generated on `date '+%Y-%m-%d %H:%M:%S'` by script \"awr_capture.sh\" version ${_progVersion}" | tee fixed_output.csv
                echo "DB Name,Instance Name,Hostname,Elapsed Time (mins),DB Time (mins),DB CPU(s),CPUs,Cores,Memory (GB),%busy CPU,SGA use(MB),PGA use(MB),Read Throughput (MB/s),Write Throughput (MB/s),Read IOPS,Write IOPS " | tee -a fixed_output.csv
        fi

        echo "$_dbName,$_dbInstName,$_hostName,$_elaTime,$_dbTime,$_dbCpu,$_CPUs,$_cores,$_memory,$_pctBusy,$_sgaUsed,$_pgaUsed,$_readMBPS,$_writeMBPS,$_readIOPS,$_writeIOPS" | tee -a fixed_output.csv

        # Unset variables to empty for next run
        unset _dbName
        unset _dbInstName
        unset _hostName
        unset _elaTime
        unset _dbTime
        unset _dbCpu
        unset _CPUs
        unset _cores
        unset _memory
        unset _pctBusy
        unset _sgaUsed
        unset _pgaUsed
        unset _readMBPS
        unset _writeMBPS
        unset _readIOPS
        unset _writeIOPS
done
