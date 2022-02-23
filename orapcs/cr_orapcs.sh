#!/bin/bash
#================================================================================
# Name:	cr_orapcs.sh
# Type:	bash script
# Date:	13-May 2020
# From: Customer Architecture & Engineering (CAE) - Microsoft
#
# Copyright and license:
#
#	Licensed under the Apache License, Version 2.0 (the "License"); you may
#	not use this file except in compliance with the License.
#
#	You may obtain a copy of the License at
#
#		http://www.apache.org/licenses/LICENSE-2.0
#
#	Unless required by applicable law or agreed to in writing, software
#	distributed under the License is distributed on an "AS IS" basis,
#	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#
#	See the License for the specific language governing permissions and
#	limitations under the License.
#
#	Copyright (c) 2020 by Microsoft.  All rights reserved.
#
# Ownership and responsibility:
#
#	This script is offered without warranty by Microsoft Customer Engineering.
#	Anyone using this script accepts full responsibility for use, effect,
#	and maintenance.  Please do not contact Microsoft support unless there
#	is a problem with a supported Azure component used in this script,
#	such as an "az" command.
#
# Description:
#
#	Script to automate the creation of a Pacemaker/Corosync HA cluster (PCS)
#	for an Oracle database within Microsoft Azure, using the Azure CLI.
#
# Command-line Parameters:
#
#	cr_orapcs.sh -N -M -O val -P val -S val -V val -g val -h val -i val -r val -u val -v -w val
#
#	where:
#
#	-N			skip steps to create vnet/subnet, public-IP, NSG, rules, and PPG
#	-M			skip steps to create VMs and storage
#	-O owner-tag		name of the owner to use in Azure tags (no default)
#	-P project-tag		name of the project to use in Azure tags (no default)
#	-S subscription		name of the Azure subscription (no default)
#	-V vip-IPaddr		IP address for the virtual IP (VIP) (default: 10.0.0.10)
#	-g resource-group	name of the Azure resource group (default: ${_azureOwner}-${_azureProject}-rg)
#	-h ORACLE_HOME		full path of the ORACLE_HOME software (default: /u01/app/oracle/product/19.0.0/dbhome_1)
#	-i instance-type	name of the Azure VM instance type for database nodes (default: Standard_D2s_v4)
#	-r region		name of Azure region (default: westus2)
#	-u urn			Azure URN for the VM from the marketplace
#				(default: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1)
#	-v			set verbose output is true (default: false)
#	-w password		Oracle SYS/SYSTEM account password (default: oracleA1)
#
# Usage notes:
#
#	1) Azure subscription must be specified with "-S" switch, always
#
#	2) Azure owner, default is output of "whoami" command in shell, can be
#	   specified using "-O" switch on command-line
#
#	3) Azure project, default is "orapcs", can be specified using "-P"
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
#	   subnet, network security groups, etc), consider using the "-N"
#	   switch to accept these as prerequisites 
#
#	Please be aware that Azure owner (i.e. "-O") and Azure project (i.e. "-P")
#	are used to generate names for the Azure resource group, storage
#	account, virtual network, subnet, network security group and rules,
#	VM, and storage disks.  Use the "-v" switch to verify expected naming.
#
#	The "-N" and "-M" switches were mainly used for debugging, and might well
#	be removed in more mature versions of the script.  They intended to skip
#	over some steps if something failed later on.
#
# Modifications:
#	TGorman	13may20	v0.1	written
#	TGorman 27jul20	v0.2	added new cmd-line parameters
#	TGorman 14aug20	v0.3	added SCSI fencing
#	TGorman	17aug20	v0.4	added pause before CRM_VERIFY on both nodes
#	TGorman	11sep20	v0.5	added availability set for both nodes
#	TGorman	10nov20	v0.6	added Azure load balancer for VIP, create 3rd VM
#				from which to test, and change default URN value
#				from Oracle12c v12.2 to Oracle19c v19.3 as well
#				as the default ORACLE_HOME path value
#	TGorman	12nov20 v0.7	contains code to disable Linux firewalld; also
#				has code that is commented-out to enable Linux
#				firewall and open necessary ports
#	TGorman	29jan21	v0.8	set accelerated networking TRUE at NIC creation
#				and change default VM instance type to
#				"Standard_D2s_v4"
#	TGorman	05apr21	v0.9	correct handling of ephemeral SSD by instance type
#	TGorman	26apr21 v1.0	set waagent.conf to rebuild swapfile after reboot,
#				set default image to 19c, and perform yum updates
#	TGorman	23jun21	v1.1	set resource-stickiness=100
#================================================================================
#
#--------------------------------------------------------------------------------
# Set global environment variables for the entire script...
#--------------------------------------------------------------------------------
_progName="orapcs"
_progVersion="v1.1"
_progArgs="$*"
_outputMode="terse"
_azureOwner="`whoami`"
_azureProject="orapcs"
_azureRegion="westus2"
_azureSubscription=""
_skipVnetNicNsg="false" 
_skipMachines="false" 
_workDir="`pwd`"
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_rgName="${_azureOwner}-${_azureProject}-rg"
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_ppgName="${_azureOwner}-${_azureProject}-ppg"
_avSetName="${_azureOwner}-${_azureProject}-avset"
_lbName="${_azureOwner}-${_azureProject}-lb"
_lbPoolName="${_azureOwner}-${_azureProject}-lb-pool"
_lbProbeName="${_azureOwner}-${_azureProject}-lb-probe"
_lbProbePort="62503"
_lbRuleName="${_azureOwner}-${_azureProject}-lb-rule"
_vmSharedDisk="${_azureOwner}-${_azureProject}-sharedDisk01"
_nicName1="${_azureOwner}-${_azureProject}-nic01"
_nicName2="${_azureOwner}-${_azureProject}-nic02"
_nicName3="${_azureOwner}-${_azureProject}-nic03"
_pubIpName1="${_azureOwner}-${_azureProject}-public-ip01"
_pubIpName2="${_azureOwner}-${_azureProject}-public-ip02"
_pubIpName3="${_azureOwner}-${_azureProject}-public-ip03"
_vmNbr1="vm01"
_vmNbr2="vm02"
_vmNbr3="vm03"
_vmName1="${_azureOwner}-${_azureProject}-${_vmNbr1}"
_vmName2="${_azureOwner}-${_azureProject}-${_vmNbr2}"
_vmName3="${_azureOwner}-${_azureProject}-${_vmNbr3}"
_vmUrn="Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1"
_vmDomain="internal.cloudapp.net"
_vmFQDN1="${_vmName1}.${_vmDomain}"
_vmFQDN2="${_vmName2}.${_vmDomain}"
_vmOsDiskSize="32"
_vmDataDiskSize="1024"
_vmInstanceType="Standard_D2s_v4"
_oraSid="oradb01"
_oraBase="/u01/app/oracle"
_oraVersion="19.0.0"
_oraHome="${_oraBase}/product/${_oraVersion}/dbhome_1"
_oraTnsDir=${_oraHome}/network/admin
_oraInvDir="/u01/app/oraInventory"
_oraOsAcct="oracle"
_oraOsGroup="oinstall"
_oraCharSet="WE8ISO8859P15"
_vgName="vg_shared_ora01"
_lvName="lv_shared_ora01"
_fsType="xfs"
_oraMntDir="/u02"
_oraDataDir="${_oraMntDir}/oradata"
_oraFRADir="${_oraMntDir}/orarecv"
_oraConfDir="${_oraMntDir}/oraconf"
_oraClusterSvcAcct="ocfmon"
_oraSysPwd="oracleA1"
_oraRedoSizeMB="500"
_oraLsnr="LISTENER"
_oraLsnrPort="1521"
_pcsClusterUser="hacluster"
_pcsClusterName="${_azureOwner}-${_azureProject}-cluster"
_pcsClusterGroup="${_azureOwner}-${_azureProject}-group"
_pcsClusterVIP="${_azureOwner}-${_azureProject}-vip"
_pcsClusterLB="${_lbName}"
_pcsClusterLVM="${_azureOwner}-${_azureProject}-lvm"
_pcsClusterFS="${_azureOwner}-${_azureProject}-fs"
_pcsClusterDB="${_azureOwner}-${_azureProject}-db"
_pcsClusterLsnr="${_azureOwner}-${_azureProject}-lsnr"
_pcsFenceName="${_azureOwner}-${_azureProject}-fence"
_pcsVipAddr="10.0.0.10"
_pcsVipMask="24"
#
#--------------------------------------------------------------------------------
# Accept command-line parameter values to override default values (above)..
#--------------------------------------------------------------------------------
typeset -i _parseErrs=0
while getopts ":MNO:P:S:V:g:h:i:r:u:vw:" OPTNAME
do
	case "${OPTNAME}" in
		M)	_skipMachines="true"		;;
		N)	_skipVnetNicNsg="true"		;;
		O)	_azureOwner="${OPTARG}"		;;
		P)	_azureProject="${OPTARG}"	;;
		S)	_azureSubscription="${OPTARG}"	;;
		V)	_pcsVipAddr="${OPTARG}"		;;
		g)	_rgName="${OPTARG}"		;;
		h)	_oraHome="${OPTARG}"		;;
		i)	_vmInstanceType="${OPTARG}"	;;
		r)	_azureRegion="${OPTARG}"	;;
		u)	_vmUrn="${OPTARG}"		;;
		v)	_outputMode="verbose"		;;
		w)	_oraSysPwd="${OPTARG}"		;;
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
if (( ${_parseErrs} > 0 )); then
	echo "Usage: $0 -M -N -O val -P val -S val -V val -g val -h val -i val -r val -u val -v -w val"
	echo "where:"
	echo "	-M 			skip steps to create VMs and storage"
	echo "	-N 			skip steps to create vnet/subnet, public-IP, NSG, rules, and PPG"
	echo "	-O owner-tag		name of the owner to use in Azure tags (no default)"
	echo "	-P project-tag		name of the project to use in Azure tags (no default)"
	echo "	-S subscription		name of the Azure subscription (no default)"
	echo "	-V vip-IPaddr		IP address for the virtual IP (VIP) (default: 10.0.0.10)"
	echo "	-g resource-group	name of the Azure resource group (default: ${_azureOwner}-${_azureProject}-rg)"
	echo "	-h ORACLE_HOME		full path of the ORACLE_HOME software (default: /u01/app/oracle/product/19.0.0/dbhome_1)"
	echo "	-i instance-type	name of the Azure VM instance type for database nodes (default: Standard_D2s_v4)"
	echo "	-r region		name of Azure region (default: westus2)"
	echo "	-u urn			Azure URN for the VM from the marketplace"
	echo "				(default: Oracle:oracle-database-19-3:oracle-database-19-0904:19.3.1)"
	echo "	-v			set verbose output is true (default: false)"
	echo "	-w password		Oracle SYS/SYSTEM account password (default: oracleA1)"
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Re-set script variables in case "owner" or "project" was changed...
#--------------------------------------------------------------------------------
_logFile="${_workDir}/${_azureOwner}-${_azureProject}.log"
_vnetName="${_azureOwner}-${_azureProject}-vnet"
_subnetName="${_azureOwner}-${_azureProject}-subnet"
_nsgName="${_azureOwner}-${_azureProject}-nsg"
_ppgName="${_azureOwner}-${_azureProject}-ppg"
_avSetName="${_azureOwner}-${_azureProject}-avset"
_lbName="${_azureOwner}-${_azureProject}-lb"
_lbPoolName="${_azureOwner}-${_azureProject}-lb-pool"
_lbProbeName="${_azureOwner}-${_azureProject}-lb-probe"
_lbRuleName="${_azureOwner}-${_azureProject}-lb-rule"
_vmSharedDisk="${_azureOwner}-${_azureProject}-sharedDisk01"
_nicName1="${_azureOwner}-${_azureProject}-nic01"
_nicName2="${_azureOwner}-${_azureProject}-nic02"
_nicName3="${_azureOwner}-${_azureProject}-nic03"
_pubIpName1="${_azureOwner}-${_azureProject}-public-ip01"
_pubIpName2="${_azureOwner}-${_azureProject}-public-ip02"
_pubIpName3="${_azureOwner}-${_azureProject}-public-ip03"
_vmName1="${_azureOwner}-${_azureProject}-${_vmNbr1}"
_vmName2="${_azureOwner}-${_azureProject}-${_vmNbr2}"
_vmName3="${_azureOwner}-${_azureProject}-${_vmNbr3}"
_vmFQDN1="${_vmName1}.${_vmDomain}"
_vmFQDN2="${_vmName2}.${_vmDomain}"
_pcsClusterName="${_azureOwner}-${_azureProject}-cluster"
_pcsClusterGroup="${_azureOwner}-${_azureProject}-group"
_pcsClusterVIP="${_azureOwner}-${_azureProject}-vip"
_pcsClusterLB="${_lbName}"
_pcsClusterLVM="${_azureOwner}-${_azureProject}-lvm"
_pcsClusterFS="${_azureOwner}-${_azureProject}-fs"
_pcsClusterDB="${_azureOwner}-${_azureProject}-db"
_pcsClusterLsnr="${_azureOwner}-${_azureProject}-lsnr"
_pcsFenceName="${_azureOwner}-${_azureProject}-fence"
_oraTnsDir=${_oraHome}/network/admin
#
#--------------------------------------------------------------------------------
# Display variable values when output is set to "verbose"...
#--------------------------------------------------------------------------------
if [[ "${_outputMode}" = "verbose" ]]; then
	echo "`date` - DBUG: variable _progName is \"${_progName}\""
	echo "`date` - DBUG: variable _progVersion is \"${_progVersion}\""
	echo "`date` - DBUG: variable _progArgs is \"${_progArgs}\""
	echo "`date` - DBUG: parameter _skipVnetNicNsg is \"${_skipVnetNicNsg}\""
	echo "`date` - DBUG: parameter _skipMachines is \"${_skipMachines}\""
	echo "`date` - DBUG: parameter _rgName is \"${_rgName}\""
	echo "`date` - DBUG: parameter _azureOwner is \"${_azureOwner}\""
	echo "`date` - DBUG: parameter _azureProject is \"${_azureProject}\""
	echo "`date` - DBUG: parameter _azureSubscription is \"${_azureSubscription}\""
	echo "`date` - DBUG: parameter _pcsVipAddr is \"${_pcsVipAddr}\""
	echo "`date` - DBUG: parameter _vmInstanceType is \"${_vmInstanceType}\""
	echo "`date` - DBUG: parameter _azureRegion is \"${_azureRegion}\""
	echo "`date` - DBUG: parameter _vmUrn is \"${_vmUrn}\""
	echo "`date` - DBUG: variable _workDir is \"${_workDir}\""
	echo "`date` - DBUG: variable _logFile is \"${_logFile}\""
	echo "`date` - DBUG: variable _vmDomain is \"${_vmDomain}\""
	echo "`date` - DBUG: variable _vnetName is \"${_vnetName}\""
	echo "`date` - DBUG: variable _subnetName is \"${_subnetName}\""
	echo "`date` - DBUG: variable _nsgName is \"${_nsgName}\""
	echo "`date` - DBUG: variable _ppgName is \"${_ppgName}\""
	echo "`date` - DBUG: variable _avSetName is \"${_avSetName}\""
	echo "`date` - DBUG: variable _lbName is \"${_lbName}\""
	echo "`date` - DBUG: variable _lbPoolName is \"${_lbPoolName}\""
	echo "`date` - DBUG: variable _lbProbeName is \"${_lbProbeName}\""
	echo "`date` - DBUG: variable _lbRuleName is \"${_lbRuleName}\""
	echo "`date` - DBUG: variable _nicName1 is \"${_nicName1}\""
	echo "`date` - DBUG: variable _pubIpName1 is \"${_pubIpName1}\""
	echo "`date` - DBUG: variable _vmName1 is \"${_vmName1}\""
	echo "`date` - DBUG: variable _nicName2 is \"${_nicName2}\""
	echo "`date` - DBUG: variable _pubIpName2 is \"${_pubIpName2}\""
	echo "`date` - DBUG: variable _vmName2 is \"${_vmName2}\""
	echo "`date` - DBUG: variable _nicName3 is \"${_nicName3}\""
	echo "`date` - DBUG: variable _pubIpName3 is \"${_pubIpName3}\""
	echo "`date` - DBUG: variable _vmName3 is \"${_vmName3}\""
	echo "`date` - DBUG: variable _oraSid is \"${_oraSid}\""
	echo "`date` - DBUG: variable _oraLsnr is \"${_oraLsnr}\""
	echo "`date` - DBUG: variable _oraLsnrPort is \"${_oraLsnrPort}\""
	echo "`date` - DBUG: variable _pcsClusterName is \"${_pcsClusterName}\""
	echo "`date` - DBUG: variable _pcsClusterGroup is \"${_pcsClusterGroup}\""
	echo "`date` - DBUG: variable _pcsClusterUser is \"${_pcsClusterUser}\""
	echo "`date` - DBUG: variable _pcsClusterVIP is \"${_pcsClusterVIP}\""
	echo "`date` - DBUG: variable _pcsClusterLB is \"${_pcsClusterLB}\""
	echo "`date` - DBUG: variable _pcsClusterLVM is \"${_pcsClusterLVM}\""
	echo "`date` - DBUG: variable _pcsClusterFS is \"${_pcsClusterFS}\""
	echo "`date` - DBUG: variable _pcsClusterDB is \"${_pcsClusterDB}\""
	echo "`date` - DBUG: variable _pcsClusterLsnr is \"${_pcsClusterLsnr}\""
	echo "`date` - DBUG: variable _pcsFenceName is \"${_pcsFenceName}\""
	echo "`date` - DBUG: variable _pcsVipMask is \"${_pcsVipMask}\""
	echo "`date` - DBUG: variable _vmFQDN1 is \"${_vmFQDN1}\""
	echo "`date` - DBUG: variable _vmFQDN2 is \"${_vmFQDN2}\""
	echo "`date` - DBUG: variable _vmOsDiskSize is \"${_vmOsDiskSize}\""
	echo "`date` - DBUG: variable _vmDataDiskSize is \"${_vmDataDiskSize}\""
	echo "`date` - DBUG: variable _oraVersion is \"${_oraVersion}\""
	echo "`date` - DBUG: variable _oraBase is \"${_oraBase}\""
	echo "`date` - DBUG: variable _oraHome is \"${_oraHome}\""
	echo "`date` - DBUG: variable _oraTnsDir is \"${_oraTnsDir}\""
	echo "`date` - DBUG: variable _oraInvDir is \"${_oraInvDir}\""
	echo "`date` - DBUG: variable _oraOsAcct is \"${_oraOsAcct}\""
	echo "`date` - DBUG: variable _oraOsGroup is \"${_oraOsGroup}\""
	echo "`date` - DBUG: variable _oraCharSet is \"${_oraCharSet}\""
	echo "`date` - DBUG: variable _vgName is \"${_vgName}\""
	echo "`date` - DBUG: variable _lvName is \"${_lvName}\""
	echo "`date` - DBUG: variable _oraMntDir is \"${_oraMntDir}\""
	echo "`date` - DBUG: variable _oraDataDir is \"${_oraDataDir}\""
	echo "`date` - DBUG: variable _oraFRADir is \"${_oraFRADir}\""
	echo "`date` - DBUG: variable _oraConfDir is \"${_oraConfDir}\""
	echo "`date` - DBUG: variable _oraClusterSvcAcct is \"${_oraClusterSvcAcct}\""
	echo "`date` - DBUG: variable _oraRedoSizeMB is \"${_oraRedoSizeMB}\""
fi
#
#--------------------------------------------------------------------------------
# Remove any existing logfile...
#--------------------------------------------------------------------------------
rm -f ${_logFile}
echo "`date` - INFO: \"$0 ${_progArgs}\" ${_progVersion}, starting..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Azure shared disk requires AZ CLI version 2.5.0 or above...
#--------------------------------------------------------------------------------
_azVersion="`az --version 2> /dev/null | grep '^azure-cli' | awk '{print $2}'`"
typeset -i _azVersionRelease="`echo ${_azVersion} | awk -F\. '{print $1}'`"
typeset -i _azVersionMajor="`echo ${_azVersion} | awk -F\. '{print $2}'`"
typeset -i _azVersionMinor="`echo ${_azVersion} | awk -F\. '{print $3}'`"
if (( ${_azVersionRelease} < 2 ))
then
	echo "`date` - FAIL: az CLI version is less than 2.5.0; does not support Azure shared disk" | tee -a ${_logFile}
	exit 1
else
	if (( ${_azVersionRelease} == 2 ))
	then
		if (( ${_azVersionMajor} < 5 ))
		then
			echo "`date` - FAIL: az CLI version is less than 2.5.0; does not support Azure shared disk" | tee -a ${_logFile}
			exit 1
		fi
	fi
fi
#
#--------------------------------------------------------------------------------
# Verify that the resource group exists...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az group exists -n ${_rgName}..." | tee -a ${_logFile}
if [[ "`az group exists -n ${_rgName}`" != "true" ]]; then
	echo "`date` - FAIL: resource group \"${_rgName}\" does not exist" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure subscription...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az account set subscription..." | tee -a ${_logFile}
az account set -s "${_azureSubscription}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az account set subscription" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Set the default Azure resource group and region/location...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az configure --defaults group location..." | tee -a ${_logFile}
az configure --defaults group=${_rgName} location=${_azureRegion} >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az configure --defaults group location" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# If the user elected to skip the creation of vnet, the NIC, the NSG, and the
# rules...
#--------------------------------------------------------------------------------
if [[ "${_skipVnetNicNsg}" = "false" ]]; then
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
	# Create a custom Azure network security group rule to permit SSH access...
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
	# Create a custom Azure network security group rule to permit access for
	# PCS Pacemaker/Corosync services on TCP ports 2224 (i.e. PCSD daemon),
	# 3121 (i.e. Pacemaker remote nodes), and 21064 (i.e. DLM resources)...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg rule create pcs-tcp-access..." | tee -a ${_logFile}
	az network nsg rule create \
		--name pcs-tcp-access \
		--nsg-name ${_nsgName} \
		--priority 1010 \
		--direction Inbound \
		--protocol TCP \
		--source-address-prefixes \* \
		--source-port-ranges \* \
		--destination-address-prefixes \* \
		--destination-port-ranges 2224 3121 21064 \
		--access Allow \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg rule create pcs-tcp-access" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create a custom Azure network security group rule to permit access for
	# PCS Pacemaker/Corosync services on UDP ports 5404 (i.e. Corosync
	# multicast, if enabled) and 5405 (i.e. Corosync clustering)...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nsg rule create pcs-udp-access..." | tee -a ${_logFile}
	az network nsg rule create \
		--name pcs-udp-access \
		--nsg-name ${_nsgName} \
		--priority 1020 \
		--direction Inbound \
		--protocol UDP \
		--source-address-prefixes \* \
		--source-port-ranges \* \
		--destination-address-prefixes \* \
		--destination-port-ranges 5404 5405 \
		--access Allow \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nsg rule create pcs-udp-access" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure proximity placement group for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az ppg create ${_ppgName}..." | tee -a ${_logFile}
	az ppg create \
		--name ${_ppgName} \
		--type Standard \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az ppg create ${_ppgName}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure availability set for this project...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm availability-set create ${_avSetName}..." | tee -a ${_logFile}
	az vm availability-set create \
		--name ${_avSetName} \
		--ppg ${_ppgName} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm availability-set create ${_avSetName}" | tee -a ${_logFile}
		exit 1
	fi
	#
fi
#
#--------------------------------------------------------------------------------
# If the user elected to skip the creation of virtual machines and data storage...
#--------------------------------------------------------------------------------
if [[ "${_skipMachines}" = "false" ]]; then
	#
	#------------------------------------------------------------------------
	# Create an Azure public IP address object for use with the first VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network public-ip create ${_pubIpName1}..." | tee -a ${_logFile}
	az network public-ip create \
		--name ${_pubIpName1} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--allocation-method Static \
		--sku Standard \
		--version IPv4 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network public-ip create ${_pubIpName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure network interface (NIC) object for use with the first
	# VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nic create ${_nicName1}..." | tee -a ${_logFile}
	az network nic create \
		--name ${_nicName1} \
		--vnet-name ${_vnetName} \
		--subnet ${_subnetName} \
		--network-security-group ${_nsgName} \
		--public-ip-address ${_pubIpName1} \
		--accelerated-networking TRUE \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nic create ${_nicName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create the first Azure virtual machine (VM), intended to be used as
	# the primary Oracle database server/host...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm create ${_vmName1}..." | tee -a ${_logFile}
	az vm create \
		--name ${_vmName1} \
		--image ${_vmUrn}:latest \
		--admin-username ${_azureOwner} \
		--size ${_vmInstanceType} \
		--nics ${_nicName1} \
		--ppg ${_ppgName} \
		--availability-set ${_avSetName} \
		--os-disk-name ${_vmName1}-osdisk \
		--os-disk-size-gb ${_vmOsDiskSize} \
		--os-disk-caching ReadWrite \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--generate-ssh-keys \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm create ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create a shared disk for use with the two VMs...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az disk create --max-shares 2 on ${_vmName1}..." | tee -a ${_logFile}
	az disk create --name ${_vmSharedDisk} \
		--size ${_vmDataDiskSize} \
		--max-shares 2 \
		--sku Premium_LRS \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az disk create --max-shares 2 on ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Attach the shared data disk to the first VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm disk attach to ${_vmName1}..." | tee -a ${_logFile}
	az vm disk attach \
		--name ${_vmSharedDisk} \
		--vm-name ${_vmName1} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm disk attach ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure public IP address object for use with the second VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network public-ip create ${_pubIpName2}..." | tee -a ${_logFile}
	az network public-ip create \
		--name ${_pubIpName2} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--allocation-method Static \
		--sku Standard \
		--version IPv4 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network public-ip create ${_pubIpName2}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure network interface (NIC) object for use with the second
	# VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nic create ${_nicName2}..." | tee -a ${_logFile}
	az network nic create \
		--name ${_nicName2} \
		--vnet-name ${_vnetName} \
		--subnet ${_subnetName} \
		--network-security-group ${_nsgName} \
		--public-ip-address ${_pubIpName2} \
		--accelerated-networking TRUE \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nic create ${_nicName2}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create the second Azure virtual machine (VM), intended to be used as
	# the standby Oracle database server/host...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm create ${_vmName2}..." | tee -a ${_logFile}
	az vm create \
		--name ${_vmName2} \
		--image ${_vmUrn}:latest \
		--admin-username ${_azureOwner} \
		--size ${_vmInstanceType} \
		--nics ${_nicName2} \
		--ppg ${_ppgName} \
		--availability-set ${_avSetName} \
		--os-disk-name ${_vmName2}-osdisk \
		--os-disk-size-gb ${_vmOsDiskSize} \
		--os-disk-caching ReadWrite \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--generate-ssh-keys \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm create ${_vmName2}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Attach the shared data disk to the second VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm disk attach to ${_vmName2}..." | tee -a ${_logFile}
	az vm disk attach \
		--name ${_vmSharedDisk} \
		--vm-name ${_vmName2} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm disk attach ${_vmName2}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure public IP address object for use with the third VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network public-ip create ${_pubIpName3}..." | tee -a ${_logFile}
	az network public-ip create \
		--name ${_pubIpName3} \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--allocation-method Static \
		--sku Standard \
		--version IPv4 \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network public-ip create ${_pubIpName3}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create an Azure network interface (NIC) object for use with the third
	# VM...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az network nic create ${_nicName3}..." | tee -a ${_logFile}
	az network nic create \
		--name ${_nicName3} \
		--vnet-name ${_vnetName} \
		--subnet ${_subnetName} \
		--network-security-group ${_nsgName} \
		--public-ip-address ${_pubIpName3} \
		--accelerated-networking TRUE \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az network nic create ${_nicName3}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# Create the third Azure virtual machine (VM), intended to be used as
	# an observer or node from which to launch testing of the cluster...
	#------------------------------------------------------------------------
	echo "`date` - INFO: az vm create ${_vmName3}..." | tee -a ${_logFile}
	az vm create \
		--name ${_vmName3} \
		--image ${_vmUrn}:latest \
		--admin-username ${_azureOwner} \
		--size ${_vmInstanceType} \
		--nics ${_nicName3} \
		--availability-set ${_avSetName} \
		--os-disk-name ${_vmName3}-osdisk \
		--os-disk-size-gb ${_vmOsDiskSize} \
		--os-disk-caching ReadWrite \
		--tags owner=${_azureOwner} project=${_azureProject} \
		--generate-ssh-keys \
		--verbose >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: az vm create ${_vmName3}" | tee -a ${_logFile}
		exit 1
	fi
	#
fi
#
#--------------------------------------------------------------------------------
# Obtain the public IP addresses for future use within the script...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network public-ip show ${_pubIpName1}..." | tee -a ${_logFile}
_ipAddr1=`az network public-ip show --name ${_pubIpName1} | \
	 jq '. | {ipaddr: .ipAddress}' | \
	 grep ipaddr | \
	 awk '{print $2}' | \
	 sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip show ${_pubIpName1}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: public IP ${_ipAddr1} on ${_vmName1}..." | tee -a ${_logFile}
#
echo "`date` - INFO: az network public-ip show ${_pubIpName2}..." | tee -a ${_logFile}
_ipAddr2=`az network public-ip show --name ${_pubIpName2} | \
	 jq '. | {ipaddr: .ipAddress}' | \
	 grep ipaddr | \
	 awk '{print $2}' | \
	 sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip show ${_pubIpName2}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: public IP ${_ipAddr2} on ${_vmName2}..." | tee -a ${_logFile}
#
echo "`date` - INFO: az network public-ip show ${_pubIpName3}..." | tee -a ${_logFile}
_ipAddr3=`az network public-ip show --name ${_pubIpName3} | \
	 jq '. | {ipaddr: .ipAddress}' | \
	 grep ipaddr | \
	 awk '{print $2}' | \
	 sed 's/"//g'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az network public-ip show ${_pubIpName3}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: public IP ${_ipAddr3} on ${_vmName3}..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Obtain the private/internal IP addresses for future use within the script...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az vm list-ip-addresses --name ${_vmName1}..." | tee -a ${_logFile}
_internalIpAddr1=`az vm list-ip-addresses --name ${_vmName1} --output table | tail -1 | awk '{print $3}'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm list-ip-addresses --name ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: internal IP ${_internalIpAddr1} on ${_vmName1}..." | tee -a ${_logFile}
#
echo "`date` - INFO: az vm list-ip-addresses --name ${_vmName2}..." | tee -a ${_logFile}
_internalIpAddr2=`az vm list-ip-addresses --name ${_vmName2} --output table | tail -1 | awk '{print $3}'`
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm list-ip-addresses --name ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: internal IP ${_internalIpAddr2} on ${_vmName2}..." | tee -a ${_logFile}
#
#--------------------------------------------------------------------------------
# Remove any previous entries of the IP address from the "known hosts" config
# file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: ssh-keygen to clean known hosts..." | tee -a ${_logFile}
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${_ipAddr1} >> ${_logFile} 2>&1
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${_ipAddr2} >> ${_logFile} 2>&1
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R ${_ipAddr3} >> ${_logFile} 2>&1
#
#--------------------------------------------------------------------------------
# Create an Azure load balancer to "front-end" the VIP used in the PCS cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network lb create --name ${_lbName}..." | tee -a ${_logFile}
az network lb create \
	--name ${_lbName} \
	--private-ip-address ${_pcsVipAddr} \
	--sku Standard \
	--vnet-name ${_vnetName} \
	--subnet ${_subnetName} \
	--backend-pool-name ${_lbPoolName} \
	--tags owner=${_azureOwner} project=${_azureProject} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network lb create --name ${_lbName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Add an address to the back-end address pool for the first database server VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network lb address-pool address add --name ${_lbPoolName}-01..." | tee -a ${_logFile}
az network lb address-pool address add \
	--name ${_lbPoolName}-01 \
	--pool-name ${_lbPoolName} \
	--lb-name ${_lbName} \
	--vnet ${_vnetName} \
	--ip-address=${_internalIpAddr1} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network lb address-pool address add --name ${_lbPoolName}-01" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Add an address to the back-end address pool for the second database server VM...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network lb address-pool address add --name ${_lbPoolName}-02..." | tee -a ${_logFile}
az network lb address-pool address add \
	--name ${_lbPoolName}-02 \
	--pool-name ${_lbPoolName} \
	--lb-name ${_lbName} \
	--vnet ${_vnetName} \
	--ip-address=${_internalIpAddr2} \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network lb address-pool address add --name ${_lbPoolName}-02" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a health probe for the Azure load balancer to front-end the VIP...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network lb probe create --name ${_lbProbeName}..." | tee -a ${_logFile}
az network lb probe create \
	--name ${_lbProbeName} \
	--lb-name ${_lbName} \
	--port ${_lbProbePort} \
	--protocol tcp \
	--interval 5 \
	--threshold 2 \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network lb probe create --name ${_lbProbeName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Create a health probe for the Azure load balancer to front-end the VIP...
#--------------------------------------------------------------------------------
echo "`date` - INFO: az network lb rule create --name ${_lbRuleName}..." | tee -a ${_logFile}
az network lb rule create \
	--name ${_lbRuleName} \
	--lb-name ${_lbName} \
	--backend-pool-name ${_lbPoolName} \
	--probe-name ${_lbProbeName} \
	--protocol all \
	--frontend-port 0 \
	--backend-port 0 \
	--idle-timeout 30 \
	--floating-ip true \
	--verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az network lb rule create --name ${_lbRuleName}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to copy the file "oraInst.loc" from the current Oracle
# Inventory default location into the "/etc" system directory, where it can be
# easily found by any Oracle programs accessing the host.  Set the ownership and
# permissions appropriately for the copied file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: copy oraInst.loc file on ${_vmName1}" | tee -a ${_logFile}
ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr1} "sudo cp ${_oraInvDir}/oraInst.loc /etc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo cp ${_azureOwner}@${_ipAddr1}:${_oraInvDir}/oraInst.loc /etc on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo chmod 644 /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chmod 644 /etc/oraInst.loc on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to copy the file "oraInst.loc" from the current Oracle
# Inventory default location into the "/etc" system directory, where it can be
# easily found by any Oracle programs accessing the host.  Set the ownership and
# permissions appropriately for the copied file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: copy oraInst.loc file on ${_vmName2}" | tee -a ${_logFile}
ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr2} "sudo cp ${_oraInvDir}/oraInst.loc /etc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo cp ${_azureOwner}@${_ipAddr2}:${_oraInvDir}/oraInst.loc /etc on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraOsAcct}:${_oraOsGroup} /etc/oraInst.loc on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo chmod 644 /etc/oraInst.loc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chmod 644 /etc/oraInst.loc on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#------------------------------------------------------------------------
# SSH into the first VM to determine how much physical RAM there is, then
# use the RHEL7 formula to determine needed swap space, and then configure
# the Azure Linux agent (waagent) to recreate upon boot...
#------------------------------------------------------------------------
echo "`date` - INFO: free -m to find physical RAM on ${_vmName1}..." | tee -a ${_logFile}
typeset -i _ramMB=`ssh ${_azureOwner}@${_ipAddr1} "free -m | grep '^Mem:' | awk '{print \\\$2}'" 2>&1`
if (( $? != 0 )); then
	echo "`date` - FAIL: free -m on ${_vmName1}" | tee -a ${_logFile}
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
echo "`date` - INFO: configure waagent for ${_swapMB}M swap on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo sed -i.old -e 's/^ResourceDisk.EnableSwap=n$/ResourceDisk.EnableSwap=y/' -e 's/^ResourceDisk.SwapSizeMB=0$/ResourceDisk.SwapSizeMB='${_swapMB}'/' /etc/waagent.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed /etc/waagent.conf on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: configure waagent for ${_swapMB}M swap on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo sed -i.old -e 's/^ResourceDisk.EnableSwap=n$/ResourceDisk.EnableSwap=y/' -e 's/^ResourceDisk.SwapSizeMB=0$/ResourceDisk.SwapSizeMB='${_swapMB}'/' /etc/waagent.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed /etc/waagent.conf on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
echo "`date` - INFO: configure waagent for ${_swapMB}M swap on ${_vmName3}..." | tee -a ${_logFile}
ssh -o StrictHostKeyChecking=no ${_azureOwner}@${_ipAddr3} "sudo sed -i.old -e 's/^ResourceDisk.EnableSwap=n$/ResourceDisk.EnableSwap=y/' -e 's/^ResourceDisk.SwapSizeMB=0$/ResourceDisk.SwapSizeMB='${_swapMB}'/' /etc/waagent.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed /etc/waagent.conf on ${_vmName3}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to install the LVM2 package and the "nc" (netcap) program...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum install -y lvm2 nc on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo yum install -y lvm2 nc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum install -y lvm2 nc on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to perform an update of all OS packages to be sure that
# all OS packages are up-to-date...
#--------------------------------------------------------------------------------
echo "`date` - INFO: 1st yum update -y on ${_vmName1} (be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update -y on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# ...then run an update again, because sometimes things are missed the first time
# around...
#--------------------------------------------------------------------------------
echo "`date` - INFO: 2nd yum update -y on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update -y on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to install the LVM2 package and the "nc" (netcap) program...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum install -y lvm2 nc on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo yum install -y lvm2 nc" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum install -y lvm2 nc on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to perform an update of all OS packages to be sure that
# all OS packages are up-to-date...
#--------------------------------------------------------------------------------
echo "`date` - INFO: 1st yum update -y on ${_vmName2} (be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update -y on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# ...then run an update again, because sometimes things are missed the first time
# around...
#--------------------------------------------------------------------------------
echo "`date` - INFO: 2nd yum update -y on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo yum update -y" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum update -y on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a directory mount-point for the soon-to-be-created
# filesystem in which Oracle database files will reside, and then set the OS
# account:group ownership appropriately...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir/chown ${_oraMntDir} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo mkdir ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir ${_oraMntDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo chown ${_oraOsAcct}:${_oraOsGroup} ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraMntDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to create a directory mount-point for the soon-to-be-created
# filesystem in which Oracle database files will reside, and then set the OS
# account:group ownership appropriately...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir/chown ${_oraMntDir} on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo mkdir ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir ${_oraMntDir} on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo chown ${_oraOsAcct}:${_oraOsGroup} ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraMntDir} on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to determine if Ephemeral/Temporary SSD exists under the
# "/mnt/resource" mount-point.
#
# If "/mnt/resource" is mounted upon "/dev/sdb", then Ephemeral/Temporary SSD
# exists.  If the "/mnt/resource" is mounted on "/dev/sda" or elsewhere, then
# ephemeral/temporary SSD does not exist on this VM instance type...
#--------------------------------------------------------------------------------
echo "`date` - INFO: df -h /mnt/resource on ${_vmName1}..." | tee -a ${_logFile}
_scsiDevName="sdb"
if [[ "`ssh ${_azureOwner}@${_ipAddr1} "df -h /mnt/resource | tail -1 | awk '{print $1}' | grep ${_scsiDevName}" 2>&1`" != "" ]]
then
	_scsiDevName="sdc"
fi
_scsiDev="/dev/${_scsiDevName}"
_pvName="${_scsiDev}1"
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a volume label on the shared disk...
# 
# If the shared disk is less than 2 TB in size, then use "msdos" volume label,
# but if it is larger, then we must use "GPT" volume label format...
#--------------------------------------------------------------------------------
echo "`date` - INFO: parted ${_scsiDev} mklabel gpt on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo parted ${_scsiDev} mklabel gpt" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo parted ${_scsiDev} mklabel gpt on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a single primary partitition consuming the
# entire shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: sudo parted -a opt ${_scsiDev} mkpart primary ${_fsType} 0% 100%..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo parted -a opt ${_scsiDev} mkpart primary ${_fsType} 0% 100%" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo parted mkpart -a opt ${_scsiDev} primary ${_fsType} 0% 100% on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a "physical volume" from the primary SCSI
# partition on the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pvcreate ${_pvName} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pvcreate ${_pvName}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pvcreate ${_pvName} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a "volume group" consisting of the single
# "physical volume" from the primary SCSI partition on the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: vgcreate ${_vgName} ${_pvName} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo vgcreate ${_vgName} ${_pvName}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo vgcreate ${_vgName} ${_pvName} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a "logical volume" on the "volume group" of
# the shared disk...
#--------------------------------------------------------------------------------
typeset -i _vmDataDiskMB=${_vmDataDiskSize}*1024
typeset -i _vmDataDiskMB=${_vmDataDiskMB}-4
echo "`date` - INFO: lvcreate -n ${_lvName} -L ${_vmDataDiskMB}m ${_vgName} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo lvcreate -n ${_lvName} -L ${_vmDataDiskMB}m ${_vgName}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo lvcreate -n ${_lvName} -L ${_vmDataDiskMB}m ${_vgName} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create an EXT4 filesystem on the "logical volume" on
# the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkfs.${_fsType} /dev/${_vgName}/${_lvName} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo mkfs.${_fsType} /dev/${_vgName}/${_lvName}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkfs.${_fsType} /dev/${_vgName}/${_lvName} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to mount the newly-created filesystem on the shared disk
# onto the newly-created directory mount-point...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo mount /dev/${_vgName}/${_lvName} ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mount /dev/${_vgName}/${_lvName} ${_oraMntDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create sub-directories for the Oracle database files
# and for the Oracle Flash Recovery Area (FRA) files, then set OS account:group
# ownership...
#--------------------------------------------------------------------------------
echo "`date` - INFO: mkdir/chown ${_oraDataDir} ${_oraFRADir} ${_oraConfDir} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo mkdir -p ${_oraDataDir} ${_oraFRADir} ${_oraConfDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo mkdir ${_oraDataDir} ${_oraFRADir} ${_oraConfDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo chown ${_oraOsAcct}:${_oraOsGroup} ${_oraDataDir} ${_oraFRADir} ${_oraConfDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo chown ${_oraDataDir} ${_oraFRADir} ${_oraConfDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to run the Oracle Database Creation Assistant (DBCA)
# program to create a new primary Oracle database...
#--------------------------------------------------------------------------------
echo "`date` - INFO: dbca -createDatabase ${_oraSid} on ${_vmName1} (be prepared - long wait)..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"\
	dbca -silent -createDatabase \
		-gdbName ${_oraSid} \
		-templateName ${_oraHome}/assistants/dbca/templates/General_Purpose.dbc \
		-sid ${_oraSid} \
		-sysPassword ${_oraSysPwd} \
		-systemPassword ${_oraSysPwd} \
		-characterSet ${_oraCharSet} \
		-createListener ${_oraLsnr}:${_oraLsnrPort} \
		-storageType FS \
		-datafileDestination ${_oraDataDir} \
		-enableArchive TRUE \
		-memoryMgmtType AUTO_SGA \
		-memoryPercentage 70 \
		-recoveryAreaDestination ${_oraFRADir} \
		-recoveryAreaSize 40960 \
		-redoLogFileSize ${_oraRedoSizeMB}\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: dbca -createDatabase ${_oraSid} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create the service account for PCS in the Oracle database...
#--------------------------------------------------------------------------------
echo "`date` - INFO: create database service account for Pacemaker/Corosync from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
sqlplus -S / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
create user ${_oraClusterSvcAcct} identified by ${_oraSysPwd};
grant create session to ${_oraClusterSvcAcct};
grant alter session to ${_oraClusterSvcAcct};
grant connect to ${_oraClusterSvcAcct};
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: create database service account for Pacemaker/Corosync on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to shutdown the Oracle database instance...
#--------------------------------------------------------------------------------
echo "`date` - INFO: shutdown immediate ${_oraSid} from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"
export ORACLE_SID=${_oraSid}
sqlplus -S / as sysdba << __EOF__
whenever oserror exit failure
whenever sqlerror exit failure
shutdown immediate
exit success
__EOF__\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: shutdown immediate ${_oraSid} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to stop the Oracle listener service...
#--------------------------------------------------------------------------------
echo "`date` - INFO: lsnrctl stop ${_oraLsnr} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"lsnrctl stop ${_oraLsnr}\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: lsnrctl stop ${_oraLsnr} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to move the Oracle database instance's password file
# (i.e. "orapw${ORACLE_SID}") and the parameter initialization file (i.e.
# "spfile${ORACLE_SID}.ora") to a subdirectory on the shared disk, then create
# symbolic (soft) links for each file so that it appears that both files are
# in their original locations...
#--------------------------------------------------------------------------------
echo "`date` - INFO: move/symlink PWDFILE and SPFILE to ${_oraConfDir} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"mv ${_oraHome}/dbs/orapw${_oraSid} ${_oraHome}/dbs/spfile${_oraSid}.ora ${_oraConfDir}\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"mv ${_oraHome}/dbs/orapw${_oraSid} ${_oraHome}/dbs/spfile${_oraSid}.ora ${_oraConfDir}\" on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/orapw${_oraSid} ${_oraHome}/dbs\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"ln -s ${_oraConfDir}/orapw${_oraSid} ${_oraHome}/dbs\" on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/spfile${_oraSid}.ora ${_oraHome}/dbs\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"ln -s ${_oraConfDir}/spfile${_oraSid}.ora ${_oraHome}/dbs\" on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to create symbolic (soft) links for the password file
# and the server parameter (spfile).  Even though the shared disk is not yet
# mounted, the symbolic links will be ready when it is...
#--------------------------------------------------------------------------------
echo "`date` - INFO: symlink PWDFILE and SPFILE to ${_oraConfDir} on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/orapw${_oraSid} ${_oraHome}/dbs\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"ln -s ${_oraConfDir}/orapw${_oraSid} ${_oraHome}/dbs\" on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/spfile${_oraSid}.ora ${_oraHome}/dbs\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"ln -s ${_oraConfDir}/spfile${_oraSid}.ora ${_oraHome}/dbs\" on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Perform the same three steps for each of the three Oracle TNS configuration
# files which are (by default) located in the "$ORACLE_HOME/network/admin"
# sub-directory on local (non-shared) disk...
#--------------------------------------------------------------------------------
for _fName in sqlnet.ora tnsnames.ora listener.ora
do
	#
	#------------------------------------------------------------------------
	# SSH into the first VM to edit the Oracle TNS configuration file to
	# change the fully-qualified domain name of the first VM to the IP address
	# of the PCS cluster virtual IP...
	#------------------------------------------------------------------------
	echo "`date` - INFO: edit ${_oraTnsDir}/${_fName} on ${_vmName1}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"sed -i s/${_vmFQDN1}/${_pcsVipAddr}/ ${_oraTnsDir}/${_fName}\"" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: \"sed -i s/${_vmFQDN1}/${_pcsVipAddr}/ ${_oraTnsDir}/${_fName}\" on ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# SSH into the first VM to move the Oracle TNS configuration file to a
	# subdirectory on the shared disk, so that it will be accessible from
	# whichever node is active.  Then create a symbolic (soft) link so that
	# it appears to the database instance and other applications that the
	# file is still in its original location...
	#------------------------------------------------------------------------
	echo "`date` - INFO: move/link \"${_fName}\" to ${_oraConfDir} on ${_vmName1}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"mv ${_oraTnsDir}/${_fName} ${_oraConfDir}\"" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: \"mv ${_oraTnsDir}/${_fName} ${_oraConfDir}\" on ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	ssh ${_azureOwner}@${_ipAddr1} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/${_fName} ${_oraTnsDir}\"" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: \"ln -s ${_oraConfDir}/${_fName} ${_oraTnsDir}\" on ${_vmName1}" | tee -a ${_logFile}
		exit 1
	fi
	#
	#------------------------------------------------------------------------
	# SSH into the second VM to create a symbolic (soft) link for the Oracle
	# TNS configuration file, so that when the shared disk is attached to
	# this host/node, the symlink will point at the file in the shared
	# location...
	#
	# Please note: the shared disk need not be mounted for a symlink to be
	# created...
	#------------------------------------------------------------------------
	echo "`date` - INFO: symlink \"${_fName}\" to ${_oraConfDir} on ${_vmName2}..." | tee -a ${_logFile}
	ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"ln -s ${_oraConfDir}/${_fName} ${_oraTnsDir}\"" >> ${_logFile} 2>&1
	if (( $? != 0 )); then
		echo "`date` - FAIL: \"ln -s ${_oraConfDir}/${_fName} ${_oraTnsDir}\" on ${_vmName2}" | tee -a ${_logFile}
		exit 1
	fi
	#
done
#
#--------------------------------------------------------------------------------
# SSH into the second VM to create an entry for the Oracle database in the
# "/etc/oratab" ccnfiguration file...
#--------------------------------------------------------------------------------
echo "`date` - INFO: create entry in /etc/oratab on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"echo ${_oraSid}:${_oraHome}:N >> /etc/oratab\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"echo ${_oraSid}:${_oraHome}:N >> /etc/oratab\" on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to create the subdirectories needed "audit" and DataPump
# files for the Oracle database instance, the former based on the default value
# of the AUDIT_FILE_DEST parameter value...
#--------------------------------------------------------------------------------
echo "`date` - INFO: create adump and dpdump subdirectories on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"mkdir -p ${_oraBase}/admin/${_oraSid}/adump\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"mkdir -p ${_oraBase}/admin/${_oraSid}/adump\" on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo su - ${_oraOsAcct} -c \"mkdir -p ${_oraBase}/admin/${_oraSid}/dpdump\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: \"mkdir -p ${_oraBase}/admin/${_oraSid}/dpdump\" on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to unmount the filesystem on the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: umount ${_oraMntDir} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo umount ${_oraMntDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo umount ${_oraMntDir} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to install the PCS module to create and manage the
# cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum install -y pcs resource-agents fence-agents-all on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo yum install -y pcs resource-agents fence-agents-all" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum install -y pcs resource-agents fence-agents-all on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to start the "pcsd" service...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl start pcsd.service on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl start pcsd.service" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl start pcsd.service on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to enable the "pcsd" service for automatic start after
# reboot...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl enable pcsd.service on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl enable pcsd.service" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl enable pcsd.service on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set a password for the HA cluster OS account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: set ${_pcsClusterUser} password on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "echo ${_oraSysPwd} | sudo passwd --stdin ${_pcsClusterUser}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo passwd ${_pcsClusterUser} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to disable firewall services...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl stop/disable firewalld on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl stop firewalld" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl stop firewalld on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl disable firewalld" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl disable firewalld on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to open up firewall ports for HA services, Oracle TNS
# port 1521, and the PCS azure-lb port 62503...
#--------------------------------------------------------------------------------
#echo "`date` - INFO: systemctl start/enable firewalld on ${_vmName1}..." | tee -a ${_logFile}
#ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl start firewalld" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo systemctl start firewalld on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl enable firewalld" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo systemctl enable firewalld on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#echo "`date` - INFO: firewall-cmd --add-service=high-availability from ${_vmName1}..." | tee -a ${_logFile}
#ssh ${_azureOwner}@${_ipAddr1} "sudo firewall-cmd --add-service=high-availability --permanent" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-service=high-availability --permanent on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr1} "sudo firewall-cmd --add-service=high-availability" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-service=high-availability on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr1} "sudo firewall-cmd --add-port=1521/tcp" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-port=1521/tcp on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr1} "sudo firewall-cmd --add-port=62503/tcp" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-port=62503/tcp on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to install the PCS module to create and manage the
# cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: yum install -y pcs resource-agents fence-agents-all on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo yum install -y pcs resource-agents fence-agents-all" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo yum install -y pcs resource-agents fence-agents-all on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to start the "pcsd" service...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl start pcsd.service on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo systemctl start pcsd.service" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl start pcsd.service on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to enable the "pcsd" service for automatic restart after
# reboot...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl enable pcsd.service on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo systemctl enable pcsd.service" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl enable pcsd.service on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to set a password for the HA cluster OS account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: set ${_pcsClusterUser} password on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "echo ${_oraSysPwd} | sudo passwd --stdin ${_pcsClusterUser}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo passwd ${_pcsClusterUser} on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to open up firewall ports for HA services, Oracle TNS
# port 1521, and the PCS azure-lb port 62503...
#--------------------------------------------------------------------------------
echo "`date` - INFO: systemctl stop/disable firewalld on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo systemctl stop firewalld" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl stop firewalld on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo systemctl disable firewalld" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo systemctl disable firewalld on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to set up firewall ports for HA services...
#--------------------------------------------------------------------------------
#echo "`date` - INFO: systemctl start/enable firewalld on ${_vmName1}..." | tee -a ${_logFile}
#ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl start firewalld" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo systemctl start firewalld on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr1} "sudo systemctl enable firewalld" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo systemctl enable firewalld on ${_vmName1}" | tee -a ${_logFile}
#	exit 1
#fi
#echo "`date` - INFO: firewall-cmd --add-service=high-availability from ${_vmName2}..." | tee -a ${_logFile}
#ssh ${_azureOwner}@${_ipAddr2} "sudo firewall-cmd --add-service=high-availability --permanent" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-service=high-availability --permanent on ${_vmName2}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr2} "sudo firewall-cmd --add-service=high-availability" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-service=high-availability on ${_vmName2}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr2} "sudo firewall-cmd --add-port=1521/tcp" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-port=1521/tcp on ${_vmName2}" | tee -a ${_logFile}
#	exit 1
#fi
#ssh ${_azureOwner}@${_ipAddr2} "sudo firewall-cmd --add-port=62503/tcp" >> ${_logFile} 2>&1
#if (( $? != 0 )); then
#	echo "`date` - FAIL: sudo firewall-cmd --add-port=62503/tcp on ${_vmName2}" | tee -a ${_logFile}
#	exit 1
#fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set up authentication on the nodes of the PCS cluster
# using the PCS cluster OS account...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs cluster auth from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs cluster auth ${_vmFQDN1} ${_vmFQDN2} -u ${_pcsClusterUser} -p ${_oraSysPwd}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs cluster auth ${_vmFQDN1} ${_vmFQDN2} -u ${_pcsClusterUser} -p XXX on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to setup the new PCS cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs cluster setup --wait_for_all=0 --name ${_pcsClusterName} from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs cluster setup --wait_for_all=0 --name ${_pcsClusterName} ${_vmFQDN1} ${_vmFQDN2}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs cluster setup --wait_for_all=0 --name ${_pcsClusterName} ${_vmFQDN1} ${_vmFQDN2} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to start all the nodes in the PCS cluster.  The "--all"
# qualifier does this for all nodes in the cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs cluster start --all from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs cluster start --all" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs cluster start --all on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to ignore the default policy requiring a quorum...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs property set no-quorum-policy=ignore from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs property set no-quorum-policy=ignore" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs property set no-quorum-policy=ignore on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to enable STONITH fencing in the cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs property set stonith-enabled=true from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs property set stonith-enabled=true" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs property set stonith-enabled=true on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set the failover (migration) threshold to one node...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource defaults migration-threshold=1 from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource defaults migration-threshold=1" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource defaults migration-threshold=1 on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to set the default "stickiness" of resources to indicate
# that healthy resources should not be moved. We do not want PCS moving resources
# unless there is a failure or a command to do so...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource defaults resource-stickiness=100 from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource defaults resource-stickiness=100" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource defaults resource-stickiness=100 on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to enable the PCS cluster for automatic restart when the
# node restarts.  The "--all" qualifier does this for all nodes in the cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs cluster enable --all from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs cluster enable --all" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs cluster enable --all on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to disable the "lvmetad" subsystem, which might contend
# with Pacemaker for control of LVM resources.  Finish by editing the
# "/etc/lvm/lvm.conf" configuration file and rebooting the host...
#--------------------------------------------------------------------------------
echo "`date` - INFO: disabling lvmetad then rebooting ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo lvmconf --enable-halvm --services --startstopservices" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo lvmconf --enable-halvm --services --startstopservices on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
if [[ "`ssh ${_azureOwner}@${_ipAddr1} 'ps -eaf | grep lvmetad | grep -v grep'`" != "" ]]; then
	echo "`date` - FAIL: lvmetad is still running on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo sed -i 's/# volume_list = \[/volume_list = [] ###[/' /etc/lvm/lvm.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed -i 's/# volume_list = [/volume_list = [] ###[/' /etc/lvm/lvm.conf on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr1} "sudo dracut -H -f /boot/initramfs-\$(uname -r).img \$(uname -r)" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo dracut -H -f /boot/initramfs-\$(uname -r).img \$(uname -r) on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
az vm restart --name ${_vmName1} --verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm restart --name ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the second VM to disable the "lvmetad" subsystem, which might contend
# with Pacemaker for control of LVM resources.  Finish by editing the
# "/etc/lvm/lvm.conf" configuration file and rebooting the host...
#--------------------------------------------------------------------------------
echo "`date` - INFO: disabling lvmetad then rebooting ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo lvmconf --enable-halvm --services --startstopservices" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo lvmconf --enable-halvm --services --startstopservices on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
if [[ "`ssh ${_azureOwner}@${_ipAddr2} 'ps -eaf | grep lvmetad | grep -v grep'`" != "" ]]; then
	echo "`date` - FAIL: lvmetad is still running on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed -i 's/use_lvmetad = 1/use_lvmetad = 0/' /etc/lvm/lvm.conf on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo sed -i 's/# volume_list = \[/volume_list = [] ###[/' /etc/lvm/lvm.conf" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo sed -i 's/# volume_list = [/volume_list = [] ###[/' /etc/lvm/lvm.conf on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
ssh ${_azureOwner}@${_ipAddr2} "sudo dracut -H -f /boot/initramfs-\$(uname -r).img \$(uname -r)" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo dracut -H -f /boot/initramfs-\$(uname -r).img \$(uname -r) on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
az vm restart --name ${_vmName2} --verbose >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: az vm restart --name ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Find the underlying block ID for the SCSI device...
#--------------------------------------------------------------------------------
_devById=`ssh ${_azureOwner}@${_ipAddr1} "ls -l /dev/disk/by-id" | grep "/${_scsiDevName}$" | grep "wwn-" | awk '{print $9}'`
if [[ "${_devById}" = "" ]]
then
	echo "`date` - FAIL: \"/dev/disk/by-id\" entry for \"${_scsiDevName}\" not found on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
_devByIdPath="/dev/disk/by-id/${_devById}"
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a storage-based STONITH device on the shared
# SCSI device...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs stonith create ${_pcsFenceName} devices=${_devByIdPath} from ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs stonith create \
	${_pcsFenceName} fence_scsi \
	devices=${_devByIdPath} \
	pcmk_host_list=\"${_vmFQDN1} ${_vmFQDN2}\" \
	pcmk_monitor_action=metadata \
	pcmk_reboot_action=off \
	meta provides=unfencing \
	--group=${_pcsClusterGroup}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs stonith create ${_pcsFenceName} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the virtual IP address...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterVIP} ocf:heartbeat:IPaddr2 ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterVIP} \
	ocf:heartbeat:IPaddr2 \
	--group=${_pcsClusterGroup} \
	ip=${_pcsVipAddr} \
	cidr_netmask=${_pcsVipMask} \
	nic=eth0 \
	op monitor interval=10s" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterVIP} IPaddr2 at ${_pcsVipAddr} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the Azure load balancer...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterLB} ocf:heartbeat:azure-lb ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterLB} \
	ocf:heartbeat:azure-lb \
	--group=${_pcsClusterGroup} \
	port=${_lbProbePort}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterLB} azure-lb at ${_lbProbePort} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the volume group
# consisting of the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterLVM} ocf:heartbeat:LVM volgrpname=${_vgName} on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterLVM} \
	ocf:heartbeat:LVM \
	--group=${_pcsClusterGroup} \
	volgrpname=${_vgName} \
	exclusive=true" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterLVM} LVM on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the EXT4 filesystem on
# the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterFS} ocf:heartbeat:Filesystem on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterFS} \
	ocf:heartbeat:Filesystem \
	--group=${_pcsClusterGroup} \
	device=\"/dev/${_vgName}/${_lvName}\" \
	directory=\"${_oraMntDir}\" \
	fstype=\"${_fsType}\"" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterFS} Filesystem on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the Oracle TNS Listener...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterLsnr} oralsnr sid=${_oraSid} --group=${_pcsClusterGroup}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterLsnr} \
	ocf:heartbeat:oralsnr \
	--group=${_pcsClusterGroup} \
	sid=${_oraSid} \
	user=${_oraOsAcct} \
	home=${_oraHome} \
	listener=${_oraLsnr} \
	tns_admin=${_oraTnsDir}" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterLsnr} ocf:heartbeat:oralsnr --group=${_pcsClusterGroup} sid=${_oraSid} home=${_oraHome} listener=${_oraLsnr} tns_admin=${_oraTnsDir}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to create a cluster resource for the Oracle database
# instance on the shared disk...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pcs resource create ${_pcsClusterDB} oracle sid=${_oraSid} --group=${_pcsClusterGroup}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo pcs resource create \
	${_pcsClusterDB} \
	ocf:heartbeat:oracle \
	--group=${_pcsClusterGroup} \
	sid=${_oraSid} \
	home=${_oraHome} \
	user=${_oraOsAcct} \
	monuser=${_oraClusterSvcAcct} \
	monpassword=${_oraSysPwd} \
	monprofile=default \
	ipcrm=instance \
	shutdown_method=checkpoint/abort" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: sudo pcs resource create ${_pcsClusterDB} ocf:heartbeat:oracle sid=${_oraSid} --group=${_pcsClusterGroup} on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Pause for 30 seconds before running verbose "live check" on both nodes...
#--------------------------------------------------------------------------------
echo "`date` - INFO: pause for 30 seconds..." | tee -a ${_logFile}
sleep 30
#
#--------------------------------------------------------------------------------
# SSH into the first VM to perform a verbose "live check" of the validity of the
# configuration of the PCS cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: crm_verify --live-check --verbose on ${_vmName1}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr1} "sudo crm_verify --live-check --verbose" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: crm_verify --live-check --verbose on ${_vmName1}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# SSH into the first VM to perform a verbose "live check" of the validity of the
# configuration of the PCS cluster...
#--------------------------------------------------------------------------------
echo "`date` - INFO: crm_verify --live-check --verbose on ${_vmName2}..." | tee -a ${_logFile}
ssh ${_azureOwner}@${_ipAddr2} "sudo crm_verify --live-check --verbose" >> ${_logFile} 2>&1
if (( $? != 0 )); then
	echo "`date` - FAIL: crm_verify --live-check --verbose on ${_vmName2}" | tee -a ${_logFile}
	exit 1
fi
#
#--------------------------------------------------------------------------------
# Successful completion and exit with success status...
#--------------------------------------------------------------------------------
echo "`date` - INFO: successful completion" | tee -a ${_logFile}
exit 0
