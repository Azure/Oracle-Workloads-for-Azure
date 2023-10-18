[CmdletBinding()]
Param(
    [Parameter()]
    [Alias("h")]
    [switch]$Help,

    [Parameter(mandatory=$false)]
    [string]$SourceFolder=".\",

    [Parameter(mandatory=$false)]
    [string]$OutputFile="",

    [Parameter(mandatory=$false)]
    [string]$AzureRegion="westus",

    [Parameter(mandatory=$false)]
    [string]$TemplateFileName="template.xlsm",

    [Parameter()]
    [switch]$NoAwr

    )
        
    
######################################### Utility Functions #########################################
function FirstLineOffset {
    param (
        $htmlTable
    )
    $headerOffset=0
    :rowLoop for($i=0;$i -lt $htmlTable.rows.length;$i++)
    {
        $headerTagFound=$false
        :cellLoop for($j=0;$j -lt $htmlTable.rows[$i].cells.length;$j++)
        {
            if($htmlTable.rows[$i].cells[$j].tagName -ieq "TH") 
            {
                $headerTagFound=$true
                break cellLoop
            }
        }
        if ($headerTagFound -eq $false)
        {
            $headerOffset=$i
            break rowLoop
        }
    }
    return $headerOffset
}
function ConvertNumberOrDefault {
    param (
        [string]$textToConvert,
        [decimal]$defaultValue
    )
    [decimal]$parsedNumber=0
    [bool]$result=[decimal]::TryParse($textToConvert, [ref]$parsedNumber)
    if($result -eq $true)
    {
        return $parsedNumber
    }
    else {
        return $defaultValue
    }
    
}

function ResetTable([object]$listObject){
    while ($listObject.ListRows.Count -gt 0)
    {
        $listObject.ListRows.Item(1).Range.EntireRow.Delete() | Out-Null
    }
}

function AppendRow([object]$listObject){
    #$listObject.ListRows.Item($listObject.ListRows.Count).Range.Offset(1).EntireRow.Insert() | Out-Null
    #if($listObject.ShowTotals -eq $False){$listObject.Resize($listObject.Range.Resize($listObject.Range.CurrentRegion.Rows.Count))}
    if ($null -eq $listObject.InsertRowRange) 
    {
        $listObject.ListRows.Item($listObject.ListRows.Count).Range.Offset(1).EntireRow.Insert() | Out-Null
    }
    else {
        $listObject.InsertRowRange.Cells(1) = " "
    }
}

function ParseSkuSizeString([string]$size){
	$allmatches=$global:azureSizeStringRegex.Matches($size)
    $objectProps=[ordered]@{
        Size                = $size
        Family 		        = $allmatches.Groups[1].Value
        Subfamily 		    = $allmatches.Groups[2].Value
        vCpus  	            = $allmatches.Groups[3].Value
        ConstrainedvCpus    = $allmatches.Groups[4].Value
        Capabilities 	    = $allmatches.Groups[5].Value.ToLower()
        AMDProcessor        = $allmatches.Groups[5].Value.ToLower().Contains('a')
        BlockStoragePerformance = $allmatches.Groups[5].Value.ToLower().Contains('b')
        Diskful             = $allmatches.Groups[5].Value.ToLower().Contains('d')
        IsolatedSize        = $allmatches.Groups[5].Value.ToLower().Contains('i')
        LowMemory           = $allmatches.Groups[5].Value.ToLower().Contains('l')
        MemoryIntensive     = $allmatches.Groups[5].Value.ToLower().Contains('m')
        ARMProcessor        = $allmatches.Groups[5].Value.ToLower().Contains('p')
        TinyMemory          = $allmatches.Groups[5].Value.ToLower().Contains('t')
        PremiumStorage      = $allmatches.Groups[5].Value.ToLower().Contains('s')
        AcceleratorType     = $allmatches.Groups[6].Value
        Version			    = $allmatches.Groups[7].Value
        Promo			    = $allmatches.Groups[8].Value
        } 

        $obj = New-Object -TypeName PSCustomObject -Property $objectProps

        if($obj.ConstrainedvCpus.StartsWith("-"))
        {
            $obj.ConstrainedvCpus=$obj.ConstrainedvCpus.Substring(1)
        }

        if($obj.Version.StartsWith("_"))
        {
            $obj.Version=$obj.Version.Substring(1)
        }
	return $obj
}

function ParseAWR_Normal([object]$html, [string]$awrReportFileName){
    #first find the release
    $firstTable=$html.body.getElementsByTagName('table')[0]
    $releaseNumber=""
    if($firstTable)
    {
        for($i=0;$i -lt $firstTable.rows[0].cells.Length;$i++)
        {
            if($firstTable.rows[0].cells[$i].InnerText -ieq "Release")
            {
                $releaseNumber=$firstTable.rows[1].cells[$i].InnerText
            }
        }
    } 

    if([string]::IsNullOrEmpty($releaseNumber))
    {
        throw "Release number cannot be found while processing file `"$awrReportFileName`""
    }

    $objectProps=[ordered]@{
        InstanceIndex=0 
        Release      =$releaseNumber 
        DBName       =""
        InstanceName =""
        HostName     =""
        ElapsedTime  =0
        DBTime       =0
        DBCPU        =0
        CPUs         =0
        Cores        =0
        Memory       =0
        BusyCPU      =0
        SGAUse       =0
        PGAUse       =0
        ReadThroughput  =0
        WriteThroughput =0
        ReadIOPS        =0
        WriteIOPS       =0
        TotalThroughput =0
        TotalIOPS       =0
        CPUTotalCapacity=0
        ORAUse          =0
        SourceCPUHTFactor=0
        AverageActiveSessions=0
        AWRReportFileName=$awrReportFileName
        ReportType="Normal"
    }
    $awrObj=New-Object -TypeName PSCustomObject -Property $objectProps #this is to provide ordered list of object properties

    if($releaseNumber -like "10*")
    {
        $tables=$html.body.getElementsByTagName('table')
        $awrObj.InstanceIndex=$tables[0].rows[1].cells[3].InnerText
        $awrObj.DBName       =$tables[0].rows[1].cells[0].InnerText
        $awrObj.InstanceName =$tables[0].rows[1].cells[2].InnerText
        $awrObj.HostName     =$tables[0].rows[1].cells[6].InnerText

        $tblSnapshot = $tables[1]
        if ($tblSnapshot)
        {
            $offset=FirstLineOffset($tblSnapshot)
    
            for($i=0;$i -lt $tblSnapshot.rows.Length-1;$i++)
            {
                if($tblSnapshot.rows[$i+$offset].cells[0].InnerText -like "Elapsed*")
                {
                    $awrObj.ElapsedTime= ConvertNumberOrDefault ($tblSnapshot.rows[$i+$offset].cells[2].InnerText -replace "[^\d*\,?\.?\d*$/]",'') 0 
                }
                elseif($tblSnapshot.rows[$i+$offset].cells[0].InnerText -like "DB Time*")
                {
                    $awrObj.DBTime= ConvertNumberOrDefault ($tblSnapshot.rows[$i+$offset].cells[2].InnerText -replace "[^\d*\,?\.?\d*$/]",'') 0 
                }
            }
        }
        else {
            Write-Host "HTML table cannot be found (First table) while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblTimeModel=$html.body.getElementsByTagName('table') | Where-Object {
            $cells = $_.tBodies[0].rows[0].cells
            $cells[0].innerText -eq "Statistic Name" -and
            $cells[1].innerText -eq "Time (s)" -and
            $cells[2].innerText -eq "% of DB Time" -and 
            $cells.Length -eq 3
        }
        if ($tblTimeModel)
        {
            $offset=FirstLineOffset($tblTimeModel)
    
            for($i=0;$i -lt $tblTimeModel.rows.Length-1;$i++)
            {
                if($tblTimeModel.rows[$i+$offset].cells[0].InnerText -ieq "DB CPU")
                {
                $awrObj.DBCPU=ConvertNumberOrDefault $tblTimeModel.rows[$i+$offset].cells[1].InnerText 0 
                }
            }
        }
        else {
            Write-Host "HTML table cannot be found (Headers: Statistic Name,Time (s),% of DB Time) while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblOSStats=$html.body.getElementsByTagName('table') | Where-Object {
            $cells = $_.tBodies[0].rows[0].cells
            $cells[0].innerText -eq "Statistic" -and
            $cells[1].innerText -eq "Total" -and 
            $cells.Length -eq 2
        }

        if ($tblOSStats)
        {
            $offset=FirstLineOffset($tblOSStats)

            $busyTime=0
            $idleTime=0
            $userTime=0
            for($i=0;$i -lt $tblOSStats.rows.Length-1;$i++)
            {
                if($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "PHYSICAL_MEMORY_BYTES")
                {
                    $awrObj.Memory= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                    $awrObj.Memory/=1024*1024*1024
                }
                elseif($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "NUM_CPUS")
                {
                    $awrObj.Cores= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                }
                elseif($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "NUM_CPU_SOCKETS")
                {
                    $awrObj.CPUs= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                }
                elseif($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "BUSY_TIME")
                {
                    $busyTime= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                }
                elseif($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "IDLE_TIME")
                {
                    $idleTime= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                }
                elseif($tblOSStats.rows[$i+$offset].cells[0].InnerText -like "USER_TIME")
                {
                    $userTime= ConvertNumberOrDefault $tblOSStats.rows[$i+$offset].cells[1].InnerText 0
                }

                if($busyTime -gt 0 -and $idleTime -gt 0 -and $userTime -gt 0)
                {
                    $awrObj.BusyCPU=$userTime/($busyTime+$idleTime)
                }
                
            }
        }
        else{
            Write-Host "HTML table cannot be found (Headers: Statistic,Total) while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblInitOraParameters=$html.body.getElementsByTagName('table') | Where-Object {
            $cells = $_.tBodies[0].rows[0].cells
            $cells[0].innerText -eq "Parameter Name" -and
            $cells[1].innerText -eq "Begin value" -and
            $cells[2].innerText -eq "End value (if different)" -and 
            $cells.Length -eq 3
        }

        if ($tblInitOraParameters)
        {
            $offset=FirstLineOffset($tblInitOraParameters)

            for($i=0;$i -lt $tblInitOraParameters.rows.Length-1;$i++)
            {
                if($tblInitOraParameters.rows[$i+$offset].cells[0].InnerText -like "pga_aggregate_target")
                {
                    $awrObj.PGAUse= ConvertNumberOrDefault $tblInitOraParameters.rows[$i+$offset].cells[1].InnerText 0
                    $awrObj.PGAUse/=1024*1024
                }
                elseif($tblInitOraParameters.rows[$i+$offset].cells[0].InnerText -like "sga_target")
                {
                    $awrObj.SGAuse= ConvertNumberOrDefault $tblInitOraParameters.rows[$i+$offset].cells[1].InnerText 0
                    $awrObj.SGAuse/=1024*1024
                }
                
            }
        }
        else{
            Write-Host "HTML table cannot be found (Headers: Parameter Name,Begin value,End value (if different)) while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblInstanceActivityStats=$html.body.getElementsByTagName('table') | Where-Object {
            $cells = $_.tBodies[0].rows[0].cells
            $cells[0].innerText -eq "Statistic" -and
            $cells[1].innerText -eq "Total" -and
            $cells[2].innerText -eq "per Second" -and
            $cells[3].innerText -eq "per Trans" -and 
            $cells.Length -eq 4
            
        }

        if ($tblInstanceActivityStats)
        {
            $offset=FirstLineOffset($tblInstanceActivityStats)

            for($i=0;$i -lt $tblInstanceActivityStats.rows.Length-1;$i++)
            {
                if($tblInstanceActivityStats.rows[$i+$offset].cells[0].InnerText -like "physical read bytes")
                {
                    $awrObj.ReadThroughput= ConvertNumberOrDefault $tblInstanceActivityStats.rows[$i+$offset].cells[2].InnerText 0
                    $awrObj.ReadThroughput/=1024*1024
                }
                elseif($tblInstanceActivityStats.rows[$i+$offset].cells[0].InnerText -like "physical read IO requests")
                {
                    $awrObj.ReadIOPS= ConvertNumberOrDefault $tblInstanceActivityStats.rows[$i+$offset].cells[2].InnerText 0
                }
                elseif($tblInstanceActivityStats.rows[$i+$offset].cells[0].InnerText -like "physical write bytes")
                {
                    $awrObj.WriteThroughput= ConvertNumberOrDefault $tblInstanceActivityStats.rows[$i+$offset].cells[2].InnerText 0
                    $awrObj.WriteThroughput/=1024*1024
                }
                elseif($tblInstanceActivityStats.rows[$i+$offset].cells[0].InnerText -like "physical write IO requests")
                {
                    $awrObj.WriteIOPS= ConvertNumberOrDefault $tblInstanceActivityStats.rows[$i+$offset].cells[2].InnerText 0
                }
                
            }
        }
        else{
            Write-Host "HTML table cannot be found (Headers: Statistic,Total,per Second,per Trans) while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }
    }
    elseif(($releaseNumber -like "1*") -or ($releaseNumber -like "2*"))
    {
        $tblDBInstance=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*database instance information'} 

        if ($tblDBInstance)
        {
            if(($releaseNumber -like "11*") -or ($releaseNumber -like "12.1*"))
            {
                $awrObj.DBName       =$tblDBInstance.rows[1].cells[0].InnerText
                $awrObj.InstanceName =$tblDBInstance.rows[1].cells[2].InnerText
                $awrObj.InstanceIndex=$tblDBInstance.rows[1].cells[3].InnerText
            }
            else
            {
                $awrObj.DBName       =$tblDBInstance[0].rows[1].cells[0].InnerText
                $awrObj.InstanceName =$tblDBInstance[1].rows[1].cells[0].InnerText
                $awrObj.InstanceIndex=$tblDBInstance[1].rows[1].cells[1].InnerText
            }
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*database instance information`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }


        $tblHostInformation=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*host information'} 

        if ($tblHostInformation)
        {
            $offset=FirstLineOffset($tblHostInformation)
            $awrObj.HostName= $tblHostInformation.rows[$offset].cells[0].InnerText
            $awrObj.CPUs    = ConvertNumberOrDefault $tblHostInformation.rows[$offset].cells[2].InnerText
            $awrObj.Cores   = ConvertNumberOrDefault $tblHostInformation.rows[$offset].cells[3].InnerText
            $awrObj.Memory  = ConvertNumberOrDefault $tblHostInformation.rows[$offset].cells[5].InnerText
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*host information`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }


        $tblSnapshot=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*snapshot information'} 

        if ($tblSnapshot)
        {
            $offset=FirstLineOffset($tblSnapshot)
    
            for($i=0;$i -lt $tblSnapshot.rows.Length-1;$i++)
            {
                if($tblSnapshot.rows[$i+$offset].cells[0].InnerText -like "Elapsed*")
                {
                    $awrObj.ElapsedTime= ConvertNumberOrDefault ($tblSnapshot.rows[$i+$offset].cells[2].InnerText -replace "[^\d*\,?\.?\d*$/]",'') 0 
                }
                elseif($tblSnapshot.rows[$i+$offset].cells[0].InnerText -like "DB Time*")
                {
                    $awrObj.DBTime= ConvertNumberOrDefault ($tblSnapshot.rows[$i+$offset].cells[2].InnerText -replace "[^\d*\,?\.?\d*$/]",'') 0 
                }
            }
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*snapshot information`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }


        $tblTimeModel=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*time model statistics*'} 

        if ($tblTimeModel)
        {
            $offset=FirstLineOffset($tblTimeModel)
    
            for($i=0;$i -lt $tblTimeModel.rows.Length-1;$i++)
            {
                if($tblTimeModel.rows[$i+$offset].cells[0].InnerText -ieq "DB CPU")
                {
                $awrObj.DBCPU=ConvertNumberOrDefault $tblTimeModel.rows[$i+$offset].cells[1].InnerText 0 
                }
            }
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*time model statistics*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblHostCPU=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*CPU usage and wait statistics'} 

        if ($tblHostCPU)
        {
            $offset=FirstLineOffset($tblHostCPU)
            $awrObj.BusyCPU=ConvertNumberOrDefault $tblHostCPU.rows[$offset].cells[1].InnerText 0 
            $awrObj.BusyCPU/=100
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*CPU usage and wait statistics`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }
    

        $tblMemoryStats=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*memory statistics'} 

        if ($tblMemoryStats)
        {
            $offset=FirstLineOffset($tblMemoryStats)

            for($i=0;$i -lt $tblMemoryStats.rows.Length-1;$i++)
            {
                if($tblMemoryStats.rows[$i+$offset].cells[0].InnerText -like "SGA use (MB)*")
                {
                    $begin=ConvertNumberOrDefault $tblMemoryStats.rows[$i+$offset].cells[1].InnerText 0
                    $end  =ConvertNumberOrDefault $tblMemoryStats.rows[$i+$offset].cells[2].InnerText 0
                    $awrObj.SGAUse= [double]([Math]::Max($begin, $end))
                }
                elseif($tblMemoryStats.rows[$i+$offset].cells[0].InnerText -like "PGA use (MB)*")
                {
                    $begin=ConvertNumberOrDefault $tblMemoryStats.rows[$i+$offset].cells[1].InnerText 0
                    $end  =ConvertNumberOrDefault $tblMemoryStats.rows[$i+$offset].cells[2].InnerText 0
                    $awrObj.PGAUse= [double]([Math]::Max($begin, $end))
                }
            }
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*memory statistics`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }

        $tblIOStats=$html.body.getElementsByTagName('table') | Where {$_.summary -like '*IO Statistics for different file types*'} 

        if ($tblIOStats)
        {

            $awrObj.ReadIOPS       = ConvertAbbreviatedNumberOrDefault $tblIOStats.rows[$tblIOStats.rows.Length-1].cells[2].InnerText 0 1024
            $awrObj.ReadThroughput = ConvertAbbreviatedNumberOrDefault $tblIOStats.rows[$tblIOStats.rows.Length-1].cells[3].InnerText 0 1024
            $awrObj.ReadThroughput/=1024*1024
            $awrObj.WriteIOPS      = ConvertAbbreviatedNumberOrDefault $tblIOStats.rows[$tblIOStats.rows.Length-1].cells[5].InnerText 0 1024
            $awrObj.WriteThroughput= ConvertAbbreviatedNumberOrDefault $tblIOStats.rows[$tblIOStats.rows.Length-1].cells[6].InnerText 0 1024
            $awrObj.WriteThroughput/=1024*1024
        }
        else {
            Write-Host "HTML table cannot be found summary=`"*IO Statistics for different file types*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
        }
    }
    else {
        Write-Host "Unsupported relese $releaseNumber found while processing file `"$awrReportFileName`"" -ForegroundColor Red
    }
    return @($awrObj)
}

function IsNumber {
    param ([string]$text)
    return [bool]($text -as [double])  
}

function ConvertAbbreviatedNumberOrDefault {
    param (
        [string]$textToConvert,
        [decimal]$defaultValue,
        [decimal]$baseMultiplier #eg if you use 1000 or 1024 for multiplication 
    )
    [decimal]$parsedNumber=0
    [decimal]$multiplier=1
    [string]$suffix=$textToConvert.Substring($textToConvert.Length-1,1)

    if    ($suffix -ieq 'K' ){$multiplier=[Math]::Pow($baseMultiplier,1)}
    elseif($suffix -ieq 'M' ){$multiplier=[Math]::Pow($baseMultiplier,2)}
    elseif($suffix -ieq 'G' ){$multiplier=[Math]::Pow($baseMultiplier,3)}
    elseif($suffix -ieq 'T' ){$multiplier=[Math]::Pow($baseMultiplier,4)}
    elseif($suffix -ieq 'P' ){$multiplier=[Math]::Pow($baseMultiplier,5)}
    if(-not (IsNumber($suffix))){$textToConvert=$textToConvert.Substring(0,$textToConvert.Length-1)}
    
    $parsedNumber=ConvertNumberOrDefault $textToConvert 0
    $parsedNumber*=$multiplier
    return $parsedNumber
}


function ParseAWR_RAC([object]$html, [string]$awrReportFileName){
    $tblDBSummary=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'Database Summary'} 

    if ($tblDBSummary)
    {
        $databaseName=$tblDBSummary.rows[2].cells[1].InnerText 
    }
    else {
        throw "HTML table cannot be found summary=`"Database Summary`" while processing file `"$awrReportFileName`""
    }

    [array]$awrData=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'Database Instances Included In Report*'} | ForEach-Object {$_.rows} | where {$_.cells[0].tagName -ne "TH"} |
    ForEach-Object {
        $objectProps=[ordered]@{
            InstanceIndex=ConvertNumberOrDefault $_.cells[0].InnerText 0 
            Release      =$_.cells[6].InnerText 
            DBName       =$databaseName
            InstanceName =$_.cells[1].InnerText 
            HostName     =$_.cells[2].InnerText 
            ElapsedTime  =ConvertNumberOrDefault $_.cells[7].InnerText 0  
            DBTime       =ConvertNumberOrDefault $_.cells[8].InnerText 0 
            DBCPU        =0
            CPUs         =0
            Cores        =0
            Memory       =0
            BusyCPU      =0
            SGAUse       =0
            PGAUse       =0
            ReadThroughput  =0
            WriteThroughput =0
            ReadIOPS        =0
            WriteIOPS       =0
            TotalThroughput =0
            TotalIOPS       =0
            CPUTotalCapacity=0
            ORAUse          =0
            SourceCPUHTFactor=0
            AverageActiveSessions=0
            AWRReportFileName=$awrReportFileName
            ReportType="RAC"
        }
        New-Object -TypeName PSCustomObject -Property $objectProps #this is to provide ordered list of object properties
    }

    if (-not ($awrData))
    {
        throw "HTML table cannot be found summary=`"Database Instances Included In Report*`" while processing file `"$awrReportFileName`""
    }

    #If we made it here file is processed at least partially. Try block/finally makes sure whatever is extracted from AWR report is appended into global report

    $tblTimeModel=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'Time Model*'} 

    if ($tblTimeModel)
    {
        $offset=FirstLineOffset($tblTimeModel)

        for($i=0;$i -lt $awrData.Length;$i++)
        {
            $awrData[$i].DBCPU=ConvertNumberOrDefault $tblTimeModel.rows[$i+$offset].cells[2].InnerText 0 
        }
    }
    else {
        Write-Host "HTML table cannot be found summary=`"Time Model*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
    }

    $tblOSStatistics=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'OS Statistics By Instance*'} 

    if ($tblOSStatistics)
    {
        $offset=FirstLineOffset($tblOSStatistics)

        for($i=0;$i -lt $awrData.Length;$i++)
        {
            $awrData[$i].CPUs   =ConvertNumberOrDefault $tblOSStatistics.rows[$i+$offset].cells[ 1].InnerText 0 
            $awrData[$i].Cores  =ConvertNumberOrDefault $tblOSStatistics.rows[$i+$offset].cells[ 2].InnerText 0 
            $awrData[$i].Memory =ConvertNumberOrDefault $tblOSStatistics.rows[$i+$offset].cells[14].InnerText 0 
            $awrData[$i].Memory/=1024
            $awrData[$i].busyCPU=ConvertNumberOrDefault $tblOSStatistics.rows[$i+$offset].cells[ 6].InnerText 0 
            $awrData[$i].busyCPU/=100
        }
    
    }
    else {
        Write-Host "HTML table cannot be found summary=`"OS Statistics By Instance*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
    }

    $tblCacheSizes=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'Cache Sizes*'} 
    if ($tblCacheSizes)
    {
        $offset=FirstLineOffset($tblCacheSizes)

        for($i=0;$i -lt $awrData.Length;$i++)
        {
            $begin=ConvertNumberOrDefault $tblCacheSizes.rows[$i+$offset].cells[3].InnerText 0 
            $end  =ConvertNumberOrDefault $tblCacheSizes.rows[$i+$offset].cells[4].InnerText 0 
            $awrData[$i].SGAuse=[Math]::Max($begin, $end)

            $begin=ConvertNumberOrDefault $tblCacheSizes.rows[$i+$offset].cells[15].InnerText 0 
            $end  =ConvertNumberOrDefault $tblCacheSizes.rows[$i+$offset].cells[16].InnerText 0 
            $awrData[$i].PGAuse=[Math]::Max($begin, $end)
        }
    }
    else {
        Write-Host "HTML table cannot be found summary=`"Cache Sizes*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
    }


    $tblIOStatByFileType=$html.body.getElementsByTagName('table') | Where {$_.summary -like 'IOStat by File Type*'} 

    if ($tblIOStatByFileType)
    {
        $release=$awrData[0].Release

        if(($release -like "19*") -or ($release -like "18*"))
        {
            for($i=0;$i -lt $awrData.Length;$i++)
            {
                $currentInstance=-1
                $rowIndex=-1
                for($j=0;$j -lt $tblIOStatByFileType.rows.length; $j++)
                {
                    $currentInstance=ConvertNumberOrDefault $tblIOStatByFileType.rows[$j].cells[0].InnerText -1
                    if ($currentInstance -eq $awrData[$i].InstanceIndex)
                    {
                        $rowIndex=$j
                        break
                    }
        
                }
        
                if ($rowIndex -gt -1)
                {
                    $awrData[$i].ReadThroughput =ConvertNumberOrDefault $tblIOStatByFileType.rows[$rowIndex].cells[8].InnerText 0 
                    $awrData[$i].WriteThroughput=ConvertNumberOrDefault $tblIOStatByFileType.rows[$rowIndex].cells[9].InnerText 0 
                    $awrData[$i].ReadIOPS       =ConvertNumberOrDefault $tblIOStatByFileType.rows[$rowIndex].cells[4].InnerText 0 
                    $awrData[$i].WriteIOPS      =ConvertNumberOrDefault $tblIOStatByFileType.rows[$rowIndex].cells[5].InnerText 0 
                }
            }
        }
        else
        {
            $offset=FirstLineOffset($tblIOStatByFileType)

            for($i=0;$i -lt $awrData.Length;$i++)
            {
                $awrData[$i].ReadThroughput=ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[1].InnerText 0 
                if ($awrData[$i].ReadThroughput -eq 0){$awrData[$i].ReadThroughput=(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[2].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[3].InnerText 0)}
                $awrData[$i].WriteThroughput=ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[4].InnerText 0 
                if ($awrData[$i].WriteThroughput -eq 0){$awrData[$i].WriteThroughput=(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[5].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[6].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[7].InnerText 0)}
                $awrData[$i].ReadIOPS=ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[8].InnerText 0 
                if ($awrData[$i].ReadIOPS -eq 0){$awrData[$i].ReadIOPS=(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[9].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[10].InnerText 0)}
                $awrData[$i].WriteIOPS=ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[11].InnerText 0 
                if ($awrData[$i].WriteIOPS -eq 0)
                {
                    $awrData[$i].WriteIOPS=(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[12].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[13].InnerText 0)+(ConvertNumberOrDefault $tblIOStatByFileType.rows[$i+$offset].cells[14].InnerText 0)
                }
            }
        }
    }
    else {
        Write-Host "HTML table cannot be found summary=`"IOStat by File Type*`" while processing file `"$awrReportFileName`"" -ForegroundColor Red
    }

    Write-Debug "awrData contains $($awrData.Length) element(s)"
    Write-Debug ($awrData | Format-Table | Out-String)

    return $awrData
}

######################################### Process AWR Report #########################################
<#
.SYNOPSIS
 Process a single AWR Report file.

.DESCRIPTION
Processes a given AWR report file in HTML format, extracts information and appends it into a global array (awrDataAll)

.PARAMETER awrReportFileName
Full path to AWR report file to be processed.

.EXAMPLE
ProcessAWRReport -awrReportFileName $_.FullName

#>
function ProcessAWRReport {
    param (
        [string]$awrReportFileName
    )
    
    Write-Host "$($global:numProcessedFiles+1)-Processing file : $awrReportFileName"
    $OperationsStartedAt=Get-Date

    try {

        Write-Debug "Creating HTML DOM object..."
        $html = New-Object -ComObject "HTMLFile"

        Write-Debug "Opening HTML file ($awrReportFileName) ..."
        $source = Get-Content -Path $awrReportFileName -Raw

        Write-Debug "Loading DOM document ..."
        try {
            $html.IHTMLDocument2_write($source)
        }
        catch {
            $srcBytes = [System.Text.Encoding]::Unicode.GetBytes($source)
            $html.write($srcBytes)
        }        
        

        $htmlHeader=$html.body.getElementsByTagName('h1')

        if ($htmlHeader)
        {
            $awrReportFileBaseName=""
            try{
            $awrReportFileBaseName = [System.IO.Path]::GetFileName($awrReportFileName) 
            }
            catch{}

            if([string]::IsNullOrEmpty($awrReportFileBaseName))
            {
                $awrReportFileBaseName=$awrReportFileName
            }
            
            $awrData = $null
            if ($htmlHeader[0].InnerText.Trim() -ieq $global:AWRRACReportTitle)
            {
                $awrData=ParseAWR_RAC $html $awrReportFileBaseName
            }
            elseif ($htmlHeader[0].InnerText.Trim() -ieq $global:AWRNormalReportTitle) {
                $awrData=ParseAWR_Normal $html $awrReportFileBaseName
            }
            else
            {
                throw "This file ($awrReportFileName) does not seem to be a valid report file. It should be an AWR report generated by awrgrpt.sql or a Global (RAC) AWR report generated by awrgrpt.sql. The report should read `"$global:AWRRACReportTitle`" or `"$global:AWRNormalReportTitle`" at the top."
            }
            #append to global array
            if($null -ne $awrData )
            {
                $global:numProcessedFiles++
                $global:awrDataAll +=  $awrData  
            }

        }
        else {
            throw "This file ($awrReportFileName) does not seem to be a valid report file. It should be an AWR report generated by awrgrpt.sql or a Global (RAC) AWR report generated by awrgrpt.sql. The report should read `"$global:AWRRACReportTitle`" or `"$global:AWRNormalReportTitle`" at the top."
        }

    }
    catch {
        Write-Host "Error processing file `"$awrReportFileName`":" -ForegroundColor Red
        Write-Host ($_ | out-string) -ForegroundColor Red
    }
    finally{
        Write-Debug "Releasing DOM object..."
        [System.Runtime.Interopservices.Marshal]::ReleaseComObject($html) | Out-Null
        Write-Debug "File processing took $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds"
        }
}



######################################### Export to Excel #########################################
<#
.SYNOPSIS
Export data to Excel

.DESCRIPTION
Export data that was collected into the global array (awrDataAll) to an excel file. Also generates Azure VM SKU recommendations and exports them into the same Excel file.

#>
function ExportToExcel(){
    Write-Host "Exporting to Excel..."
    Write-Debug "Starting Excel ..."
    $XL = New-Object -comobject Excel.Application

    if ($DebugPreference -eq "Continue")
    {
        $XL.Visible = $true
    }
    if (-not $XL.Visible) {
        $XL.DisplayAlerts = $false
    }
    
    
    try{

  
        $global:awrDataAll = $global:awrDataAll | 
            Group-Object -Property InstanceIndex,Release,DBName,InstanceName,HostName | 
            ForEach-object {
                #$elapsedTime,$dbTime,$dbCpu = ($_.Group|Measure-Object ElapsedTime,DBTime,DBCPU -Sum    ).Sum
                $MaxAAS      =($_.Group | Select-Object @{n='AAS'           ;e={[math]::Round($_.DBTime / $_.ElapsedTime,3)}} | Measure-Object AAS -Maximum).Maximum
                $MaxAASRow   = $_.Group | Select-Object ElapsedTime,DBTime,DBCPU,@{n='AAS'           ;e={[math]::Round($_.DBTime / $_.ElapsedTime,3)}} | Where-Object AAS -eq $MaxAAS  | Select-Object ElapsedTime,DBTime,DBCPU -First 1
                $elapsedTime = $MaxAASRow.ElapsedTime
                $dbTime      = $MaxAASRow.DBTime
                $dbCpu       = $MaxAASRow.DBCPU

                $CPUs,$Cores,$Memory        = ($_.Group|Measure-Object CPUs,Cores,Memory        -Maximum).Maximum
                $SGAUse,$PGAUse             = ($_.Group|Measure-Object SGAUse,PGAUse            -Maximum).Maximum
                $BusyCpu, $ReadThroughput, $ReadIOPS, $WriteThroughput, $WriteIOPS = ($_.Group|Measure-Object BusyCpu, ReadThroughput, ReadIOPS, WriteThroughput, WriteIOPS -Maximum).Maximum

                # $BusyCpuxElapsedTime, $ReadThroughputxElapsedTime, $ReadIOPSxElapsedTime, $WriteThroughputxElapsedTime, $WriteIOPSxElapsedTime = ($_.Group | Select-Object @{n='BusyCpuxElapsedTime'           ;e={$_.BusyCPU * $_.ElapsedTime}}, 
                #         @{n='ReadThroughputxElapsedTime'    ;e={$_.ReadThroughput  * $_.ElapsedTime}}, 
                #         @{n='ReadIOPSxElapsedTime'          ;e={$_.ReadIOPS        * $_.ElapsedTime}}, 
                #         @{n='WriteThroughputxElapsedTime'   ;e={$_.WriteThroughput * $_.ElapsedTime}}, 
                #         @{n='WriteIOPSxElapsedTime'         ;e={$_.WriteIOPS       * $_.ElapsedTime}} | 
                #         Measure-Object BusyCpuxElapsedTime, ReadThroughputxElapsedTime, ReadIOPSxElapsedTime, WriteThroughputxElapsedTime, WriteIOPSxElapsedTime -Sum).Sum
                $awrReportFileName=($_.Group.AWRReportFileName -join ",`n")
                $reportType=(($_.Group.ReportType | Select-Object -Unique) -join ",")
                [PSCustomObject]@{
                    InstanceIndex=$_.Group[0].InstanceIndex
                    Release      =$_.Group[0].Release
                    DBName       =$_.Group[0].DBName
                    InstanceName =$_.Group[0].InstanceName
                    HostName     =$_.Group[0].HostName
                    ElapsedTime  =$elapsedTime
                    DBTime       =$dbTime
                    DBCPU        =$dbCpu
                    CPUs         =$CPUs
                    Cores        =$Cores
                    Memory       =$Memory
                    BusyCPU      =$BusyCpu
                    #BusyCPU      =$BusyCpuxElapsedTime/$elapsedTime
                    SGAUse       =$SGAUse
                    PGAUse       =$PGAUse
                    ReadThroughput  =$ReadThroughput
                    WriteThroughput =$WriteThroughput
                    ReadIOPS        =$ReadIOPS
                    WriteIOPS       =$WriteIOPS
                    # ReadThroughput  =$ReadThroughputxElapsedTime/$elapsedTime
                    # WriteThroughput =$WriteThroughputxElapsedTime/$elapsedTime
                    # ReadIOPS        =$ReadIOPSxElapsedTime/$elapsedTime
                    # WriteIOPS       =$WriteIOPSxElapsedTime/$elapsedTime
                    TotalThroughput =0
                    TotalIOPS       =0
                    CPUTotalCapacity=0
                    ORAUse          =0
                    SourceCPUHTFactor=0
                    AverageActiveSessions=0
                    AWRReportFileName=$awrReportFileName
                    ReportType=$reportType
                }

            }




    Write-Debug "Opening workbook..."
    Copy-Item $TemplateFileName $global:outputExcel
    $file=Get-Item $global:outputExcel #now that the file exists, get the file object
    $global:outputExcel=$file.FullName

    $wbOma = $XL.Workbooks.Open($global:outputExcel, $false) #UpdateLinks:=false
    $wsOma = $wbOma.Worksheets.Item("Data")

    if (-not $NoAwr.IsPresent)
    {
    Write-Host "Exporting tables ..."
    $OperationsStartedAt=Get-Date

    $tblAwr = $wsOma.ListObjects.Item("AWRData")
    Write-Debug "Populating AWR table..."
    ResetTable $tblAwr
    if($global:awrDataAll.Length -gt 0)
    {
        [array]$props=$global:awrDataAll[0].psobject.properties | select Name
    }
    for($i=0;$i -lt $global:awrDataAll.Length;$i++) {
        AppendRow $tblAwr

        for($j=0;$j -lt $props.Length;$j++) {
            if (-not $tblAwr.DataBodyRange.Item($i+1,$j+1).HasFormula())
            {
                $value = $global:awrDataAll[$i]."$($props[$j].Name)"
                $tblAwr.DataBodyRange.Item($i+1,$j+1) = $value
                if($props[$j].Name -eq "AWRReportFileName")
                {
                $tblAwr.DataBodyRange.Item($i+1,$j+1).WrapText = $false
                }
            }
        }
    }
    
    ############################# Instance Summary #############################
    $tblInstSummary = $wsOma.ListObjects.Item("InstSummary")
    Write-Debug "Populating Instance Summary table..."
    [array]$instSummaryData = $global:awrDataAll | Select-Object DBName,InstanceName -Unique
    if($instSummaryData.Length -gt 0)
    {
        [array]$props=$instSummaryData[0].psobject.properties | select Name
    }
    ResetTable $tblInstSummary
    for($i=0;$i -lt $instSummaryData.Length;$i++) {
        AppendRow $tblInstSummary
        for($j=0;$j -lt $props.Length;$j++) {
            if (-not $tblInstSummary.DataBodyRange.Item($i+1,$j+1).HasFormula())
            {
                $tblInstSummary.DataBodyRange.Item($i+1,$j+1) = $instSummaryData[$i]."$($props[$j].Name)"
            }
        }
    }

    ############################# Host Summary #############################
    $tblHostSummary = $wsOma.ListObjects.Item("HostSummary")
    Write-Debug "Populating Host Summary table..."
    [array]$hostSummaryData = $global:awrDataAll | Select-Object HostName -Unique
    if($hostSummaryData.Length -gt 0)
    {
        [array]$props=$hostSummaryData[0].psobject.properties | select Name
    }
    ResetTable $tblHostSummary
    for($i=0;$i -lt $hostSummaryData.Length;$i++) {
        AppendRow $tblHostSummary
        for($j=0;$j -lt $props.Length;$j++) {
            if (-not $tblHostSummary.DataBodyRange.Item($i+1,$j+1).HasFormula())
            {
                $tblHostSummary.DataBodyRange.Item($i+1,$j+1) = $hostSummaryData[$i]."$($props[$j].Name)"
            }
        }
    }
   
    ############################# DB Summary #############################
    $tblDBSummary = $wsOma.ListObjects.Item("DBSummary")
    Write-Debug "Populating DB Summary table..."
    [array]$dbSummaryData = $global:awrDataAll | Select-Object DBName -Unique
    if($dbSummaryData.Length -gt 0)
    {
        [array]$props=$dbSummaryData[0].psobject.properties | select Name
    }

    ResetTable $tblDBSummary
    for($i=0;$i -lt $dbSummaryData.Length;$i++) {
        AppendRow $tblDBSummary
        $tblDBSummary.DataBodyRange.Item($i+1,1) = "Server1"
        for($j=0;$j -lt $props.Length;$j++) {
            if (-not $tblDBSummary.DataBodyRange.Item($i+1,$j+1).HasFormula())
            {
                $tblDBSummary.DataBodyRange.Item($i+1,$j+1+1) = $dbSummaryData[$i]."$($props[$j].Name)"
            }
        }
    }

    Write-Debug "Export tables took $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds"
    }
    else{
        $temp = $XL.DisplayAlerts
        $XL.DisplayAlerts = $false
        $wsOma.Delete() | Out-Null
        $XL.DisplayAlerts = $temp
        $wsOma=$null
        $wsRecommendations = $wbOma.Worksheets.Item("Recommendations")
        $tblAzureServerSummary = $wsRecommendations.ListObjects.Item("AzureServerSummary")
        $tblAzureServerSummary.DataBodyRange.Item(1,1) = "Server1"
        $tblAzureServerSummary.DataBodyRange.Item(1,2) = ""
        $tblAzureServerSummary.DataBodyRange.Item(1,3) = "<not used>"
        $tblAzureServerSummary.DataBodyRange.Item(1,4) = "<not used>"
        $tblAzureServerSummary.DataBodyRange.Item(1,5) = "<enter data>"
        $tblAzureServerSummary.DataBodyRange.Item(1,6) = "<not used>"
        $tblAzureServerSummary.DataBodyRange.Item(1,7) = "<not used>"
        $tblAzureServerSummary.DataBodyRange.Item(1,8) = "<enter data>"
        $tblAzureServerSummary.DataBodyRange.Item(1,9) = "<enter data>"
        $tblAzureServerSummary.DataBodyRange.Item(1,10) = "<not used>"
        $tblAzureServerSummary.DataBodyRange.Item(1,11) = "<enter data>"
        $tblAzureServerSummary.DataBodyRange.Item(1,12) = "<enter data>"
        for($i=1;$i -lt $tblAzureServerSummary.DataBodyRange.Columns.Count;$i++) {
            if($tblAzureServerSummary.DataBodyRange.Item(1,$i+1).Text -eq "<not used>")
            {
                $tblAzureServerSummary.DataBodyRange.Item(1,$i+1).Font.ThemeColor = 3 #xlThemeColorDark2            
                $tblAzureServerSummary.DataBodyRange.Item(1,$i+1).Font.TintAndShade = -0.5 #50% lighter
                $tblAzureServerSummary.DataBodyRange.Item(1,$i+1).HorizontalAlignment = -4108 #xlCenter

            }
        }
    }

    if ([string]::IsNullOrEmpty($AzureRegion))
    {
        $filter="currencyCode eq 'USD' and (serviceFamily eq 'Compute' or serviceFamily eq 'Storage')"
        Write-Host "Fetching pricelist for all regions in USD. This operation takes a while."
    }
    else {
        $filter="armRegionName eq '$AzureRegion' and currencyCode eq 'USD' and (serviceFamily eq 'Compute' or serviceFamily eq 'Storage')"
        Write-Host "Fetching pricelist for $AzureRegion in USD. This operation takes a while."
    }
    $priceListAPIBaseUrl="https://prices.azure.com/api/retail/prices"
    $url="$($priceListAPIBaseUrl)?`$filter=$filter"
    $priceList=$null
    $pageNum=0

    $OperationsStartedAt=Get-Date
    while (-not [string]::IsNullOrEmpty($url))
    {
        $data=Invoke-RestMethod -Uri $url -Method Get
        $priceList+=$data.Items
        $url=$data.NextPageLink
        $pageNum++
        if(($pageNum % 10) -eq 0) 
        {
            Write-Debug "Processing $pageNum pages in $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds."
        }
    }
    Write-Debug "Processed $pageNum pages in $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds."


    $OperationsStartedAt=Get-Date
    $wsAzurePriceList = $wbOma.Worksheets.Item("AzurePriceList")
    $priceListProperties=$priceList[0].psobject.properties  | select Name
    $priceListStaticProperties=[string[]]("serviceFamily","serviceName","type","productName","armSkuName","skuName","meterName", "unitPrice","unitOfMeasure","armRegionName","location")

    Write-Debug "Creating AzurePriceList table ..."
    try{$tblAzurePriceList = $wsAzurePriceList.ListObjects.Item("AzurePriceList")}catch{}
    if($null -eq $tblAzurePriceList)
    {
    $tblStartRow=1
    $tblStartCol=1
    $tblAzurePriceList = $wsAzurePriceList.ListObjects.Add(
        $global:XlListObjectSourceType_xlSrcRange, 
        $wsAzurePriceList.Range($wsAzurePriceList.cells($tblStartRow,$tblStartCol),$wsAzurePriceList.cells($tblStartRow+$priceList.Length  ,$priceListProperties.Length+$tblStartCol-1)), 
        $null ,
        $global:XlYesNoGuess_xlYes)

    $tblAzurePriceList.Name = "AzurePriceList"
    $tblAzurePriceList.ShowHeaders = $true
    $tblAzurePriceList.ShowTotals = $false
    $tblAzurePriceList.TableStyle = "TableStyleMedium9"
    }
    else {
        try{
        if($null -ne $tblAzurePriceList.DataBodyRange) {$tblAzurePriceList.DataBodyRange.Rows.Delete() | Out-Null}
        if($priceListProperties.Length -lt $tblAzurePriceList.ListColumns.Count)
        {
            for($i=$priceListProperties.Length+1;$i -le $tblAzurePriceList.ListColumns.Count;$i++) {
                $tblAzurePriceList.HeaderRowRange.Item(1,$i) = ''
            }
        }
        $tblStartRow=$tblAzurePriceList.Range.Cells(1,1).Row
        $tblStartCol=$tblAzurePriceList.Range.Cells(1,1).Column
        $tblAzurePriceList.Resize($wsAzurePriceList.Range($wsAzurePriceList.cells($tblStartRow,$tblStartCol),$wsAzurePriceList.cells($tblStartRow+$priceList.Length  ,$priceListProperties.Length+$tblStartCol-1)))
        }
        catch{}
    }

    Write-Debug "Formatting headers for AzurePriceList table..."
    for($i=0;$i -lt $priceListStaticProperties.Length;$i++) {
        $tblAzurePriceList.HeaderRowRange.Item(1,$i+1) = $priceListStaticProperties[$i]
    }
    $k=$priceListStaticProperties.Length
    for($i=0;$i -lt $priceListProperties.Length;$i++) {
        if($priceListStaticProperties -notcontains $priceListProperties[$i].Name)
        {
            $tblAzurePriceList.HeaderRowRange.Item(1,(($k++)+1)) = $priceListProperties[$i].Name
        }
    }

    
    if($priceList.Length -gt 0)
    {
        Write-Host "Populating AzurePriceList table..."
        $rangeValues = new-object 'Object[,]' $priceList.Length, $priceListProperties.Length
        for($i=0;$i -lt $priceList.Length;$i++) {
            for($j=0;$j -lt $priceListStaticProperties.Length;$j++) {
                $rangeValues[$i,$j] = $priceList[$i]."$($priceListStaticProperties[$j])" 
            }
            
            $k=$priceListStaticProperties.Length
            for($j=0;$j -lt $priceListProperties.Length;$j++) {
                if($priceListStaticProperties -notcontains $priceListProperties[$j].Name)
                {
                    $rangeValues[$i,($k++)] = $priceList[$i]."$($priceListProperties[$j].Name)" 
                }
            }
        }
        $tblAzurePriceList.DataBodyRange.Value = $rangeValues
    }
    else{
        Write-Host "Could not fetch prices."
    }

    Write-Debug  "Operation took $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds."


    Write-Host "Fetching available Azure VM and Disk Skus in $AzureRegion. This operation takes a while."
    try{
    $OperationsStartedAt=Get-Date
        
    # Problem is that JSON reurned from "az vm list-skus" call can include two attributes with the same name but diferent casing: "locationInfo.zoneDetails.Name" and 
    # "locationInfo.zoneDetails.name". Therefore "ConvertFrom-Json" raises an error. In order to solve this problem properly, "-AsHashtable" parameter is provided for 
    # "ConvertFrom-Json".
    # However "-AsHashTable" parameter works only for PowerShell v6 and above. At the moment, we do not need the "Name" attribute in JSON anyway. 
    # Implemented a workaround so that instead of calling "ConvertFrom-Json" with "-AsHashtable" attribute, we'll just rename the attribute from "Name" to "_Name"
    # This workaround will also remove the need to upgrade PowerShell installation. 
    # Original Code: $json=az vm list-skus --all --location $AzureRegion | ConvertFrom-Json -AsHashtable
    if ([string]::IsNullOrEmpty($AzureRegion))
    {
        $stemp=az vm list-skus --all 2>$null
    }
    else {
        $stemp=az vm list-skus --all --location $AzureRegion 2>$null
    }
    $stemp=$stemp -creplace "`"Name`"","`"_Name`""
    $json= $stemp | ConvertFrom-Json
    # workaround ends here


    if ($null -ne $json)
    {
        $numFixedProps=25
        $azureVMSkus   = $json | where {$_.resourceType -eq "virtualMachines"} | ForEach-Object {

            $skuProps=ParseSkuSizeString($_.size)

            $objectProps=[ordered]@{
                name = $_.name
                size = $_.size
                tier = $_.tier
                family=$_.family
                resourceType=$_.resourceType
                location=$_.locations[0]
                monthlyCost=0
                vmRecommendationPriority = $global:RecommendationPriority_AllOthers
                vCPUs=[int]0
                vCPUsAvailable=[int]0
                vCPUsPerCore=[int]0
                Class 		            = $skuProps.Family 		            
                Subclass 		        = $skuProps.Subfamily
                AMDProcessor            = $skuProps.AMDProcessor           
                BlockStoragePerformance = $skuProps.BlockStoragePerformance
                Diskful                 = $skuProps.Diskful                
                IsolatedSize            = $skuProps.IsolatedSize           
                LowMemory               = $skuProps.LowMemory              
                MemoryIntensive         = $skuProps.MemoryIntensive        
                ARMProcessor            = $skuProps.ARMProcessor           
                TinyMemory              = $skuProps.TinyMemory             
                PremiumStorage          = $skuProps.PremiumStorage         
                AcceleratorType         = $skuProps.AcceleratorType        
                Version			        = $skuProps.Version			       
                Promo			        = $skuProps.Promo			         
            } 
            $obj = New-Object -TypeName PSCustomObject -Property $objectProps
            
            $_.capabilities | where {-not [string]::IsNullOrEmpty($_.name)} | ForEach-Object {
                if (-not ([bool](Get-member -Name $_.name -InputObject $obj -MemberType NoteProperty)))
                {
                add-member -InputObject $obj -MemberType NoteProperty -Name $_.name -Value $_.value
                }
                else {
                    $obj."$($_.name)"=$_.value
                }
            }
            $_.locationInfo[0].zoneDetails.capabilities | where {-not [string]::IsNullOrEmpty($_.name)} | ForEach-Object {
                if (-not ([bool](Get-member -Name $_.name -InputObject $obj -MemberType NoteProperty)))
                {
                add-member -InputObject $obj -MemberType NoteProperty -Name $_.name -Value $_.value
                }
                else {
                    $obj."$($_.name)"=$_.value
                }
            }
            return $obj
        } 
        

        $MaxESeriesVersion=($azureVMSkus | Where-Object Class -eq 'E' | Measure-Object Version -Maximum).Maximum
        $MaxMSeriesVersion=($azureVMSkus | Where-Object Class -eq 'M' | Measure-Object Version -Maximum).Maximum
        
        foreach($obj in $azureVMSkus)
        {
            if(($obj.Class -eq 'E') -and ($obj.Subclass -ne 'C') -and 
            ($obj.Diskful) -and (-not $obj.BlockStoragePerformance) -and (-not $obj.ARMProcessor) -and (-not $obj.LowMemory) -and (-not $obj.TinyMemory) -and
            ($obj.PremiumIO -ieq "True"))
            {
                if (($obj.Version -eq $MaxESeriesVersion) -or
                    (([string]::IsNullOrEmpty($obj.Version)) -and (($azureVMSkus | Where-Object {$_.size -eq "$($obj.Size)_$MaxESeriesVersion" }).Length -eq 0)))
                {
                    $obj.vmRecommendationPriority=$global:RecommendationPriority_BestPracticesOnly
                }
            }
            elseif(($obj.Class -eq 'M') -and 
            (-not $obj.BlockStoragePerformance) -and (-not $obj.ARMProcessor) -and (-not $obj.LowMemory) -and (-not $obj.TinyMemory) -and
            ($obj.PremiumIO -ieq "True"))
            {
                if (($obj.Version -eq $MaxMSeriesVersion) -or
                    (([string]::IsNullOrEmpty($obj.Version)) -and (($azureVMSkus | Where-Object {$_.size -eq "$($obj.Size)_$MaxMSeriesVersion" }).Length -eq 0)))
                {
                    $obj.vmRecommendationPriority=$global:RecommendationPriority_BestPracticesOnly
                }
            }
        }
        $wsAzureVmSkus = $wbOma.Worksheets.Item("AzureVMSkus")

        Write-Debug "Fetching VM properties ..."

        $props=$azureVMSkus[0].psobject.properties  | select Name
        $props1=$props[0 .. ($numFixedProps-1)]
        $props2=$props[($numFixedProps) .. ($props.Length-1)]

        for($i=1;$i -lt $azureVMSkus.Length;$i++)
        {
            $props=$azureVMSkus[$i].psobject.properties  | select Name
            $props2+=$props[($numFixedProps) .. ($props.Length-1)]
            if(($i % 100) -eq 0)
            {
                $props2 = $props2 | select Name -Unique
            }
        }
        $vmSkuProperties = $props1+($props2 | select Name -Unique)

        Write-Debug "Setting VM costs ..."
        $Timer1=Get-Date
        $reducedPriceListArray = $priceList | 
            Where-Object {
                ($_.serviceName -eq 'Virtual Machines') -and #only 'Virtual Machines' i.e. no 'Cloud Services'
                ($_.type -eq 'Consumption') -and #only 'Consumption' prices i.e not 'DevTestConsumption'
                ($_.skuName.EndsWith('Low Priority') -eq $false) -and  #dont consider low priority prices
                ($_.skuName.EndsWith('Spot') -eq $false) -and # dont consider spot prices
                ($_.productName.EndsWith('Cloud Services') -eq $false) -and # dont consider cloud services
                ($_.productName.StartsWith('Cloud Services') -eq $false) -and # dont consider cloud services
                ($_.productName.EndsWith('CloudServices') -eq $false) -and # dont consider cloud services
                ($_.productName.StartsWith('CloudServices') -eq $false) -and # dont consider cloud services
                ($_.productName.EndsWith('Windows') -eq $false) #
            }
        
        if ($DebugPreference -eq "Continue")
        {
            foreach($p in ($reducedPriceListArray | Group-Object -Property armSkuName | Where-Object {$_.Count -gt 1}))
            {
                Write-Debug "More than one price found for VM SKU '$($p.Name)'"
            }
        }

        for($i=0;$i -lt $azureVMSkus.Length;$i++) {
            [array]$r=$reducedPriceListArray | where {($azureVMSkus[$i].name -eq $_.armSkuName)}
            if($r.Length -eq 1)
            {
                $azureVMSkus[$i].monthlyCost = $r[0].unitPrice*730
            }
            elseif($r.Length -gt 1)
            {
                $azureVMSkus[$i].monthlyCost = -1
            }
        }
        Write-Debug  "Setting VM costs took $($($($(Get-Date) - $Timer1)).TotalSeconds) seconds."

        Write-Debug "Creating AzureVMSkus table ..."
        try{$tblAzureVmSkus = $wsAzureVmSkus.ListObjects.Item("AzureVMSkus")}catch{}
        if($null -eq $tblAzureVmSkus)
        {
        $tblStartRow=1
        $tblStartCol=1
        $tblAzureVmSkus = $wsAzureVmSkus.ListObjects.Add(
            $global:XlListObjectSourceType_xlSrcRange, 
            $wsAzureVmSkus.Range($wsAzureVmSkus.cells($tblStartRow,$tblStartCol),$wsAzureVmSkus.cells($tblStartRow+$azureVMSkus.Length  ,$vmSkuProperties.Length+$tblStartCol-1)), 
            $null ,
            $global:XlYesNoGuess_xlYes)

        $tblAzureVmSkus.Name = "AzureVMSkus"
        $tblAzureVmSkus.ShowHeaders = $true
        $tblAzureVmSkus.ShowTotals = $false
        $tblAzureVmSkus.TableStyle = "TableStyleMedium9"
        }
        else {
            try{
                if($null -ne $tblAzureVmSkus.DataBodyRange) {$tblAzureVmSkus.DataBodyRange.Rows.Delete() | Out-Null}
                if($vmSkuProperties.Length -lt $tblAzureVmSkus.ListColumns.Count)
                {
                    for($i=$vmSkuProperties.Length+1;$i -le $tblAzureVmSkus.ListColumns.Count;$i++) {
                        $tblAzureVmSkus.HeaderRowRange.Item(1,$i) = ''
                    }
                }
                $tblStartRow=$tblAzureVmSkus.Range.Cells(1,1).Row
                $tblStartCol=$tblAzureVmSkus.Range.Cells(1,1).Column
                $tblAzureVmSkus.Resize($wsAzureVmSkus.Range($wsAzureVmSkus.cells($tblStartRow,$tblStartCol),$wsAzureVmSkus.cells($tblStartRow+$azureVMSkus.Length  ,$vmSkuProperties.Length+$tblStartCol-1)))
            }
            catch{}
        }

        Write-Debug "Formatting headers for AzureVMSkus table..."
        for($i=0;$i -lt $vmSkuProperties.Length;$i++) {
            $tblAzureVmSkus.HeaderRowRange.Item(1,$i+1) = $vmSkuProperties[$i].Name
        }
        
        Write-Host "Populating AzureVMSkus table..."
        $rangeValues = new-object 'Object[,]' $azureVMSkus.Length, $vmSkuProperties.Length
        for($i=0;$i -lt $azureVMSkus.Length;$i++) {
            for($j=0;$j -lt $vmSkuProperties.Length;$j++) {
                $rangeValues[$i,$j] = $azureVMSkus[$i]."$($vmSkuProperties[$j].Name)"

                #Some values come as null from Azure RM 
                #updating those values with specs from https://learn.microsoft.com/en-us/azure/virtual-machines/mv2-series
                if (($azureVMSkus[$i].size -like 'M208*') -and ($vmSkuProperties[$j].Name -eq 'UncachedDiskIOPS') -and ([string]::IsNullOrEmpty($azureVMSkus[$i]."$($vmSkuProperties[$j].Name)")))
                    {$rangeValues[$i,$j] = 40000}
                elseif (($azureVMSkus[$i].size -like 'M208*') -and ($vmSkuProperties[$j].Name -eq 'UncachedDiskBytesPerSecond') -and ([string]::IsNullOrEmpty($azureVMSkus[$i]."$($vmSkuProperties[$j].Name)")))
                    {$rangeValues[$i,$j] = 1000000000}
                elseif (($azureVMSkus[$i].size -like 'M416*') -and ($vmSkuProperties[$j].Name -eq 'UncachedDiskIOPS') -and ([string]::IsNullOrEmpty($azureVMSkus[$i]."$($vmSkuProperties[$j].Name)")))
                    {$rangeValues[$i,$j] = 80000}
                elseif (($azureVMSkus[$i].size -like 'M416*') -and ($vmSkuProperties[$j].Name -eq 'UncachedDiskBytesPerSecond') -and ([string]::IsNullOrEmpty($azureVMSkus[$i]."$($vmSkuProperties[$j].Name)")))
                    {$rangeValues[$i,$j] = 2000000000}
                
                if (($vmSkuProperties[$j].Name -eq 'vCPUsAvailable') -and ([string]::IsNullOrEmpty($azureVMSkus[$i]."$($vmSkuProperties[$j].Name)")))
                {$rangeValues[$i,$j] = $azureVMSkus[$i].vCpus}
            }

        }
        $tblAzureVmSkus.DataBodyRange.Value = $rangeValues

        $numFixedProps=8
        $azureDiskSkus = $json | where {$_.resourceType -eq "disks"} | ForEach-Object {
            $objectProps=[ordered]@{
                name = $_.name
                size = $_.size
                tier = $_.tier
                family=$_.family
                resourceType=$_.resourceType
                location=$_.locations[0]
                monthlyCost=0
                diskRecommendationPriority = $global:RecommendationPriority_AllOthers
            } 
            $obj = New-Object -TypeName PSCustomObject -Property $objectProps
            
            $_.capabilities | where {-not [string]::IsNullOrEmpty($_.name)} | ForEach-Object {
                if (-not ([bool](Get-member -Name $_.name -InputObject $obj -MemberType NoteProperty)))
                {
                add-member -InputObject $obj -MemberType NoteProperty -Name $_.name -Value $_.value
                }
                else {
                    $obj."$($_.name)"=$_.value
                }
            }
            $_.locationInfo[0].zoneDetails.capabilities | where {-not [string]::IsNullOrEmpty($_.name)} | ForEach-Object {
                if (-not ([bool](Get-member -Name $_.name -InputObject $obj -MemberType NoteProperty)))
                {
                add-member -InputObject $obj -MemberType NoteProperty -Name $_.name -Value $_.value
                }
                else {
                    $obj."$($_.name)"=$_.value
                }
            }
            return $obj
        } 

        $wsAzureDiskSkus = $wbOma.Worksheets.Item("AzureDiskSkus")

        $props=$azureDiskSkus[0].psobject.properties  | select Name
        $props1=$props[0 .. ($numFixedProps-1)]
        $props2=$props[($numFixedProps) .. ($props.Length-1)]

        for($i=1;$i -lt $azureDiskSkus.Length;$i++)
        {
            $props=$azureDiskSkus[$i].psobject.properties  | select Name
            $props2+=$props[($numFixedProps) .. ($props.Length-1)]
            if(($i % 100) -eq 0)
            {
                $props2 = $props2 | select Name -Unique
            }
        }
        $diskSkuProperties = $props1+($props2 | select Name -Unique)

        foreach($obj in $azureDiskSkus)
        {
            if ($obj.name.StartsWith("PremiumV2"))
            {
                $obj.diskRecommendationPriority=$global:RecommendationPriority_BestPracticesOnly
            }
            elseif ($obj.name.StartsWith("Premium"))
            {
                $obj.diskRecommendationPriority=$global:RecommendationPriority_BestPracticesOnly
            }
            elseif ($obj.name.StartsWith("Ultra"))
            {
                $obj.diskRecommendationPriority=$global:RecommendationPriority_BestPracticesOnly
            }
        }

        Write-Debug "Creating AzureDiskSkus table ..."
        try{$tblAzureDiskSkus = $wsAzureDiskSkus.ListObjects.Item("AzureDiskSkus")}catch{}
        if($null -eq $tblAzureDiskSkus)
        {
            $tblStartRow=1
            $tblStartCol=1
            $tblAzureDiskSkus = $wsAzureDiskSkus.ListObjects.Add(
                $global:XlListObjectSourceType_xlSrcRange, 
                $wsAzureDiskSkus.Range($wsAzureDiskSkus.cells($tblStartRow,$tblStartCol),$wsAzureDiskSkus.cells($tblStartRow+$azureDiskSkus.Length  ,$diskSkuProperties.Length+$tblStartCol-1)), 
                $null ,
                $global:XlYesNoGuess_xlYes)
        
            $tblAzureDiskSkus.Name = "AzureDiskSkus"
            $tblAzureDiskSkus.ShowHeaders = $true
            $tblAzureDiskSkus.ShowTotals = $false
            $tblAzureDiskSkus.TableStyle = "TableStyleMedium9"
        }
        else {
            try{
                if($null -ne $tblAzureDiskSkus.DataBodyRange) {$tblAzureDiskSkus.DataBodyRange.Rows.Delete() | Out-Null}
                if($diskSkuProperties.Length -lt $tblAzureDiskSkus.ListColumns.Count)
                {
                    for($i=$diskSkuProperties.Length+1;$i -le $tblAzureDiskSkus.ListColumns.Count;$i++) {
                        $tblAzureDiskSkus.HeaderRowRange.Item(1,$i) = ''
                    }
                }
                $tblStartRow=$tblAzureDiskSkus.Range.Cells(1,1).Row
                $tblStartCol=$tblAzureDiskSkus.Range.Cells(1,1).Column
                $tblAzureDiskSkus.Resize($wsAzureDiskSkus.Range($wsAzureDiskSkus.cells($tblStartRow,$tblStartCol),$wsAzureDiskSkus.cells($tblStartRow+$azureDiskSkus.Length  ,$diskSkuProperties.Length+$tblStartCol-1)))
            }
            catch{}
        }



        Write-Debug "Formatting headers for AzureDiskSkus table..."
        for($i=0;$i -lt $diskSkuProperties.Length;$i++) {
            $tblAzureDiskSkus.HeaderRowRange.Item(1,$i+1) = $diskSkuProperties[$i].Name
        }

        Write-Host "Populating AzureDiskSkus table..."
        $rangeValues = new-object 'Object[,]' $azureDiskSkus.Length, $diskSkuProperties.Length
        for($i=0;$i -lt $azureDiskSkus.Length;$i++) {
            for($j=0;$j -lt $diskSkuProperties.Length;$j++) {
                $rangeValues[$i,$j] = $azureDiskSkus[$i]."$($diskSkuProperties[$j].Name)"
            }
        }
        $tblAzureDiskSkus.DataBodyRange.Value = $rangeValues

        Write-Debug "Operation took $($($($(Get-Date) - $OperationsStartedAt)).TotalSeconds) seconds"


        foreach($slicerCache in $wbOma.SlicerCaches)
        {
            foreach($slicer in $slicerCache.Slicers)
            {
                if($slicer.Name -eq "vmRecommendationPriority" -or $slicer.Name -eq "diskRecommendationPriority")
                {
                    foreach($slicerItem in $slicerCache.SlicerItems)
                    {
                        if($slicerItem.Value -eq $global:RecommendationPriority_BestPracticesOnly)
                        {
                            $slicerItem.Selected = $true
                        }
                        else {
                            $slicerItem.Selected = $false
                        }
                    }
                }
            }
        }

        if(-not $NoAwr.IsPresent)
        {
            Write-Host "Refreshing recommendations..."
            $XL.Run('RefreshRecommendations')
        }
    }
    else
    {
        Write-Host "Azure SKUs cannot be fetched. Parsed AWR data will be available in Excel, but recommendations will not be available."
    }

    }
    catch {
        Write-Host "Error generating recommendations." -ForegroundColor Red
        Write-Host ($_ | out-string) -ForegroundColor Red
    }
    
}
catch [System.Runtime.InteropServices.COMException] {
    Write-Host "An Excel related error has occured." -ForegroundColor Red
    Write-Host ($_ | out-string) -ForegroundColor Red
}
catch {
    Write-Host ($_ | out-string) -ForegroundColor Red
}
finally
{
    Write-Debug "Saving Excel file ($global:outputExcel)..."
    if($null -ne $wbOma)
    {
        if($null -ne $wsOma)
        {
            $wsOma.Activate() | Out-Null
            $wsOma.Cells(1,1).Activate() | Out-Null
        }
        elseif($null -ne $wsRecommendations)
        {
            $wsRecommendations.Activate() | Out-Null
            $wsRecommendations.Cells(1,1).Activate() | Out-Null
        }
        
        $wbOma.Save() | Out-Null #($global:outputExcel,$global:XlFileFormat_xlOpenXMLWorkbookMacroEnabled) 
        $wbOma.Close($false) | Out-Null 
        Unblock-File -Path $global:outputExcel
    }
    Write-Debug "Closing Excel ..."
    if($null -ne $XL)
    {
        $XL.Quit() | Out-Null 
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsOma) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsRecommendations) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsAzurePriceList) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsAzureVmSkus) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wsAzureDiskSkus) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($wbOma) | Out-Null}catch{}
        try{[System.Runtime.Interopservices.Marshal]::ReleaseComObject($XL) | Out-Null}catch{}
        [System.GC]::Collect() | Out-Null 
        [System.GC]::WaitForPendingFinalizers() | Out-Null 
    }
}
}

######################################### Init global variables #########################################


$global:XlListObjectSourceType_xlSrcRange=1
$global:XlYesNoGuess_xlYes=1

[array]$global:awrDataAll=$null
$global:AWRRACReportTitle="WORKLOAD REPOSITORY REPORT (RAC)"
$global:AWRNormalReportTitle="WORKLOAD REPOSITORY report for"
$global:numProcessedFiles=0

$global:RecommendationPriority_BestPracticesOnly="Best Practices Only"
$global:RecommendationPriority_AllOthers="All Others"

$azureSizeStringRegExPattern="([A-Z])([A-Z])?([0-9]+)(\-[0-9]+)?([abdilmprst]*)(_[A-Z,0-9]+)?(_v[0-9]+)?(_Promo)?"
$global:azureSizeStringRegex = [regex]$azureSizeStringRegExPattern



######################################### MAIN #########################################
    if($Help -eq $true)
{
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) [OPTIONS]"
    Write-Host "OPTIONS:"
    Write-Host "   -h, Help          : Display this screen."
    Write-Host "   -SourceFolder     : Source folder that contains AWR reports in HTML format. Default is '.' (current directory)."
    Write-Host "   -NoAwr            : Creates an empty file so that you can manually enter vCPU, memory and disk requirements and generate recommendations."
    Write-Host "   -OutputFile       : Full path of the Excel file that will be created as output. Default is same name as SourceFolder directory name with XLSM extension under SourceFolder directory."
    Write-Host "   -TemplateFileName : Excel templatethat will be used for capacity estimations. Default is '.\template.xlsm'."
    Write-Host "   -AzureRegion      : Name of the Azure region to be used when generating Azure resource recommendations. Default is 'westus'."
    Write-Host "   -Debug            : Generates debug output."
    Write-Host ""
    Write-Host "$($MyInvocation.MyCommand.Name) -SourceFolder `"C:\AWR`" -AzureRegion `"westus`""
    Exit 0
}

if ($PSBoundParameters['Debug']) {
    $DebugPreference = 'Continue'
    
}

[datetime]$ScriptStartAt = Get-Date
Write-Debug "Starting..."
Write-Debug "DebugPreference=$DebugPreference"

# if ($PSVersionTable.PSVersion.Major -lt 6)
# {
#     Write-Host "PowerShell version 6 upwards is required. Your version is $($PSVersionTable.PSVersion)"
#     Write-Host "Install latest LTS release from: https://aka.ms/powershell-release?tag=lts"
#     Write-Host "Exiting."
#     Exit
# }

if ([bool](Get-Command -Name 'az' -ErrorAction SilentlyContinue) -eq $false) { #check if azure cli is installed
    Write-Host "Azure CLI is not installed."  -ForegroundColor Red
    Write-Host "Please install Azure CLI from https://aka.ms/installazurecliwindows" -ForegroundColor Red
    Write-Host "Then run 'az-login' and re-execute this script." -ForegroundColor Red
    Exit
}


if (-not (Test-Path $SourceFolder -PathType Container))
{
    Write-Host "Source folder not found: $SourceFolder" -ForegroundColor Red
    Write-Host "Exiting."
    Exit
}

if(-not $NoAwr.IsPresent)
{
    $src=Get-Item $sourceFolder
    $sourceFolder=$src.FullName

    if([string]::IsNullOrEmpty($OutputFile))
    {
        $global:outputExcel="$($src.FullName)\$($src.Name).xlsm"
    }
    else {
        if($OutputFile -notlike "*.xlsm")
        {
            $OutputFile = "$OutputFile.xlsm"
        }
        if(-not $OutputFile.Contains("\"))
        {
            $OutputFile = "$($src.FullName)\$OutputFile"
        }
        $global:outputExcel=$OutputFile
    }
}
else
{
    if([string]::IsNullOrEmpty($OutputFile))
    {
        $rnd=Get-Random -Minimum 1000 -Maximum 9999
        $global:outputExcel=".\OMAT-NoAwr-$rnd.xlsm"
    }
    else {
        if($OutputFile -notlike "*.xlsm")
        {
            $OutputFile = "$OutputFile.xlsm"
        }
        if(-not $OutputFile.Contains("\"))
        {
            $OutputFile = ".\$OutputFile"
        }
        $global:outputExcel=$OutputFile
    }
}

$azureAccountJson=az account show 2>$null
if($null -eq $azureAccountJson)
{
    Write-Host "You need to be logged on to Azure to run this script." -ForegroundColor Red
    Write-Host "Please run 'az login' first and rerun this script." -ForegroundColor Red
    Exit
}
else {
    $azureAccount = $azureAccountJson | ConvertFrom-Json
    Write-Host "Connected to subscription '$($azureAccount.name)' ($($azureAccount.id)) as '$($azureAccount.user.name)'"
}

$AzureRegion = $AzureRegion.ToLower()

$azureRegionFound=((az account list-locations 2>$null) | ConvertFrom-Json | Where-Object {$_.name -eq $AzureRegion})
if($null -eq $azureRegionFound)
{
    Write-Host "'$AzureRegion' is not a valid Azure region identifier or your current subscription '$($azureAccount.id)' does not have access to '$AzureRegion'." -ForegroundColor Red
    Exit
}
else {
    Write-Host "Using Azure region '$AzureRegion'"
}


if($NoAwr.IsPresent)
{
    Write-Host "No AWR files given. You will need to manually enter required values in the output Excel generated."
}
else
{
    Write-Host "Processing files from directory : $SourceFolder"
}

if (-not (Test-Path $TemplateFileName -PathType Leaf))
{
    throw "Template file not found: $TemplateFileName"
}
else
{
    $tmpfile=Get-Item $TemplateFileName
    Write-Host "Using template file             : $($tmpFile.FullName)"
}

if (Test-Path $global:outputExcel -PathType Leaf)
{
    if ($DebugPreference -eq "Continue")
    {
        Write-Host "Overwriting output file : $global:outputExcel"
        Remove-Item -LiteralPath $global:outputExcel
    }
    else {
        Write-Host "Output file already exists : $global:outputExcel" -ForegroundColor Red
        Write-Host "Exiting." -ForegroundColor Red
        Exit
    }
}

if (-not $NoAwr.IsPresent)
{
    Get-ChildItem -Path $sourceFolder -File -Filter *.html | ForEach-Object {ProcessAWRReport -awrReportFileName $_.FullName}
}
if($global:numProcessedFiles -gt 0 -or $NoAwr.IsPresent)
{
    ExportToExcel  | Out-Null
    if($NoAwr.IsPresent)
    {
        Write-Host "Created file `"$global:outputExcel`" with no AWR data, open the file and manually enter vCPU, memory and disk requirements in `"Azure Server Summary`" table." -ForegroundColor Green
    }
    else
    {
        Write-Host "Finished processing files from directory : $SourceFolder in $($($($(Get-Date) - $ScriptStartAt)).TotalSeconds) seconds" -ForegroundColor Green
        Write-Host "Open the Excel file `"$global:outputExcel`" to review recommendations." -ForegroundColor Green
    }
    Write-Host "Note macros are required to be enabled in Excel. See following link to enable macros: https://support.microsoft.com/en-us/office/enable-or-disable-macros-in-microsoft-365-files-12b036fd-d140-4e74-b45e-16fed1a7e5c6" -ForegroundColor Green
}
else {
    Write-Host "No AWR report files found in directory : $SourceFolder" -ForegroundColor Red
    Write-Host "If you would like to create an empty file and manually enter requirements, use -NoAwr switch to run the tool." -ForegroundColor Red
    Write-Host "Nothing to process. Exiting." -ForegroundColor Red
}


#global error handler
trap {
    Write-Host "Error occured." -ForegroundColor Red
    Write-Host ($_ | out-string) -ForegroundColor Red
    break
}


