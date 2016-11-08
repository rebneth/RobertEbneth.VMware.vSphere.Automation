function Get-VAAISettings {
  <#
.SYNOPSIS
  Get VMware vSphere ESXi Servers VAAI Settings
.DESCRIPTION
  Get VMware vSphere ESXi Servers VAAI Settings
.NOTES
  Release 1.0
  Robert Ebneth
  November, 8th, 2016
.LINK
  http://github.com/rebneth
.EXAMPLE
  Get-VAAISettings -Cluster <vSphere Cluster Name>
.EXAMPLE
  Get-Cluster | Get-VAAISettings
#>

	[CmdletBinding()]
	param(
	[Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
	HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
	[string]$CLUSTER
	)


Begin {
    if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Add-PSSnapin VMware.VimAutomation.Core
    }
    $report = @()
} ### End Begin

Process {

	$status = Get-Cluster $Cluster
    If ( $? -eq $false ) {
		Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		break
    }
    $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Sort Name | Select Name
    foreach ($ESXiHost in $ClusterHosts ) {
        $VAAISettings = "" | Select ESXiHost, VMFS3.HardwareAcceleratedLocking, DataMover.HardwareAcceleratedInit, DataMover.HardwareAcceleratedMove
        $VAAISettings.ESXiHost = $ESXiHost.Name
        $CurrentVAAISettings = Get-VMHost $ESXiHost.Name |Get-AdvancedSetting | Where { $_.Name -Like "*Accelerated*"} | Sort Name
        $VAAISettings."DataMover.HardwareAcceleratedInit" = $CurrentVAAISettings[0].Value
        $VAAISettings."DataMover.HardwareAcceleratedMove" = $CurrentVAAISettings[1].Value
        $VAAISettings."VMFS3.HardwareAcceleratedLocking" = $CurrentVAAISettings[2].Value
        $report += $VAAISettings
    }    
} ### End Process

End {
    $report | Format-Table -AutoSize
}

} ### End Function