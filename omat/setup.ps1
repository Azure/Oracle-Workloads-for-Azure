Write-Host "Downloading omat.ps1"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Azure/Oracle-Workloads-for-Azure/master/omat/omat.ps1 -OutFile .\omat.ps1
Write-Host "Unblocking omat.ps1"
Unblock-File -Path .\omat.ps1
Write-Host "Downloading template.xlsm"
Invoke-WebRequest -Uri https://raw.githubusercontent.com/Azure/Oracle-Workloads-for-Azure/master/omat/template.xlsm -OutFile .\template.xlsm
Unblock-File -Path .\template.xlsm

$azCmd=Get-Command -Name 'az' -ErrorAction SilentlyContinue 

if($null -eq $azCmd) {
    Write-Host "Azure CLI is not found."
    Write-Host "Downloading Azure CLI."
    Invoke-WebRequest -Uri https://aka.ms/installazurecliwindows -OutFile .\AzureCLI.msi
    Write-Host "Installing Azure CLI."
    Start-Process msiexec.exe -Wait -ArgumentList '/I AzureCLI.msi /quiet'
    Write-Host "Cleanup Azure CLI install files."
    Remove-Item .\AzureCLI.msi
}


