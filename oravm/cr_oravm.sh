#!/bin/bash
#================================================================================
# Name:	cr_oravm.sh
# Type:	bash script
# Date:	23-April 2020
# From: Customer Architecture & Engineering (CAE) - Microsoft
#
# Copyright and license:
#
#       Licensed under the Apache License, Version 2.0 (the "License"); you may
#       not use this file except in compliance with the License.
#
#       You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#       Unless required by applicable law or agreed to in writing, software
#       distributed under the License is distributed on an "AS IS" basis,
#       WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#       See the License for the specific language governing permissions and
#       limitations under the License.
#
#       Copyright (c) 2020 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#       This script is offered without warranty by Microsoft Customer Engineering.
#       Anyone using this script accepts full responsibility for use, effect,
#       and maintenance.  Please do not contact Microsoft support unless there
#       is a problem with a supported Azure component used in this script,
#       such as an "az" command.
#
# Description:
#
#	Script to automate the creation of an Oracle database on a marketplace
#	Oracle image within Microsoft Azure, using the Azure CLI.
#
# Command-line Parameters:
#
#	Usage: ./cr_oravm.sh -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val
#
#	where:
#		-G resource-group-name	name of the Azure resource group (default: \"{owner}-{project}-rg\")
#		-H ORACLE_HOME		full path of ORACLE_HOME software (default: /u01/app/oracle/product/19.0.0/dbhome_1)
#		-N			skip network setup i.e. vnet, NSG, NSG rules (default: false)
#		-O owner-tag		name of the owner to use in Azure tags (default: Linux 'whoami')
#		-P project-tag		name of the project to use in Azure tags (default: oravm)
#		-S subscription		name of the Azure subscription (no default)
#		-c True|False		True is ReadWrite for OS / ReadOnly for data, False is None (default: True)
#		-d domain-name		IP domain name (default: internal.cloudapp.net)
#		-i instance-type	name of the Azure VM instance type (default: Standard_D4ds_v4)
#		-n #data-disks		number of data disks to attach to the VM (default: 1)
#		-p Oracle-port		port number of the Oracle TNS Listener (default: 1521)
#		-r region		name of Azure region (default: westus)
#		-s ORACLE_SID		Oracle System ID (SID) value (default: oradb01)
#		-u urn			Azure URN for the VM from the marketplace (default: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1)
#		-v			set verbose output is true (default: false)
#		-w password		clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)
#		-z data-disk-GB		size of each attached data-disk in GB (default: 4095)
#
# Expected command-line output:
#
#	Please see file "oravm_output.txt" at https://github.com/tigormanmsft/oravm.
#
# Usage notes:
#
#	1) Azure subscription must be specified with "-S" switch, always
#
#	2) Azure owner, default is output of "whoami" command in shell, can be
#	   specified using "-O" switch on command-line
#
#	3) Azure project, default is "oravm", can be specified using "-P"
#	   switch on command-line
#
#	4) Azure resource group, specify with "-G" switch or with a
#	   combination of "-O" (project owner tag) and "-P" (project name)
#	   values (default: "(project owner tag)-(project name)-rg").
#
#	   For example, if the project owner tag is "abc" and the project
#	   name is "beetlejuice", then by default the resource group is
#	   expected to be named "abc-beetlejuice-rg", unless changes have
#	   been specified using the "-G", "-O", or "-P" switches
#
#	5) Use the "-v" (verbose) switch to verify that program variables
#	   have the expected values
#
#	6) For users who are expected to use prebuilt networking (i.e. vnet,
#	   subnet, network security groups, etc), please consider using the
#	   "-N" switch
#
#	Please be aware that Azure owner (i.e. "-O") and Azure project (i.e. "-P")
#	are used to generate names for the Azure resource group, storage
#	account, virtual network, subnet, network security group and rules,
#	VM, and storage disks.  Use the "-v" switch to verify expected naming.
#
# Modifications:
#	TGorman	23apr20	v0.1	written
#	TGorman	15jun20 v0.2	various bug fixes
#	TGorman	16jun20 v0.3	move TEMP to temporary/ephemeral disk
#	TGorman	22jun20		fix OsDisk Caching typo
#	SLuce and TGorman 22jun20 v0.4	add Azure NetApp Files (ANF) storage
#	TGorman	18aug20	v0.5	fix minor issues
#	TGorman	24aug20	v0.6	fix major issues for v0.5
#	TGorman	17nov20	v0.7	update to default 19c VM image from marketplace
#	TGorman	27jan21 v0.8	accelerated networking TRUE at NIC creation and
#				defaulted VM instance type to "Standard_D4ds_v4"
#	TGorman	03mar21	v0.9	remove NSG rule default-all-ssh open to internet,
#				add NSG rule ssh-cloud-shell open only to Azure
#				Cloud service tag.  Also add "yum update" to
#				ensure that everything is up-to-date...
#	TGorman	26apr21	v1.0	set waagent.conf to rebuild swapfile after reboot
#				and perform 2nd "yum update"
#	TGorman	03jun21	v1.1	Enable Azure VM Backup on resident Oracle db,
#				attach Azure Files standard share for archived
#				redo log file storage
#	TGorman	06jul21	v1.2	regenerate initramfs and reboot before finish
#	TGorman	29jul21	v1.3	regenerate grub and grub2.cfg files before
#				regenerating initramfs file and rebooting...
#	TGorman	09feb22	v1.4	pushed to azure/Oracle-Workloads-For-Azure repo...
#================================================================================
#
#--------------------------------------------------------------------------------
# Set global environment variables with default values...
#--------------------------------------------------------------------------------
_progVersion="1.4"
_progName="cr_oravm"
_outputMode="terse"
_azureOwner="`whoami`"
_azureProject="oravm"
_azureRegion="westus"
_azureSubscription=""
_workDir="`pwd`"
_skipVnetSubnetNsg="false"
_vmUrn="Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1"
_vmDomain="internal.cloudapp.net"
_vmInstanceType="Standard_D4ds_v4"
_vmOsDiskSize="32"
_vmOsDiskCaching="ReadWrite"
_vmDataDiskCaching="ReadOnly"
_vmDataDiskNbr=1
_vmDataDiskSzGB=4095
_vgName="vg_ora01"
_lvName="lv_ora01"
_oraSid="oradb01"
_oraHome="/u01/app/oracle/product/19.0.0/dbhome_1"
_oraInvDir="/u01/app/oraInventory"
_oraOsAcct="oracle"
_oraOsGroup="oinstall"
_oraCharSet="WE8ISO8859P15"
_oraMntDir="/u02"
_oraDataDir="${_oraMntDir}/oradata"
_oraFRADir="${_oraMntDir}/orarecv"
_oraArchDir="/backup"
_oraSysPwd=oracleA1
_oraRedoSizeMB=4096
_oraLsnrPort=1521
_oraMemPct=70
_oraMemType="AUTO_SGA"
_oraFraSzGB=40960
typeset -i _scsiDevNbr=24
declare -a _scsiDevList=("", "sdc" "sdd" "sde" "sdf" "sdg" "sdh" \
			     "sdi" "sdj" "sdk" "sdl" "sdm" "sdn" \
			     "sdo" "sdp" "sdq" "sdr" "sds" "sdt" \
			     "sdu" "sdv" "sdw" "sdx" "sdy" "sdz")
_rgName="${_azureOwner}-${_azureProject}-rg"
_realRgName=""
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_nicName="${_azureOwner}-${_azureProject}-nic01"
_pubIpName="${_azureOwner}-${_azureProject}-pip01"
_vmName="${_azureOwner}-${_azureProject}-vm01"
_saName="${_azureOwner}${_azureProject}sa01"
_shareName="${_azureOwner}-${_azureProject}-share01"
_vaultName="${_azureOwner}-${_azureProject}-vault01"
_policyName="${_azureOwner}-${_azureProject}-policy01"
_workloadConfFile=/tmp/workload_conf_$$.tmp
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_ANFaccountName="${_azureOwner}-${_azureProject}-naa"
_ANFpoolName="${_azureOwner}-${_azureProject}-pool"
_ANFvolumeName="${_azureOwner}-${_azureProject}-vol"
_ANFsubnetName="${_azureOwner}-${_azureProject}-anfnet"
#
#--------------------------------------------------------------------------------
# Accept command-line parameter values to override default values (above)..
#--------------------------------------------------------------------------------
typeset -i _parseErrs=0
while getopts ":G:H:NO:P:S:c:d:i:n:p:r:s:u:vw:z:" OPTNAME
do
	case "${OPTNAME}" in
		G)	_realRgName="${OPTARG}"		;;
		H)	_oraHome="${OPTARG}"		;;
		N)	_skipVnetSubnetNsg="true"	;;
		O)	_azureOwner="${OPTARG}"		;;
		P)	_azureProject="${OPTARG}"	;;
		S)	_azureSubscription="${OPTARG}"	;;
		c)	typeset -u _TRUEorFALSE=${OPTARG}
			if [[ "${_TRUEorFALSE}" != "TRUE" ]]; then
				_vmOsDiskCaching="None"
				_vmDataDiskCaching="None"
			fi
			;;
		d)	_vmDomain="${OPTARG}"		;;
		i)	_vmInstanceType="${OPTARG}"	;;
		n)	_vmDataDiskNbr="${OPTARG}"	;;
		p)	_oraLsnrPort="${OPTARG}"	;;
		r)	_azureRegion="${OPTARG}"	;;
		s)	_oraSid="${OPTARG}"		;;
		u)	_vmUrn="${OPTARG}"		;;
		v)	_outputMode="verbose"		;;
		w)	_oraSysPwd="${OPTARG}"		;;
		z)	_vmDataDiskSzGB="${OPTARG}"	;;
		:)	echo "`date` - FAIL: expected \"${OPTARG}\" value not found"
			typeset -i _parseErrs=${_parseErrs}+1
			;;
		\?)	echo "`date` - FAIL: unknown command-line option \"${OPTARG}\""
			typeset -i _parseErrs=${_parseErrs}+1
			;;
	esac	
done
shift $((OPTIND-1))
#
#--------------------------------------------------------------------------------
# If any errors occurred while processing the command-line parameters, then display
# a usage message and exit with failure status...
#--------------------------------------------------------------------------------
if (( ${_parseErrs} > 0 ))
then
	echo "Usage: $0 -G val -H val -N -O val -P val -S val -c val -d val -i val -n val -p val -r val -s val -u val -v -w val -z val"
	echo "where:"
	echo "	-G resource-group-name	name of the Azure resource group (default: \"{owner}-{project}-rg\")"
	echo "	-H ORACLE_HOME		full path of the ORACLE_HOME software (default: /u01/app/oracle/product/19.0.0/dbhome_1)"
	echo "	-N			skip network setup i.e. vnet, NSG, NSG rules (default: false)"
	echo "	-O owner-tag		name of the owner to use in Azure tags (default: Linux 'whoami')"
	echo "	-P project-tag		name of the project to use in Azure tags (no default)"
	echo "	-S subscription		name of the Azure subscription (no default)"
	echo "	-c True|False		True is ReadWrite for OS / ReadOnly for data, False is None (default: True)"
	echo "	-d domain-name		IP domain name (default: internal.cloudapp.net)"
	echo "	-i instance-type	name of the Azure VM instance type (default: Standard_D4ds_v4)"
	echo "	-n #data-disks		number of data disks to attach to the VM (default: 1)"
	echo "	-p Oracle-port		port number of the Oracle TNS Listener (default: 1521)"
	echo "	-r region		name of Azure region (default: westus)"
	echo "	-s ORACLE_SID		Oracle System ID (SID) value (default: oradb01)"
	echo "	-u urn			Azure URN for the VM from the marketplace (default: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1)"
	echo "	-v			set verbose output is true (default: false)"
	echo "	-w password		clear-text value of initial SYS and SYSTEM password in Oracle database (default: oracleA1)"
	echo "	-z data-disk-GB		size of each attached data-disk in GB (default: 4095)"
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set script variables based on owner and project values...
#--------------------------------------------------------------------------------
if [[ "${_realRgName}" != "" ]]
then
	_rgName="${_realRgName}"
else
	_rgName="${_azureOwner}-${_azureProject}-rg"
fi
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_nicName="${_azureOwner}-${_azureProject}-nic01"
_pubIpName="${_azureOwner}-${_azureProject}-public-ip01"
_vmName="${_azureOwner}-${_azureProject}-vm01"
_saName="${_azureOwner}${_azureProject}sa01"
_shareName="${_azureOwner}-${_azureProject}-share01"
_vaultName="${_azureOwner}-${_azureProject}-vault01"
_policyName="${_azureOwner}-${_azureProject}-policy01"
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_ANFaccountName="${_azureOwner}-${_azureProject}-naa"
_ANFpoolName="${_azureOwner}-${_azureProject}-pool"
_ANFvolumeName="${_azureOwner}-${_azureProject}-vol"
_ANFsubnetName="${_azureOwner}-${_azureProject}-anfnet"
#
#--------------------------------------------------------------------------------
# Display variable values when output is set to "verbose"...
#--------------------------------------------------------------------------------
if [[ "${_outputMode}" = "verbose" ]]
then
	echo "`date` - DBUG: parameter _rgName is \"${_rgName}\""
	echo "`date` - DBUG: parameter _skipVnetSubnetNsg is \"${_skipVnetSubnetNsg}\""
	echo "`date` - DBUG: parameter _azureOwner is \"${_azureOwner}\""
	echo "`date` - DBUG: parameter _azureProject is \"${_azureProject}\""
	echo "`date` - DBUG: parameter _azureSubscription is \"${_azureSubscription}\""
	echo "`date` - DBUG: parameter _vmDataDiskCaching is \"${_vmDataDiskCaching}\""
	echo "`date` - DBUG: parameter _vmDomain is \"${_vmDomain}\""
	echo "`date` - DBUG: parameter _oraHome is \"${_oraHome}\""
	echo "`date` - DBUG: parameter _vmInstanceType is \"${_vmInstanceType}\""
	echo "`date` - DBUG: parameter _vmDataDiskNbr is \"${_vmDataDiskNbr}\""
	echo "`date` - DBUG: parameter _oraLsnrPort is \"${_oraLsnrPort}\""
	echo "`date` - DBUG: parameter _azureRegion is \"${_azureRegion}\""
	echo "`date` - DBUG: parameter _oraSid is \"${_oraSid}\""
	echo "`date` - DBUG: parameter _vmUrn is \"${_vmUrn}\""
	echo "`date` - DBUG: parameter _vmDataDiskSzGB is \"${_vmDataDiskSzGB}\""
	echo "`date` - DBUG: variable _workDir is \"${_workDir}\""
	echo "`date` - DBUG: variable _logFile is \"${_logFile}\""
	echo "`date` - DBUG: variable _vnetName is \"${_vnetName}\""
	echo "`date` - DBUG: variable _subnetName is \"${_subnetName}\""
	echo "`date` - DBUG: variable _nsgName is \"${_nsgName}\""
	echo "`date` - DBUG: variable _nicName is \"${_nicName}\""
	echo "`date` - DBUG: variable _pubIpName is \"${_pubIpName}\""
	echo "`date` - DBUG: variable _vmName is \"${_vmName}\""
	echo "`date` - DBUG: variable _saName is \"${_saName}\""
	echo "`date` - DBUG: variable _shareName is \"${_shareName}\""
	echo "`date` - DBUG: variable _vaultName is \"${_vaultName}\""
	echo "`date` - DBUG: variable _policyName is \"${_policyName}\""
	echo "`date` - DBUG: variable _vmOsDiskSize is \"${_vmOsDiskSize}\""
	echo "`date` - DBUG: variable _vmOsDiskCaching is \"${_vmOsDiskCaching}\""
	echo "`date` - DBUG: variable _vgName is \"${_vgName}\""
	echo "`date` - DBUG: variable _lvName is \"${_lvName}\""
	echo "`date` - DBUG: variable _oraInvDir is \"${_oraInvDir}\""
	echo "`date` - DBUG: variable _oraOsAcct is \"${_oraOsAcct}\""
	echo "`date` - DBUG: variable _oraOsGroup is \"${_oraOsGroup}\""
	echo "`date` - DBUG: variable _oraCharSet is \"${_oraCharSet}\""
	echo "`date` - DBUG: variable _oraMntDir is \"${_oraMntDir}\""
	echo "`date` - DBUG: variable _oraDataDir is \"${_oraDataDir}\""
	echo "`date` - DBUG: variable _oraFRADir is \"${_oraFRADir}\""
	echo "`date` - DBUG: variable _oraArchDir is \"${_oraArchDir}\""
	echo "`date` - DBUG: variable _oraRedoSizeMB is \"${_oraRedoSizeMB}\""
	echo "`date` - DBUG: variable _oraMemPct is \"${_oraMemPct}\""
	echo "`date` - DBUG: variable _oraMemType is \"${_oraMemType}\""
	echo "`date` - DBUG: variable _oraFraSzGB is \"${_oraFraSzGB}\""
	echo "`date` - DBUG: variable _ANFaccountName is \"${_ANFaccountName}\""
	echo "`date` - DBUG: variable _ANFpoolName is \"${_ANFpoolName}\""
	echo "`date` - DBUG: variable _ANFvolumeName is \"${_ANFvolumeName}\""
	echo "`date` - DBUG: variable _ANFsubnetName is \"${_ANFsubnetName}\""
fi
#
#--------------------------------------------------------------------------------
# Verify that the requested number of data disks is less than the script's max...
#--------------------------------------------------------------------------------
if (( ${_vmDataDiskNbr} > ${_scsiDevNbr} )); then
	echo "`date` - FAIL: number of data disks must be <= ${_scsiDevNbr}" | tail -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Remove any existing logfile...
#--------------------------------------------------------------------------------
rm -f ${_logFile}
#
#--------------------------------------------------------------------------------
# Verify that the resource group exists...
#--------------------------------------------------------------------------------
echo "`date` - INFO: ${_progName}.sh version ${_progVersion}..." | tee -a ${_logFile}
echo "`date` - INFO: az group exists -n ${_rgName}..." | tee -a ${_logFile}
if [[ "`az group exists -n ${_rgName}`" != "true" ]]; then
	echo "`date` - FAIL: resource group \"${_rgName}\" does not exist" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure subscription...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az account set..." | tee -a ${_logFile}
az account set -s "${_azureSubscription}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: ${_azureProject} - az account set" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure resource group and region/location...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az configure --defaults group location..." | tee -a ${_logFile}
az configure --defaults group=${_rgName} location=${_azureRegion} >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: ${_azureProject} - az configure --defaults group location" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# If the user elected to skip the creation of vnet, the NIC, the NSG, and the
# rules...
#--------------------------------------------------------------------------------
if [[ "${_skipVnetSubnetNsg}" = "false" ]]; then
	#
	#------------------------------------------------------------------------
	# Create an Azure virtual network for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network vnet create ${_vnetName}..." | tee -a ${_logFile}
	az network vnet create \
		--name ${_vnetName} \
		--address-prefixes 10.0.0.0/16 \
		--subnet-name ${_subnetName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--subnet-prefixes 10.0.0.0/24 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network vnet create ${_vnetName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure network security group for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg create ${_nsgName}..." | tee -a ${_logFile}
	az network nsg create \
		--name ${_nsgName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg create ${_nsgName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create a custom Azure network security group rule to permit SSH access
	# over port 22...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg rule create ssh-cloud-shell..." | tee -a ${_logFile}
	az network nsg rule create \
		--name ssh-cloud-shell \
		--nsg-name ${_nsgName} \
		--priority 1000 \
		--direction Inbound \
		--protocol TCP \
		--source-address-prefixes AzureCloud \
		--destination-address-prefixes \* \
		--destination-port-ranges 22 \
		--access Allow \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg rule create ssh-cloud-shell" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create a custom Azure network security group rule to permit SMB (CIFS)
	# access over port 445...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg rule create smb-cloud-shell..." | tee -a ${_logFile}
	az network nsg rule create \
		--name smb-cloud-shell \
		--nsg-name ${_nsgName} \
		--priority 1010 \
		--direction Inbound \
		--protocol TCP \
		--source-address-prefixes AzureCloud \
		--destination-address-prefixes \* \
		--destination-port-ranges 445 \
		--access Allow \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg rule create smb-cloud-shell" | tee -a ${_logFile}
		exit 1
	fi
	#
fi
#
#--------------------------------------------------------------------------------
# Create an Azure public IP address object for use with the first VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network public-ip create ${_pubIpName}..." | tee -a ${_logFile}
az network public-ip create \
	--name ${_pubIpName} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--allocation-method Static \
	--sku Basic \
	--version IPv4 \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip create ${_pubIpName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create an Azure network interface (NIC) object for use with the first VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network nic create ${_nicName}..." | tee -a ${_logFile}
az network nic create \
	--name ${_nicName} \
	--vnet-name ${_vnetName} \
	--subnet ${_subnetName} \
	--network-security-group ${_nsgName} \
	--public-ip-address ${_pubIpName} \
	--accelerated-networking TRUE \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network nic create ${_nicName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create the Azure virtual machine (VM), intended to be used as the Oracle
# database server/host...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az vm create ${_vmName}..." | tee -a ${_logFile}
az vm create \
	--name ${_vmName} \
	--image ${_vmUrn}:latest \
	--admin-username ${_azureOwner} \
	--size ${_vmInstanceType} \
	--nics ${_nicName} \
	--os-disk-name ${_vmName}-osdisk \
	--os-disk-size-gb ${_vmOsDiskSize} \
	--os-disk-caching ${_vmOsDiskCaching} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--generate-ssh-keys \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm create ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create Azure storage account from which an Azure Files standard SMB/CIFS share
# will be allocated for Oracle archived redo log files...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az storage account create ${_saName}..." | tee -a ${_logFile}
az storage account create \
	--name ${_saName} \
	--sku Standard_RAGRS \
	--kind StorageV2 \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az storage account create ${_saName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create Azure Files standard SMB/CIFS share which will be allocated for Oracle
# database archived redo log files...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az storage share create ${_shareName}..." | tee -a ${_logFile}
az storage share create \
	--name ${_shareName} \
	--account-name ${_saName} \
	--quota 4096 \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az storage share create ${_shareName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Retrieve the URL to access the storage account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az storage account show ${_saName}..." | tee -a ${_logFile}
_saHttps=`az storage account show \
	--resource-group ${_rgName} \
	--name ${_saName} \
	--query "primaryEndpoints.file" | tr -d '"'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az storage account show ${_saName}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: az storage account ${_saName} is \"${_saHttps}\"..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Retrieve the storage account keys for later use when mounting the CIFS/SMB
# file share within the VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az storage account keys list ${_saName}..." | tee -a ${_logFile}
_saKey=`az storage account keys list \
	--resource-group ${_rgName} \
	--account-name ${_saName} \
	--query "[0].value" | tr -d '"'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az storage account keys list ${_saName}" | tee -a ${_logFile}
	exit 1
fi
if [[ "${_outputMode}" = "verbose" ]]
then
	echo "`date` - DBUG: az storage account keys list is \"${_saKey}\""
fi
#
#--------------------------------------------------------------------------------
# Create an Azure Recovery Services vault...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az backup vault create ${_vaultName}..." | tee -a ${_logFile}
az backup vault create \
	--name ${_vaultName} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az backup vault create ${_vaultName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create an Azure Backup policy...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az backup policy create ${_policyName}..." | tee -a ${_logFile}
az backup policy create \
	--name ${_policyName} \
	--vault-name ${_vaultName} \
	--backup-management-type AzureIaasVM \
	--workload-type VM \
	--policy '
{
  "eTag": null,
  "location": null,
  "name": "${_policyName}",
  "properties": {
    "backupManagementType": "AzureIaasVM",
    "instantRpDetails": {
      "azureBackupRgNamePrefix": null,
      "azureBackupRgNameSuffix": null
    },
    "instantRpRetentionRangeInDays": 2,
    "protectedItemsCount": 0,
    "retentionPolicy": {
      "dailySchedule": {
        "retentionDuration": {
          "count": 30,
          "durationType": "Days"
        },
        "retentionTimes": [
          "2020-09-30T19:30:00+00:00"
        ]
      },
      "monthlySchedule": null,
      "retentionPolicyType": "LongTermRetentionPolicy",
      "weeklySchedule": null,
      "yearlySchedule": null
    },
    "schedulePolicy": {
      "schedulePolicyType": "SimpleSchedulePolicy",
      "scheduleRunDays": null,
      "scheduleRunFrequency": "Daily",
      "scheduleRunTimes": [
        "2020-09-30T19:30:00+00:00"
      ],
      "scheduleWeeklyFrequency": 0
    },
    "timeZone": "UTC"
  },
  "resourceGroup": "${_rgName}",
  "tags": null,
  "type": "Microsoft.RecoveryServices/vaults/backupPolicies"
}'	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az backup policy create ${_policyName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Obtain the public IP addresses for future use within the script...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network public-ip show ${_pubIpName}..." | tee -a ${_logFile}
_ipAddr=`az network public-ip show --name ${_pubIpName} | \
	 jq '. | {ipaddr: .ipAddress}' | \
	 grep ipaddr | \
	 awk '{print $2}' | \
	 sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip show ${_pubIpName}" | tee -a ${_logFile}
	exit 1
fi 
echo "`date` - INFO: public IP ${_ipAddr} for ${_vmName}..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Obtain the private IP addresses for future use within the script...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network nic show ${_nicName}..." | tee -a ${_logFile}
_privateIp=`az network nic show --name ${_nicName} | \
	    jq '.ipConfigurations[0] .privateIpAddress' | \
	    sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network nic show ${_nicName}" | tee -a ${_logFile}
	exit 1
fi 
echo "`date` - INFO: private IP ${_privateIp} for ${_vmName}..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Remove any previous entries of the IP address from the "known hosts" config
# file...
#--------------------------------------------------------------------------------
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${_ipAddr} >> ${_logFile} 2>&1
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a directory mount-point for the soon-to-be-created
# filesystem in which Oracle database files will reside...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir ${_oraMntDir} on ${_vmName}..." | tee -a ${_logFile}
ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr} "sudo mkdir -p ${_oraMntDir}"
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p ${_oraMntDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# If no data disks are requested on the VM, then deploy Azure NetApp Files...
#--------------------------------------------------------------------------------
if (( ${_vmDataDiskNbr} <= 0 ))
then
	#
	echo "`date` - INFO: no data disks requested, Azure NetApp Files it is!" | tee -a ${_logFile}
	#
	#--------------------------------------------------------------------------------
	# Obtain the private IP address of the VM for future use within the script...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az network nic ip-config show ${_nicName}..." | tee -a ${_logFile}
	_privateipAddr=`az network nic ip-config show --nic-name ${_nicName} --name ipconfig1 | \
		jq '. | {ipaddr: .privateIpAddress}' | \
		grep ipaddr | \
		awk '{print $2}' | \
		sed 's/"//g'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nic ip-config show ${_nicName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Create Azure NetApp Files Delegated Subnet
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az network vnet subnet create ${_ANFsubnetName}..." | tee -a ${_logFile}
	az network vnet subnet create \
		--name ${_ANFsubnetName} \
		--vnet-name ${_vnetName} \
		--delegation Microsoft.Netapp/volumes \
		--address-prefixes 10.0.1.0/24 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network vnet subnet create ${_ANFsubnetName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Create the Azure NetApp Files (ANF) NetApp Account
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles account create ${_ANFaccountName}..." | tee -a ${_logFile}
	az netappfiles account create \
		--account-name ${_ANFaccountName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles account create ${_ANFaccountName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Create the ANF Capacity Pool
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles pool create ${_ANFpoolName}..." | tee -a ${_logFile}
	az netappfiles pool create \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--service-level Premium \
		--size 4 \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles pool create ${_ANFpoolName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Create the ANF Volume
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume create ${_ANFvolumeName}..." | tee -a ${_logFile}
	az netappfiles volume create \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--file-path ${_ANFvolumeName}\
		--usage-threshold 4096 \
		--vnet ${_vnetName} \
		--subnet ${_ANFsubnetName} \
		--protocol-types NFSv4.1 \
		--kerberos-enabled false \
		--allowed-clients ${_privateIp} \
		--rule-index 1 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume create ${_ANFvolumeName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Add a rule to the NFS export policy for our VM at index 2
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume export-policy create for ${_privateipAddr}..." | tee -a ${_logFile}
	az netappfiles volume export-policy add \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--allowed-clients ${_privateipAddr} \
		--rule-index 2 \
		--nfsv41 true \
		--nfsv3 false \
		--cifs false \
		--unix-read-only false \
		--unix-read-write true \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume export-policy create for ${_privateipAddr}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Remove the default rule from the volume export policy at index 1
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume export-policy remove for 0.0.0.0/0..." | tee -a ${_logFile}
	az netappfiles volume export-policy remove \
		--account-name ${_ANFaccountName} \
		--pool-name ${_ANFpoolName} \
		--volume-name ${_ANFvolumeName} \
		--rule-index 1 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume export-policy remove for 0.0.0.0/0" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Get the Azure NetApp Files endpoint IP address
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: az netappfiles volume show ${_ANFvolumeName}..." | tee -a ${_logFile}
	_ANFipAddr=`az netappfiles volume show \
			--account-name ${_ANFaccountName} \
			--pool-name ${_ANFpoolName} \
			--volume-name ${_ANFvolumeName} | \
			jq '.mountTargets[0].ipAddress' | \
			sed 's/"//g'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: az netappfiles volume show ${_ANFvolumeName}" | tee -a ${_logFile}
		exit 1
	fi
	echo "`date` - INFO: IP ${_ANFipAddr} for volume ${_ANFvolumeName}..." | tee -a ${_logFile}
	#
	#--------------------------------------------------------------------------------
	# SSH into the first VM to mount the newly created Azure NetApp Files
	# NFS volume in which the Oracle database files will reside...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mount ${_ANFvolumeName} on ${_vmName}..." | tee -a ${_logFile}
	ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr} "\
		sudo mount -t nfs \
			-o rw,hard,rsize=1048576,wsize=1048576,sec=sys,vers=4.1,tcp \
			${_ANFipAddr}:/${_ANFvolumeName} ${_oraMntDir}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: mount ${_ANFvolumeName} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Enable dNFS in the Oracle software installation...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: enable dNFS on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"cd ${_oraHome}/rdbms/lib; make -f ins_rdbms.mk dnfs_on\"" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: \"make -f ins_rdbms.mk dnfs_on\" on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# If there is no entry for the ANF volume in "/etc/fstab" on the Azure VM, then
	# create an entry to simplify VM restart...
	#--------------------------------------------------------------------------------
	_fstabOutput=`ssh ${_azureOwner}@${_ipAddr} "grep \"/${_ANFvolumeName} \" /etc/fstab"`
	if [[ "${_fstabOutput}" = "" ]]
	then
		_mountOutput=`ssh ${_azureOwner}@${_ipAddr} "mount | grep \"/${_ANFvolumeName} \""`
		if [[ "${_mountOutput}" = "" ]]
		then
			echo "`date` - FAIL: output from \"mount\" for ${_ANFvolumeName} on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		_mountOpts=`echo ${_mountOutput} | awk '{print $6}' | sed 's/(//g' | sed 's/)//g'`
		if [[ "${_mountOpts}" = "" ]]
		then
			echo "`date` - FAIL: parse mount options from \"${_mountOutput}\"" | tee -a ${_logFile}
			exit 1
		fi
		ssh ${_azureOwner}@${_ipAddr} "sudo su - root -c \"echo '${_ANFipAddr}:/${_ANFvolumeName} ${_oraMntDir} nfs ${_mountOpts} 0 0' >> /etc/fstab\"" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: append \"${_ANFvolumeName}\" to \"/etc/fstab\" on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
	fi
	#
else # ...else if _nbrDataDisks > 0, then use managed disks for database storage...
	#
	#--------------------------------------------------------------------------------
	# SSH into the first VM to install the "LVM2" package using the Linux "yum"
	# utility...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: yum install lvm2 on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo yum install -y lvm2" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: yum install lvm2 on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Loop to attach the specified number of data disks...
	#--------------------------------------------------------------------------------
	typeset -i _diskAttached=0
	_pvList=""
	while (( ${_diskAttached} < ${_vmDataDiskNbr} )); do
		#
		#------------------------------------------------------------------------
		# Increment the counter of attached data disks...
		#------------------------------------------------------------------------
		typeset -i _diskAttached=${_diskAttached}+1
		_diskNbr="`echo ${_diskAttached} | awk '{printf("%02d\n",$1)}'`"
		#
		#------------------------------------------------------------------------
		# Create and attach a data disk to the VM...
		#------------------------------------------------------------------------
		echo "`date` - INFO: az vm disk attach (${_vmName}-datadisk${_diskNbr})..." | tee -a ${_logFile}
		az vm disk attach \
			--new \
			--name ${_vmName}-datadisk${_diskNbr} \
			--vm-name ${_vmName} \
			--caching ${_vmDataDiskCaching} \
			--size-gb ${_vmDataDiskSzGB} \
			--sku Premium_LRS \
			--verbose >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: az vm disk create ${_vmName} (${_diskAttached})" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# Identify the name of the SCSI device from the array initialized at the
		# beginning of the script, and derive the name of the single partition on
		# the SCSI device, then add to the list of SCSI partitions for later use...
		#------------------------------------------------------------------------
		_scsiDev="/dev/${_scsiDevList[${_diskAttached}]}"
		_pvName="${_scsiDev}1"
		_pvList="${_pvList}${_pvName} "
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a GPT label on the SCSI device...
		#------------------------------------------------------------------------
		echo "`date` - INFO: parted ${_scsiDev} mklabel on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo parted ${_scsiDev} mklabel gpt" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: parted ${_scsiDev} mklabel gpt on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a single primary partitition consuming the
		# entire SCSI device...
		#------------------------------------------------------------------------
		echo "`date` - INFO: parted ${_scsiDev} mkpart primary on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo parted -a opt ${_scsiDev} mkpart primary xfs 0% 100%" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: parted mkpart -a opt ${_scsiDev} primary xfs 0% 100% on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
		#------------------------------------------------------------------------
		# SSH into the VM to create a physical partition from the SCSI partition...
		#------------------------------------------------------------------------
		echo "`date` - INFO: pvcreate ${_pvName} on ${_vmName}..." | tee -a ${_logFile}
		ssh ${_azureOwner}@${_ipAddr} "sudo pvcreate ${_pvName}" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: pvcreate ${_pvName} on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		#
	done
	#
	#--------------------------------------------------------------------------------
	# Create a volume group from the list of physcial volumes...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: vgcreate ${_vgName} ${_pvList} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo vgcreate ${_vgName} ${_pvList}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgcreate ${_vgName} ${_pvList} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# Obtain the PE Size and Total # of PEs in the volume group, to obtain the size
	# (in MiB) of all the physical volumes in the volume group, which will be the
	# size of the soon-to-be-created logical volume...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: vgdisplay ${_vgName} on ${_vmName}..." | tee -a ${_logFile}
	_peTotal=`ssh ${_azureOwner}@${_ipAddr} "sudo vgdisplay ${_vgName} | grep 'Total PE' | awk '{print \\\$3}'"`
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgdisplay ${_vgName} | grep 'Total PE' on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	_peSize=`ssh ${_azureOwner}@${_ipAddr} "sudo vgdisplay ${_vgName} | grep 'PE Size' | awk '{print \\\$3}'"`
	if (( $? != 0 )); then
		echo "`date` - FAIL: vgdisplay ${_vgName} | grep 'PE Size' on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	typeset -i _lvSize=`echo ${_peTotal} ${_peSize} | awk '{printf("%d\n",$1*$2)}'`
	if (( $? != 0 )); then
		echo "`date` - FAIL: awk '{printf(${_peTotal} * ${_peSize})" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to create a logical volume from the allocated data disks...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: lvcreate ${_vgName} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo lvcreate -n ${_lvName} -i ${_vmDataDiskNbr} -I 1024k -L ${_lvSize}m ${_vgName} ${_pvList}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: lvcreate -n ${_lvName} -i ${_vmDataDiskNbr} -I 1024k -L ${_lvSize}m ${_vgName} ${_pvList} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to create an EXT4 filesystem on the logical volume...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mkfs.xfs /dev/${_vgName}/${_lvName} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo mkfs.xfs /dev/${_vgName}/${_lvName}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: mkfs.xfs /dev/${_vgName}/${_lvName} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# SSH into the VM to mount the filesystem on "/u02"...
	#--------------------------------------------------------------------------------
	echo "`date` - INFO: mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr} "sudo mount /dev/${_vgName}/${_lvName} ${_oraMntDir}" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#--------------------------------------------------------------------------------
	# If there is no entry for the logical volume in "/etc/fstab" on the Azure VM, then
	# create an entry to simplify VM restart...
	#--------------------------------------------------------------------------------
	_fstabOutput=`ssh ${_azureOwner}@${_ipAddr} "grep \"${_vgName}-${_lvName} \" /etc/fstab"`
	if [[ "${_fstabOutput}" = "" ]]
	then
		_mountOutput=`ssh ${_azureOwner}@${_ipAddr} "mount | grep \"${_vgName}-${_lvName} \""`
		if [[ "${_mountOutput}" = "" ]]
		then
			echo "`date` - FAIL: output from \"mount\" for ${_vgName}-${_lvName} on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
		_mountOpts=`echo ${_mountOutput} | awk '{print $6}' | sed 's/(//g' | sed 's/)//g'`
		if [[ "${_mountOpts}" = "" ]]
		then
			echo "`date` - FAIL: parse mount options from \"${_mountOutput}\"" | tee -a ${_logFile}
			exit 1
		fi
		ssh ${_azureOwner}@${_ipAddr} "sudo su - root -c \"echo '/dev/mapper/${_vgName}-${_lvName} ${_oraMntDir} xfs ${_mountOpts} 0 0' >> /etc/fstab\"" >> ${_logFile} 2>&1
		if (( $? != 0 )); then
			echo "`date` - FAIL: append \"${_lvName} ${_oraMntDir}\" to \"/etc/fstab\" on ${_vmName}" | tee -a ${_logFile}
			exit 1
		fi
	fi
	#
fi
#
#------------------------------------------------------------------------
# SSH into the VM to determine how much physical RAM there is and then
# use the RHEL7 formula to determine needed swap space, and then configure
# the Azure Linux agent (waagent) to recreate upon boot...
#------------------------------------------------------------------------
echo "`date` - INFO: free -m to find physical RAM on ${_vmName}..." | tee -a ${_logFile}
typeset -i _ramMB=`ssh ${_azureOwner}@${_ipAddr} "free -m | grep '^Mem:' | awk '{print \\\$2}'" 2>&1`
if (( $? != 0 )); then
	echo "`date` - FAIL: free -m on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
if [[ "${_ramMB}" = "" ]]
then
	echo "`date` - FAIL: free -m returned NULL on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
if (( ${_ramMB} <= 2048 ))			# when RAM less than 2GB then...
then						# ...swap = double RAM
	typeset -i _swapMB=${_ramMB}*2
else
	if (( ${_ramMB} <= 8192 ))		# when RAM less than 8GB then...
	then					# ...swap = RAM
		typeset -i _swapMB=${_ramMB}
	else
		if (( ${_ramMB} <= 43690 ))	# when RAM between 8-64GB then...
		then				# ...swap = RAM * 1.5
			typeset -i _swapMB=`echo ${_ramMB} | awk '{printf("%d\n",$1*1.5)}'`
		else				# otherwise...
			typeset -i _swapMB=65536 # ...swap no larger than 64GB
		fi
	fi
fi
echo "`date` - INFO: configure waagent for ${_swapMB}M swap on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo sed -i.old -e 's/^ResourceDisk.EnableSwap=n$/ResourceDisk.EnableSwap=y/' -e 's/^ResourceDisk.SwapSizeMB=0$/ResourceDisk.SwapSizeMB='${_swapMB}'/' /etc/waagent.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed /etc/waagent.conf on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#------------------------------------------------------------------------
# SSH into first VM to create sub-directories for the Oracle database
# files, the Oracle Fast Recovery Area (FRA) files, and the Oracle
# archived redo log files...
#------------------------------------------------------------------------
echo "`date` - INFO: mkdir ${_oraDataDir} ${_oraFRADir} ${_oraArchDir} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir -p ${_oraDataDir} ${_oraFRADir} ${_oraArchDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p ${_oraDataDir} ${_oraFRADir} ${_oraArchDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set the OS account:group ownership of the mount-points...
#--------------------------------------------------------------------------------
echo "`date` - INFO: chown -R ${_oraMntDir} ${_oraArchDir} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo chown -R ${_oraOsAcct}:${_oraOsGroup} ${_oraMntDir} ${_oraArchDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown -R ${_oraMntDir} ${_oraArchDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to copy the file "oraInst.loc" from the current Oracle
# Inventory default location into the "/etc" system directory, where it can be
# easily found by any Oracle programs accessing the host.  Set the ownership and
# permissions appropriately for the copied file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: copy oraInst.loc file on ${_vmName}" | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo cp -n ${_oraInvDir}/oraInst.loc /etc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo cp -n ${_azureOwner}@${_ipAddr}:${_oraInvDir}/oraInst.loc /etc" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chmod 644 /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chmod 644 /etc/oraInst.loc" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Perform an update of all OS packages to be sure that all are up-to-date...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum update on ${_vmName} (1: be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update #1 on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Now, perform another update of all OS packages, because often the first update
# doesn't get all of them...
#--------------------------------------------------------------------------------
echo "`date` - INFO: 2nd yum update on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update #2 on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Install the CIFS-UTILS package on the VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum install cifs-utils on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo yum install cifs-utils -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum install cifs-utils on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Re-set the contents of the ".cred" file within "/etc/smbcredentials" folder...
#--------------------------------------------------------------------------------
_cifsCredDir=/etc/smbcredentials
_cifsCredFile=${_cifsCredDir}/${_saName}.cred
echo "`date` - INFO: set contents of ${_cifsCredFile} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir -p ${_cifsCredDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p ${_cifsCredDir} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo rm -f ${_cifsCredFile}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo echo rm -f ${_cifsCredFile} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "echo username=${_saName} | sudo tee ${_cifsCredFile} > /dev/null" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: echo username=${_saName} | sudo tee ${_cifsCredFile} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chmod 600 ${_cifsCredFile}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chmod 600 ${_cifsCredFile} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "echo password=${_saKey} | sudo tee -a ${_cifsCredFile} > /dev/null" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: echo password=${_saKey} | sudo tee -a ${_cifsCredFile} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Extract the CIFS/SMB path from the SMB HTTPS string and append the share name...
#--------------------------------------------------------------------------------
_cifsPath="`echo ${_saHttps} | sed 's/https://'`${_shareName}"
#
#--------------------------------------------------------------------------------
# Retrieve numeric IDs for "oracle" OS account and "oinstall" OS group...
#--------------------------------------------------------------------------------
_oraUid=`ssh ${_azureOwner}@${_ipAddr} "grep oracle /etc/passwd" | awk -F: '{print $3}' 2>&1`
if (( $? != 0 )); then
	echo "`date` - FAIL: grep oracle /etc/passwd for UID on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
_oraGid=`ssh ${_azureOwner}@${_ipAddr} "grep oracle /etc/passwd" | awk -F: '{print $4}' 2>&1`
if (( $? != 0 )); then
	echo "`date` - FAIL: grep oracle /etc/passwd for GID on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Compile the CIFS/SMB options string to use when mounting...
#--------------------------------------------------------------------------------
_cifsOptions="vers=3.0,credentials=${_cifsCredFile},serverino,cache=none,uid=${_oraUid},gid=${_oraGid}"
#
#--------------------------------------------------------------------------------
# Mount the Azure File standard share for the Oracle archived redo log files...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mount -t cifs ${_cifsPath} ${_oraArchDir} on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mount -t cifs ${_cifsPath} ${_oraArchDir} -o ${_cifsOptions}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mount -t cifs ${_cifsPath} ${_oraArchDir} -o ${_cifsOptions} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set mount options for permanent setting after reboot in /etc/fstab...
#--------------------------------------------------------------------------------
echo "`date` - INFO: set CIFS/SMB info into /etc/fstab on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "echo ${_cifsPath} ${_oraArchDir} cifs ${_cifsOptions} 0 0 | sudo tee -a /etc/fstab" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: echo ${_cifsPath} ${_oraArchDir} cifs ${_cifsOptions} 0 0 | sudo tee -a /etc/fstab on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to run the Oracle Database Creation Assistant (DBCA)
# program to create a new primary Oracle database...
#--------------------------------------------------------------------------------
echo "`date` - INFO: dbca -createDatabase ${_oraSid} on ${_vmName} (be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"\
	export ORACLE_SID=${_oraSid}
	export ORACLE_HOME=${_oraHome}
	export PATH=${_oraHome}/bin:\${PATH}
	unset TNS_ADMIN
	dbca -silent -createDatabase \
		-gdbName ${_oraSid} \
		-templateName ${_oraHome}/assistants/dbca/templates/General_Purpose.dbc \
		-sid ${_oraSid} \
		-sysPassword ${_oraSysPwd} \
		-systemPassword ${_oraSysPwd} \
		-characterSet ${_oraCharSet} \
		-createListener LISTENER:${_oraLsnrPort} \
		-storageType FS \
		-datafileDestination ${_oraDataDir} \
		-enableArchive TRUE \
		-memoryMgmtType ${_oraMemType} \
		-memoryPercentage ${_oraMemPct} \
		-initParams db_create_online_log_dest_1=${_oraFRADir},log_archive_dest_1=\"location=${_oraArchDir}\" \
		-recoveryAreaDestination ${_oraFRADir} \
		-recoveryAreaSize ${_oraFraSzGB} \
		-redoLogFileSize ${_oraRedoSizeMB}\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: dbca -createDatabase ${_oraSid} on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create the "oradata" subdirectory on the temporary disk within the "/mnt/resource"
# directory of the Linux VM, owned by the Oracle OS account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir -p /mnt/resource/oradata on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir -p /mnt/resource/oradata" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir -p /mnt/resource/oradata on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /mnt/resource/oradata on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a "temporary use" temporary tablespace (named TEMPTMPTEMP), make it
# default, then drop and recreate the TEMP tablespace on the VM temporary disk,
# then make TEMP the default and clean up the "temporary use" TEMPTMPTEMP
# tablespace...
#--------------------------------------------------------------------------------
echo "`date` - INFO: move TEMP tablespace to temporary disk on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:\${PATH}
unset TNS_ADMIN
sqlplus -S -L / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
alter session set db_create_file_dest='/mnt/resource/oradata';
create temporary tablespace temptmptemp tempfile size 10M;
alter database default temporary tablespace temptmptemp;
shutdown immediate
startup
drop tablespace temp including contents and datafiles;
alter session set db_create_file_dest='/mnt/resource/oradata';
create temporary tablespace temp
	tempfile size 512M autoextend on next 512M maxsize unlimited
	extent management local uniform size 1M;
alter database default temporary tablespace temp;
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: move TEMP tablespace to temporary disk on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:\${PATH}
unset TNS_ADMIN
sqlplus -S -L / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
drop tablespace temptmptemp including contents and datafiles;
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: drop TEMPTMPTEMP tablespace disk on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a helpful shell script named "orareboot.sh" in the "/root" directory on
# the VM.  This script will recreate the "/mnt/resource/oradata" directory with
# the correct ownership and permissions and will also remount "/u02" if it isn't
# currently mounted...
#--------------------------------------------------------------------------------
_scriptFile=/tmp/.${_azureOwner}_${_azureProject}_$$.tmp
rm -f ${_scriptFile}
if (( $? != 0 ))
then
	echo "`date` - FAIL: \"rm -f ${_scriptFile}\"" | tee -a ${_logFile}
	exit 1
fi
echo "#!/bin/bash"					 > ${_scriptFile}
echo "#"						>> ${_scriptFile}
echo "_tempFilesDir=\"/mnt/resource/oradata\""		>> ${_scriptFile}
echo "_nfsMntPt=\"${_oraMntDir}\""			>> ${_scriptFile}
echo "#"						>> ${_scriptFile}
echo "if [ ! -d \${_tempFilesDir} ]"			>> ${_scriptFile}
echo "then"						>> ${_scriptFile}
echo "	mkdir \${_tempFilesDir}"			>> ${_scriptFile}
echo "	chown oracle:oinstall \${_tempFilesDir}"	>> ${_scriptFile}
echo "	chmod 775 \${_tempFilesDir}"			>> ${_scriptFile}
echo "	ls -ld \${_tempFilesDir}"			>> ${_scriptFile}
echo "else"						>> ${_scriptFile}
echo "	echo \"\${_tempFilesDir} exists\""		>> ${_scriptFile}
echo "fi"						>> ${_scriptFile}
echo "#"						>> ${_scriptFile}
echo "if [[ \"\`mount | grep \\\" \${_nfsMntPt} \\\"\`\" = \"\" ]]"	>> ${_scriptFile}
echo "then"						>> ${_scriptFile}
echo "	mount \${_nfsMntPt}"				>> ${_scriptFile}
echo "	df -h \${_nfsMntPt}"				>> ${_scriptFile}
echo "else"						>> ${_scriptFile}
echo "	echo \"\${_nfsMntPt} mounted\""			>> ${_scriptFile}
echo "fi"						>> ${_scriptFile}
chmod 755 ${_scriptFile}
if (( $? != 0 ))
then
	echo "`date` - FAIL: \"chmod 755 ${_scriptFile}\"" | tee -a ${_logFile}
	exit 1
fi
scp ${_scriptFile} ${_azureOwner}@${_ipAddr}:/tmp/orareboot.sh >> ${_logFile} 2>&1
if (( $? != 0 ))
then
	echo "`date` - FAIL: \"scp ${_scriptFile} ${_azureOwner}@${_ipAddr}:/tmp/orareboot.sh\"" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo mv /tmp/orareboot.sh /root" >> ${_logFile} 2>&1
if (( $? != 0 ))
then
	echo "`date` - FAIL: \"sudo mv /tmp/orareboot.sh /root\" on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Enable Azure VM Backup protection using the policy and vault just created...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az backup protection enable-for-vm ${_vmName}..." | tee -a ${_logFile}
az backup protection enable-for-vm \
	--policy-name ${_policyName} \
	--vault-name ${_vaultName} \
	--vm ${_vmName} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az backup protection enable-for-vm ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create an OS account named "azbackup" belonging to the OS group named
# "backupdba" on the VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: useradd -g backupdba azbackup on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo useradd -g backupdba azbackup" >> ${_logFile} 2>&1
if (( $? != 0 )); then
        echo "`date` - FAIL: sudo useradd -g backupdba azbackup on ${_vmName}" | tee -a ${_logFile}
        exit 1
fi
#
#--------------------------------------------------------------------------------
# Create an OS-authenticated database account named OPS$AZBACKUP within the
# database, and also create a stored procedure named AZMESSAGE within the
# SYSBACKUP account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: setup Azure VM Backup within Oracle database on ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:\${PATH}
unset TNS_ADMIN
cd ${_oraHome}/dbs
mv orapw${_oraSid} orapw${_oraSid}.save
orapwd input_file=orapw${_oraSid}.save file=orapw${_oraSid} format=12.2
sqlplus -S -L / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
CREATE USER \\\"OPS\\\\\\\$AZBACKUP\\\" IDENTIFIED EXTERNALLY;
GRANT CREATE SESSION, ALTER SESSION, SYSBACKUP TO \\\"OPS\\\\\\\$AZBACKUP\\\";
GRANT EXECUTE ON DBMS_SYSTEM TO SYSBACKUP;
CREATE PROCEDURE sysbackup.azmessage(in_msg IN VARCHAR2)
AS v_timestamp     VARCHAR2(32);
BEGIN
  SELECT TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS')
    INTO v_timestamp FROM DUAL;
  DBMS_OUTPUT.PUT_LINE(v_timestamp || ' - ' || in_msg);
  SYS.DBMS_SYSTEM.KSDWRT(SYS.DBMS_SYSTEM.ALERT_FILE, in_msg);
END azmessage;
/
SHOW ERRORS
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: setup Azure VM Backup within Oracle database on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a local copy of the "workload.conf" file to be copied into the
# "/etc/azure" subdirectory on the VM, with contents appropriate for configuring
# the backing up of an Oracle database...
#--------------------------------------------------------------------------------
rm -f ${_workloadConfFile}
echo "[workload]"				>  ${_workloadConfFile}
echo "workload_name = oracle"			>> ${_workloadConfFile}
echo "configuration_path = /etc/oratab"		>> ${_workloadConfFile}
echo "timeout = 90"				>> ${_workloadConfFile}
echo "linux_user = azbackup"			>> ${_workloadConfFile}
#
#--------------------------------------------------------------------------------
# Now that the "/etc/azure/workload.conf" file has been initialized on the VM,
# replace it with contents appropriate for backing up Oracle databases...
#--------------------------------------------------------------------------------
echo "`date` - INFO: copy new workload.conf file to ${_vmName}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo mkdir /etc/azure" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir /etc/azure on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
scp ${_workloadConfFile} ${_azureOwner}@${_ipAddr}:/tmp/workload.conf >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: scp ${_workloadConfFile} ${_azureOwner}@${_ipAddr}:/tmp/workload.conf on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo mv /tmp/workload.conf /etc/azure/workload.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mv /tmp/workload.conf /etc/azure/workload.conf on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr} "sudo chown root:root /etc/azure/workload.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown root:root /etc/azure/workload.conf on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Pause for 60 more seconds before attempting to initiate the initial Azure VM Backup...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pausing for 60 seconds before initiating first backup on ${_vmName}..." | tee -a ${_logFile}
sleep 60
#
#--------------------------------------------------------------------------------
# Start an Azure VM Backup running now...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az backup protection backup-now ${_vmName}..." | tee -a ${_logFile}
az backup protection backup-now \
	--item-name ${_vmName} \
	--backup-management-type AzureIaasVM \
	--workload-type VM \
	--container-name ${_vmName} \
	--vault-name ${_vaultName} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az backup protection backup-now ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Edit the "/etc/default/grub" configuration file has the correct list of LVM2
# volume groups and logical volumes in "rd.lvm.lv" entries...
#--------------------------------------------------------------------------------
echo "`date` - INFO: reset LVM2 info in /etc/default/grub configuration file..." | tee -a ${_logFile}
_tmpGrubFile=/tmp/.${_progName}_grub_$$.tmp
rm -f ${_tmpGrubFile}
scp ${_azureOwner}@${_ipAddr}:/etc/default/grub ${_tmpGrubFile} >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: scp /etc/default/grub from ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
if [[ "`grep '^GRUB_CMDLINE_LINUX=' ${_tmpGrubFile}`" = "" ]]
then	# ...create a new blank GRUB_CMDLINE_LINUX string...
	#
	_grubCmdlineLinux="GRUB_CMDLINE_LINUX=\"\""
	_addGrubCmdlineLinux=true
	_spc=""
	#
else	# ...strip the existing "rd.lvm.lv" entries from GRUB_CMDLINE_LINUX string...
	#
	_grubCmdlineLinux=`echo ${_str} | \
				sed 's~"rd.lvm.lv=[a-z0-9]*/[a-z0-9]* ~"~g' | \
				sed 's~ rd.lvm.lv=[a-z0-9]*/[a-z0-9]*"~"~g' | \
				sed 's~rd.lvm.lv=[a-z0-9]*/[a-z0-9]* ~~g'`
	_addGrubCmdlineLinux=false
	_spc=" "
	#
fi
_tmpLvsFile=/tmp/.${_progName}_lvs_$$.tmp
_tmpErrFile=/tmp/.${_progName}_err_$$.tmp
rm -f ${_tmpLvsFile} ${_tmpErrFile}
ssh ${_azureOwner}@${_ipAddr} "sudo lvs -o vg_name,lv_name" 2> ${_tmpErrFile} | sed '1d' > ${_tmpLvsFile}
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo lvs -o vg_name,lv_name on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
while read _vg _lv
do
	_grubCmdlineLinux=`echo ${_grubCmdlineLinux} | sed "s~\"\$~${_spc}rd.lvm.lv=${_vg}/${_lv}\"~"`
	_spc=" "
done < ${_tmpLvsFile}
rm -f ${_tmpLvsFile}
if [[ "`cat ${_tmpErrFile}`" != "" ]]
then
	echo "`date` - FAIL: sudo lvs -o vg_name,lv_name on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
rm -f ${_tmpErrFile}
if [[ "${_addGrubCmdlineLinux}" = "true" ]]; then
	echo "${_grubCmdlineLinux}" >> ${_tmpGrubFile}
	if (( $? != 0 )); then
		echo "`date` - FAIL: echo GRUB_CMDLINE_LINUX >> ${_tmpGrubFile}" | tee -a ${_logFile}
		exit 1
	fi
else
	sed -i "s~^GRUB_CMDLINE_LINUX=\"[^\"]*\"\$~${_grubCmdlineLinux}~" ${_tmpGrubFile} >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: sed -i GRUB_CMDLINE_LINUX ${_tmpGrubFile}" | tee -a ${_logFile}
		exit 1
	fi
fi
scp ${_tmpGrubFile} ${_azureOwner}@${_ipAddr}:/tmp/grub.tmp >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: scp ${_tmpGrubFile} to /tmp/grub.tmp on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
rm -f ${_tmpGrubFile}
ssh ${_azureOwner}@${_ipAddr} "sudo cp /tmp/grub.tmp /etc/default/grub" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo cp /tmp/grub.tmp /etc/default/grub on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Regenerate the initramfs file in the boot directory...
#--------------------------------------------------------------------------------
echo "`date` - INFO: using dracut to regenerate initramfs..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo dracut -f /boot/initramfs-\$(uname -r).img \$(uname -r)" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo dracut -f /boot/initramfs-\$(uname -r).img \$(uname -r) on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Recreate the GRUB2 configuration file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: recreate grub2 configuration file..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo grub2-mkconfig -o /etc/grub2.cfg" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo grub2-mkconfig -o /etc/grub2.cfg on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Reboot the virtual machine...
#--------------------------------------------------------------------------------
echo "`date` - INFO: reboot..." | tee -a ${_logFile}
az vm restart --name ${_vmName} --verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm restart --name ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# After the reboot, restart the Oracle listener and database...
#--------------------------------------------------------------------------------
echo "`date` - INFO: restart Oracle listener and database..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr} "sudo su - ${_oraOsAcct} -c \"\
export ORACLE_SID=${_oraSid}
export ORACLE_HOME=${_oraHome}
export PATH=${_oraHome}/bin:\${PATH}
unset TNS_ADMIN
lsnrctl start LISTENER
sqlplus -S -L / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
startup
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: restart Oracle listener and database on ${_vmName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Completed the setup successfully!  End of program...
#--------------------------------------------------------------------------------
echo "`date` - INFO: completed successfully!" | tee -a ${_logFile}
exit 0
