<#
.SYNOPSIS
  Export vCenter items to re-create environment after fresh vCenter installation
.DESCRIPTION
  This script exports vCenter items to re-create environment after a fresh vCenter installation
.NOTES
  This Script contains Code from the Book VMware vSphere PowerCLI Reference, 2nd Edition
  by Luc Dekens, Jonathan Medd, Glenn Sizemore, Brian Graf, Andrew Sulivan and Matt Boren
  Sybex, ISBN 978-1-118-92511-9
  Code is available from http://www.wiley.com/go/vmwarevspherepowercli2e
  
  For Backup the VMware Cluster's DRS Rule Set, we use the Modules DRSRules and DRSRuleUtil
  that is available from https://github.com/PowerCLIGoodies/DRSRule/archive/Latest.zip

  Enhancements (e.g. Backup vCenter Resoource Pools, Backup datastore Cluster etc.) by Robert Ebneth
  Halle, Germany, October, 20th, 2016

  Requires Powershell Module PowerCLIReference.vCenter.Item.export
.EXAMPLE
  Export_vCenter_Items.ps1
#>

# Add personal Powershell Module Path to $PSPath environment
$MODULE_PATH = "D:\Infos\Tools\Scripting\Powershell\VMware\PS Modules Robert"
$PATH_FOUND = $false
foreach ( $MPATH in ([Environment]::GetEnvironmentVariable("PSModulePath") -split ";")) {
    # we need to make sure, that there are no leading or ending 'blank' sign to compare right
    $MPATH = $MPATH.Trim()
    if ( "$MPATH" -eq "$MODULE_PATH" ) { $PATH_FOUND = $true; break }
} 
If ( $PATH_FOUND -eq $false ) {
    $CurrentPSModulePath = [Environment]::GetEnvironmentVariable("PSModulePath")
    $CurrentPSModulePath += ";$MODULE_PATH"
    [Environment]::SetEnvironmentVariable("PSModulePath",$CurrentPSModulePath)   
    }
#$env:PSModulePath

# Load required functions from PS Script module
# Adding PowerCLI core snapin
if (!(get-pssnapin -name VMware.VimAutomation.Core -erroraction silentlycontinue)) {
	add-pssnapin VMware.VimAutomation.Core
}
# Adding PSModules that are required and own composed 
Remove-Module RobertEbneth.VMware.vSphere.Automation -EA 0
Import-Module "$MODULE_PATH\RobertEbneth.VMware.vSphere.Automation\RobertEbneth.VMware.vSphere.Automation.psd1" -Verbose
if (-not $?) { break}
# Adding PSModules that are required but Code from other
Remove-Module PowerCLIReference.vCenter.Deployment -EA 0
Import-Module "D:\Infos\Tools\Scripting\Powershell\VMware\PS Module PowerCLIReference\PowerCLIReference.vCenter.Deployment\PowerCLIReference.vCenter.Deployment.psd1" -Verbose
if (-not $?) { break}
# Adding PSModules that are required but Code from other
Remove-Module DRSRuleUtil -EA 0
Import-Module "D:\Infos\Tools\Scripting\Powershell\VMware\PS Modules Sonstige\DRSRule-Latest\DRSRuleUtil.psd1" -Verbose
if (-not $?) { break}
Remove-Module DRSRule -EA 0
Import-Module "D:\Infos\Tools\Scripting\Powershell\VMware\PS Modules Sonstige\DRSRule-Latest\DRSRule.psd1" -Verbose
if (-not $?) { break}

# This is for debugging: Get-Command -module vCenter_DR_functions -verb *
$PsIse.CurrentFile.Editor.ToggleOutliningExpansion()

# Include GlobalVariables and validate settings (at the moment just check they exist)
. "$($PSScriptRoot)\GlobalVariables.ps1"
if (-not $?) { break}
# We need a WORK_DIR for Placing the Backup data files
if (!$WORK_DIR -eq $True) { $WORK_DIR = $PSScriptRoot}

# xml and csv outputfiles
# the DRS Scripts use json files which is handled by ittself
$FOLDERFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_folder_structure.xml"
$DCOBJECTSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_dcobjects.xml"
$CLUSTERSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_clusters.xml"
$ROLESFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_roles.xml"
$PERMISSIONSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_permissions.xml"
$PERMISSIONSCSVFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_permissions.csv"
$VMLOCATIONSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_vm_locations.xml"
$VMHOSTSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_hosts.xml"
$BLUEFOLDERSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_BlueFolders.csv"
$YELLOWFOLDERSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_YellowFolders.csv"
$VMFOLDERPATHFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_vm_folderpath.csv"
$DSCLUSTERSFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_dsclusters.xml"
$DATASTORESFILENAME = "$($WORK_DIR)\$($FILEPREFIX)_dslocation.csv"
$ALLOUTPUTFILES="$FOLDERFILENAME","$DCOBJECTSFILENAME","$CLUSTERSFILENAME","$ROLESFILENAME","$PERMISSIONSFILENAME","$VMLOCATIONSFILENAME","$VMHOSTSFILENAME"

# Find the VI Server and port from the global settings file
$VIServer = ($Server -Split ":")[0]
if (($server -split ":")[1]) {
   $port = ($server -split ":")[1]
}
else
{
   $port = 443
}

$OpenConnection = $global:DefaultVIServers | where { $_.Name -eq $VIServer }
if($OpenConnection.IsConnected) {
	Write-Host $pLang.connReuse
	$VIConnection = $OpenConnection
} else {
	Write-Host $pLang.connOpen
	$VIConnection = Connect-VIServer -Server $VIServer -Port $Port}

if (-not $VIConnection.IsConnected) {
	Write-Error $pLang.connError
    break
}

# delete any existing output file
foreach ($OUTPUTFILENAME in $ALLOUTPUTFILES) {
    Set-Variable -name OUTPUTFILE -value $OUTPUTFILENAME
    if ((Test-Path $OUTPUTFILE) -eq $True)
	    {Remove-Item $OUTPUTFILE}
    New-Item $OUTPUTFILE -type file | out-null
}

Write-Host "#########################################"
Write-Host "# Export vCenter Server Inventory Items #"
Write-Host "#########################################"

###
### Step #1: Save vCenter Folder Structure
### from PowerCLI Book
###
$folderStructure = @{}
Get-Folder -NoRecursion | Get-FolderStructure | %{
    $folderStructure[$_.Name] = $_.Children
    }
Get-Datacenter | Get-FolderStructure | %{ 
    $folderStructure[$_.Name] = $_.Children
    }
Write-Host "Creating $($FOLDERFILENAME)..."
$folderStructure | Export-Clixml $FOLDERFILENAME

###
### Step #2: Save vCenter Datacenter Objects
### from PowerCLI Book
###
$datacenters = @()
ForEach ($dc in Get-Datacenter) {
    $dc | Add-Member -MemberType NoteProperty -Name VIPath -Value ($dc | Get-View | Get-VIPath)
    $datacenters += $dc
}
Write-Host "Creating $($DCOBJECTSFILENAME)..."
$datacenters | Export-Clixml $DCOBJECTSFILENAME

###
### Step #3: Save Host Clusters
### from PowerCLI Book
###
$clusters = @()
ForEach ($dc in Get-Datacenter) {
    ForEach ($cluster in ($dc | Get-Cluster | Sort Name)) {
        $cluster | Add-Member -MemberType NoteProperty -Name Datacenter -Value $dc.Name
        $cluster | Add-Member -MemberType NoteProperty -Name VIPath -Value ($cluster | Get-View | Get-VIPath)
        $clusters += $cluster
    }
}
Write-Host "Creating $($CLUSTERSFILENAME)..."
$clusters | Export-Clixml $CLUSTERSFILENAME

###
### Step #4: Save DatastoreClusters
### by Robert Ebneth
###
$dsclusters = @()
$DataStoreLocations = @()
# We need a temporary table for the relationship Dastastore Name to DatastoreId
$AllDatastores = Get-Datastore |Select Name, Id
ForEach ($dc in Get-Datacenter) {
    ForEach ($dscluster in ($dc | Get-DatastoreCluster | Sort Name)) {
        $dscluster | Add-Member -MemberType NoteProperty -Name Datacenter -Value $dc.Name
        $dscluster | Add-Member -MemberType NoteProperty -Name VIPath -Value ($dscluster | Get-View | Get-VIPath)
        # here we export the DatastoreCluster Properties
		$dsclusters += $dscluster
        foreach ($DS in $dscluster.ExtensionData.ChildEntity ) {
			# Now we export the Datastores related to this DS Cluster by Name (!)
            $DSL = "" | Select DataStoreCluster, DataStoreName
            $DSL.DataStoreCluster = $dscluster.Name
            $Filter = $AllDatastores | Where { $_.Id -eq $DS }
            $DSL.DataStoreName = $Filter.Name
            $DataStoreLocations += $DSL
        }
    }
}
Write-Host "Creating $($DSCLUSTERSFILENAME)..."
$dsclusters | Export-Clixml $DSCLUSTERSFILENAME -NoTypeInformation
Write-Host "Creating $($DATASTORESFILENAME)..."
$DataStoreLocations | Export-Csv -Delimiter ";" $DATASTORESFILENAME -NoTypeInformation

###
### Step #5: Save Roles
###
Write-Host "Creating $($ROLESFILENAME)..."
Get-VIRole | Where-Object {-not $_.IsSystem} | Export-Clixml $ROLESFILENAME

###
### Step #6: Save Permissions
### from PowerCLI Book
###
$permissions=@()
ForEach ($permission in Get-VIPermission) {
    $permission | Add-Member -MemberType NoteProperty -Name EntityType -Value (Get-View $permission.EntityID).GetType().Name
    $permissions += $permission
}
Write-Host "Creating $($PERMISSIONSFILENAME)..."
$permissions | Export-Clixml $PERMISSIONSFILENAME

Export-PermissionsToCsv -Filename $PERMISSIONSCSVFILENAME

###
### Step #7: Save Resource Pools and VM Resource Pool Locations
### by Robert Ebneth
###
Get-Cluster | Export-vCenterResourcePools

###
### Step #8: Save DRS Rule Set ( Requires Module DRSRule and DRSRuleUtil by LucD )
### from GitHub
###
foreach ($cluster in Get-Cluster ) {
    Export-DrsRule -Cluster $cluster -Path DBRENT_$($cluster.Name)_drs_rules.json
}


###
### Step #9: Save VM Locations
### from PowerCLI Book
$vmLocations = @()
ForEach ($vm in Get-VM | Sort Name) {
    $vm | Add-Member -MemberType NoteProperty -Name Datacenter -Value $($vm | Get-Datacenter).Name
    $vm | Add-Member -MemberType NoteProperty -Name VIPath -Value $($vm | Get-View | Get-VIPath)
    $vmLocations += $vm
}
Write-Host "Creating $($VMLOCATIONSFILENAME)..."
$vmLocations | Export-Clixml $VMLOCATIONSFILENAME

# Optional from chapter 1, exporting VM Folder Structure to csv
Write-Host "Creating $($BLUEFOLDERSFILENAME)..."
Export-Folders “Blue” (Get-Datacenter).Name $BLUEFOLDERSFILENAME
Write-Host "Creating $($YELLOWFOLDERSFILENAME)..."
Export-Folders “Yellow” (Get-Datacenter).Name $YELLOWFOLDERSFILENAME
Write-Host "Creating $($VMFOLDERPATHFILENAME)..."
Export-VMLocation (Get-Datacenter).Name $VMFOLDERPATHFILENAME

###
### Step 10: Save Templates
###
### This part is still missing

###
### Step #11: Save Hosts
### from PowerCLI Book
###
$vmHosts = @()
ForEach ($dc in Get-Datacenter) {
    ForEach ($machine in ($dc | Get-VMHost |Sort Name)) {
        $machine | Add-Member -MemberType NoteProperty -Name Datacenter -Value $dc -force
        $machine | Add-Member -MemberType NoteProperty -Name Cluster -Value $($machine | Get-Cluster).Name -force
        if ( -not $_.Cluster) {
            $machine | Add-Member -MemberType NoteProperty -Name VIPath -Value $($machine | Get-View | Get-VIPath)
        }
        $vmHosts += $machine
    }
}
#Write-Host "Saving data from ESXi Host $($machine.Name)..."
Write-Host "Creating $($VMHOSTSFILENAME)..."
$vmHosts | Export-Clixml $VMHOSTSFILENAME

###
### Step #12: Save Tags
### from PowerCLI Book
Write-Host "Creating $($WORK_DIR)\$($FILEPREFIX)_exportedtags.xml ..."
Export-Tag -path "$($WORK_DIR)\$($FILEPREFIX)_exportedtags.xml"
Write-Host "Creating $($WORK_DIR)\$($FILEPREFIX)_TagRelationship.csv ..."
Export-TagRelationship "$($WORK_DIR)\$($FILEPREFIX)_TagRelationship.csv"

###
### Step #13: Save vCenter Advanced Settings
### by Robert Ebneth
###
$ADVANCEDSETTINGSFILE = "$($WORK_DIR)\$($FILEPREFIX)_Advanced_Settings.xml"
Write-Host "Exporting vCenter Advanced Settings to $($ADVANCEDSETTINGSFILE)..."
Get-AdvancedSetting -Entity $VIServer | Select Name, Value, Description | Export-Clixml $ADVANCEDSETTINGSFILE

#Add the Alarm Definitions to be configured here
$alarms = @("Datastore usage on disk", "vSphere HA host status", "vSphere HA failover in progress", "Host connection and power state", "Host error", "Host CPU usage", "Host memory usage")
#Configure the Email Action on the defined list of alarms
foreach ($alarm in $alarms) {
  Get-AlarmDefinition -Name $alarm | %{
     #Remove Email Action if already configured
     $_ | Get-AlarmAction
     }
}

# Unload Powershell Modules
# Remove-Module -EA 0

# Disconnect any existing vCenter Connections
#If ($VIConnection) {
#  $VIConnection | Disconnect-VIServer -Confirm:$false
#}