function Set-VAAISettings {
  <#
.SYNOPSIS
  Set VMware vSphere ESXi Servers VAAI Settings
.DESCRIPTION
  Set VMware vSphere ESXi Servers VAAI Settings
.NOTES
  Release 1.0
  Robert Ebneth
  November, 8th, 2016
.LINK
  http://github.com/rebneth
.EXAMPLE
  Get-VAAISettings -Cluster <vSphere Cluster Name> -ATS 0 -INIT 0 -MOVE 0
.EXAMPLE
  Get-Cluster | Set-VAAISettings
#>

	[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
	param(
	[Parameter(Mandatory = $true, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
	HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
	[string]$CLUSTER,
    # For VAAI Parameters, value "0" means disable and value "1" means enable
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 1)]
    [ValidateRange(0,1)] 
	[Alias("ATS")]
	[string]$HardwareAcceleratedLocking = "1",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 2)]
    [ValidateRange(0,1)] 
	[Alias("INIT")]
	[string]$HardwareAcceleratedInit = "0",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 3)]
    [ValidateRange(0,1)] 
	[Alias("MOVE")]
	[string]$HardwareAcceleratedMove = "0"
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
        if ($PSCmdlet.ShouldProcess("$($ESXiHost.Name)", "Change ESXi VAAI Settings"))
            {Write-Host "Change ESXi VAAI Settings on Host $($ESXiHost.Name)"
            # VAAIVAR value 0 means disable value 1 means enable
            $result = Get-VMHost $ESXiHost.Name | Get-AdvancedSetting -Name "DataMover.HardwareAcceleratedInit" | Set-AdvancedSetting -Value $HardwareAcceleratedInit -Confirm:$false
            $result = Get-VMHost $ESXiHost.Name | Get-AdvancedSetting -Name "DataMover.HardwareAcceleratedMove" | Set-AdvancedSetting -Value $HardwareAcceleratedMove -Confirm:$false
            $result = Get-VMHost $ESXiHost.Name | Get-AdvancedSetting -Name "VMFS3.HardwareAcceleratedLocking" | Set-AdvancedSetting -Value $HardwareAcceleratedLocking -Confirm:$false    
            }
          else { Write-Host "Skipping Change VAAI Settings on ESXi Host $($ESXiHost.Name)"
        }
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