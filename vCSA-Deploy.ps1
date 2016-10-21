######################################################################################################
##
## Deploy vCSA6 with embedded PSC and Postgres DB using vCSA Deploy
## using Powershell CustomObject / Json File 
## For details see Command-Line Deployment and Upgrade of VMware vCenter Server Appliance 6.0 Update 2
## http://www.vmware.com/techpapers/2016/command-line-deployment-and-upgrade-of-vmware-vcen-10528.html
##
## Release 1.0.0
## Date: 2016/10/05
##
## by Robert Ebneth
##
## ChangeLog:
## 1.0.0.0 Initial Release
##
######################################################################################################

# Download VCSA ISO Image from vmware.com and mount this ISO File to the following drive letter:
$ISOLoc="V:"
# Location of the temporary json configuration file 
$UpdatedConfig = "$($env:LOCALAPPDATA)\Temp\configuration.json"

# This is for testing purpose:
#$ConfigLoc = "$PSScriptRoot\embedded_vCSA_on_ESXi.json"
$ConfigLoc = "$($ISOLoc)\vcsa-cli-installer\templates\install\embedded_vCSA_on_ESXi.json"
$Installer = "$($ISOLoc)\vcsa-cli-installer\win32\vcsa-deploy.exe"
if ((Test-Path $ConfigLoc) -eq $false)
	{Write-Error "$ConfigLoc not found"; break}
if ((Test-Path $Installer) -eq $false)
	{Write-Error "$Installer not found"; break}

# Load Json template for VCSA with embedded PSC Deployment from ISO image
$json = (Get-Content -Raw $ConfigLoc) | ConvertFrom-Json

# Comment
$json.'__comments' = "Json based cfg to deploy a vCenter Server with an embedded Platform Services Controller to an ESXi host at DB Rent GmbH."

# Destination ESXi Server
$json.'target.vcsa'.esx.hostname = "xxxxxx.yyyy.zzzz.dddd"
$json.'target.vcsa'.esx.username = "root"
$json.'target.vcsa'.esx.password = "VMw@re123"
$json.'target.vcsa'.esx.datastore = "xxxxxxxxxxx-RZS-GRP01-Volume02_SATA_10TB"

# vCenter Appliance
# set option 'size=medium' with embedded PSC
$json.'target.vcsa'.appliance.'name' = "vcenter001-betrieb-prod"
$json.'target.vcsa'.appliance.'deployment.option' = "medium"
$json.'target.vcsa'.appliance.'deployment.network' = "VM-Network"
$json.'target.vcsa'.appliance.'thin.disk.mode' = $false
$json.'target.vcsa'.os.password = "VMw@re123"
$json.'target.vcsa'.os.'ssh.enable' = $true
# As there is no NTP setting in the template, we have to define a new node
$json.'target.vcsa'.os | add-member -Name 'time.tools-sync' -Value $true -MemberType NoteProperty
#$json.'target.vcsa'.os | add-member -Name 'ntp.servers' -Value "ntp01.hal.dbrent.net" -MemberType NoteProperty

# vCenter Appliance Networking
$json.'target.vcsa'.network.'ip.family' = "ipv4"
$json.'target.vcsa'.network.'mode' = "static"
$json.'target.vcsa'.network.'ip' = "11.22.33.44"
$json.'target.vcsa'.network.'hostname' = "vcenter001-betrieb-prod.domain"
$json.'target.vcsa'.network.'prefix' = "22"
$json.'target.vcsa'.network.'gateway' = "11.22.33.44"
$json.'target.vcsa'.network.'dns.servers' = "222.333.444.555"

# Database connection (This is not included in template json file of VC6.0 U2)
$newObjectNode = New-Object PSObject
$newObjectNode | Add-Member -type NoteProperty -name type -value "embedded"
$json.'target.vcsa' | add-member -Type NoteProperty -Name 'database' -value $newObjectNode 

# SSO
$json.'target.vcsa'.sso.'password' = "VMw@re123"
$json.'target.vcsa'.sso.'domain-name' = "vsphere6.local"
$json.'target.vcsa'.sso.'site-name' = "db"

# Run installation
$json | ConvertTo-Json | Set-Content -Path "$UpdatedConfig"
Invoke-Expression "$installer --accept-eula --verify-only -v $UpdatedConfig"
if ( $? -eq "0" ) {
    Write-Host "Cleanup: Removing Json File $UpdatedConfig"
    Remove-Item $UpdatedConfig }
  else { 
    Write-Host "Json File $UpdatedConfig will be NOT DELETED"}
