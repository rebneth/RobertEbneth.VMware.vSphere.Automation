function Set-VMHostiSCSISettings {
<#
.SYNOPSIS
  PowerCLI Script to Update iSCSI Software Initiator Settings on ESXi Hosts
.DESCRIPTION
  PowerCLI Script to Update iSCSI Software Initiator Settings on ESXi Hosts
  The desired destination configuration is applied. That means, existing
  iSCSI Target Bindings, that were not needed anymore, will be deleted.
  New iSCSI Target Bindings for the ESXi Host will be added.
  PowerCLI Session must be connected to vCenter Server using Connect-VIServer
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER Name
  Name VMHost
.PARAMETER targets
  allows the following Syntaxes
  "10.202.1.101", "10.202.1.103", "10.202.2.102"
  and in one String seperated by , ; or ' ':
  "192.168.1.1,192.168.1.2; 10.10.1.1 1"
.PARAMETER DelayedAck
  Default: false
.PARAMETER NoopTimeout
  Default: 30
.PARAMETER LoginTimeout
  Default: 60
.EXAMPLE
  Get-VMhost <ESXiHostname> | Set-VMHostiSCSISettings -targets 1.1.1.1, 2.2.2.2 [ -confirm:$false ]
.EXAMPLE
  Get-Cluster | Get-VMhost | Sort Name | Set-VMHostiSCSISettings -targets 1.1.1.1, 2.2.2.2
 #>
[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
param(
	[Parameter(Mandatory = $True,
	ValueFromPipeline=$True,
	ValueFromPipelineByPropertyName=$true,
	HelpMessage = "Enter Name of ESXi Host")]
	[string]$Name,
	[Parameter(Mandatory = $True,
	ValueFromPipeline=$False,
	HelpMessage = "Enter iSCSI Target(s)")]
	[string[]]$targets,
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 2)] 
	[Alias("d")]
	[String]$DelayedAck = "false",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 3)]
	[ValidateRange(0,30)] 
	[Alias("n")]
	[int]$NoopTimeout = "30",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 4)]
	[ValidateRange(0,60)] 
	[Alias("l")]
	[int]$LoginTimeout = "60"
)

Begin {
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
}

Process {
    # We have to split multiple IP-Adresses separated by ; , or ' '
    $targets = $targets.split(",")
    $targets = $targets.split(";")
    $targets = $targets.trim()
    $targets = $targets.split(" ")
    $targets = $targets.trim()
    # We have to check the Vaildation of each IP-Address
    foreach ($target in $targets) {
        $IPvalid = [Bool]($target -as [IPAddress])
        If ( $IPvalid -eq $False ) { Throw "Invalid IP-Adress: $target" }
    } ### End foreach

    # Within this script we use $VMHost instead of $Name
    $VMHost = $Name
    # Check/Enable Software iSCSI Adapter on each host
    $SoftwareIScsiEnabled = Get-VMHostStorage -VMHost $VMHost
    If ( !$? ) { break}
    if ( $SoftwareIScsiEnabled -eq $false ) {
        Write-Host "Enabling Software iSCSI Adapter on $VMHost ..."
        Get-VMHostStorage -VMHost $VMHost | Set-VMHostStorage -SoftwareIScsiEnabled $True
        If ( $? ) { Write-Host "Software iSCSI could not be enabled. Break." -ForegroundColor Red }
        # Just a sleep to wait for the adapter to load
		Start-Sleep -Seconds 10 
        }
      else { Write-Host "Software iSCSI on host $VMHost is already enabled." -ForegroundColor Green }
    $hba = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}
    If ( $? -eq $false ) { break }

    # Remove of existing iSCSI Target Bindings that are not listed in the '-targets' list 
    $CurrentISCSITargets = Get-IScsiHbaTarget -IScsiHba $hba -Type Send
    If ( !$? ) { break }
    foreach ( $existingtarget in $CurrentISCSITargets ) {
            $TargetExists = $false
            foreach ($target in $targets){
                if ( $($existingtarget.Address) -eq $target ) {
                $TargetExists = $true; break
                }                
            }
            If ($TargetExists -eq $false) {
                if ($PSCmdlet.ShouldProcess("$($VMHost)", "Remove iSCSI target-binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"))
                    { Write-Host "Removing existing iSCSI Target $($existingtarget.Address):$($existingtarget.Port) from Host $VMHost $($hba.Device)..."
                    Get-IScsiHbaTarget -IScsiHba $hba -Address "$($existingtarget.Address):$($existingtarget.Port)" -Type Send | Remove-IScsiHbaTarget -Confirm:$false | Out-Null}
                  else
                    { Write-Host "Skipping removal of iSCSI Target Binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"
                } ### End if else 
            }
        } ### End foreach

        # Try to add iSCSI Targets
        foreach($target in $targets){
            if(Get-IScsiHbaTarget -IScsiHba $hba -Type Send | Where {$_.Address -cmatch $target}){
                Write-Host "The iSCSI target $target already exists on $VMHost $($hba.Device)" -ForegroundColor Green
            }
            else{
                Write-Host "The iSCSI target $target doesn't exist on $VMHost $($hba.Device)" -ForegroundColor Yellow
                if ($PSCmdlet.ShouldProcess("$($VMHost)", "Creating iSCSI Target Binding $($target):$($existingtarget.Port) for adapter $($hba.Device)"))
                    { Write-Host "Creating iSCSI target $target" -ForegroundColor Yellow
                    New-IScsiHbaTarget -IScsiHba $hba -Address $target | Out-Null
                    If ( $? ) { Write-Host "iSCSI target $target successfully added." -ForegroundColor Green }
                  else { Write-Host "Skipping creating of iSCSI Target Binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"
                } 
            }                
        } ### End foreach
    } ### End foreach

    ###
    ### At this point we Check/set important iSCSI params according Best practices
    ###
    ### $esxcli.iscsi.adapter.set(string adapter, string alias, string name)
    $esxcli = Get-EsxCli -VMHost $VMHost
    $iscsi_hba = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}
    $AdvancedOptions = $iscsi_hba.ExtensionData.AdvancedOptions
    $Current_DelayedAck = $AdvancedOptions | ?{$_.Key -eq "DelayedAck" } | Select-Object -ExpandProperty Value
	$Current_LoginTimeout = $AdvancedOptions | ?{$_.Key -eq "LoginTimeout" } | Select-Object -ExpandProperty Value
	$Current_NoopTimeout = $AdvancedOptions | ?{$_.Key -eq "NoopTimeout" } | Select-Object -ExpandProperty Value
    if ( "$Current_DelayedAck" -notLike "$DelayedAck" ) { 
        write-Host "Setting ESXi Host $VMHost iSCSI SW Adapter $hba Advanced Parameter DelayedAck to $false"
        $esxcli.iscsi.adapter.param.set($iscsi_hba, $null, 'DelayedAck', "$DelayedAck")}
      else
        { Write-Host "iSCSI HBA Advanced Parameter DelayedAck already set to $($DelayedAck). Nothing Changed." -ForegroundColor Green }
    if ( "$Current_NoopTimeout" -notLike "$NoopTimeout" ) { 
        write-Host "Setting ESXi Host $VMHost iSCSI SW Adapter $hba Advanced Parameter NoopTimeout to $NoopTimeout"
        $esxcli.iscsi.adapter.param.set($iscsi_hba, $false, 'NoopTimeout', "$NoopTimeout")}
      else
        { Write-Host "iSCSI HBA Advanced Parameter NoopTimeout already set to $($NoopTimeout). Nothing Changed." -ForegroundColor Green }

    if ( "$Current_LoginTimeout" -notLike "$LoginTimeout" ) { 
        write-Host "Setting ESXi Host $VMHost iSCSI SW Adapter $hba Advanced Parameter LoginTimeout to $LoginTimeout"
        $esxcli.iscsi.adapter.param.set($iscsi_hba, $false, 'LoginTimeout', "$LoginTimeout")}
      else
        { Write-Host "iSCSI HBA Advanced Parameter LoginTimeout already set to $($LoginTimeout). Nothing Changed." -ForegroundColor Green }
  
    ###
    ### At the end we do a Rescan on all HBAs and then a Rescan for VMFS volumes
    ###
    Write-Host "Rescan all HBAs on host $VMHost"
    Get-VMHostStorage -VMHost $VMHost -RescanAllHba | Out-Null
	Write-Host "Rescan VMFS on host $VMHost"
    Get-VMHostStorage -VMHost $VMHost -RescanVmfs | Out-Null

  } ### End Process

} ### End Function

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUVpywg+sxFCbmu94NY+aNvfD5
# Ci2gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
# AQUFADApMScwJQYDVQQDDB5Sb2JlcnRFYm5ldGhJVFN5c3RlbUNvbnN1bHRpbmcw
# HhcNMTcwMjA0MTI0NjQ5WhcNMjIwMjA1MTI0NjQ5WjApMScwJQYDVQQDDB5Sb2Jl
# cnRFYm5ldGhJVFN5c3RlbUNvbnN1bHRpbmcwggEiMA0GCSqGSIb3DQEBAQUAA4IB
# DwAwggEKAoIBAQCdqdh2MLNnST7h2crQ7CeJG9zXfPv14TF5v/ZaO8yLmYkJVsz1
# tBFU5E1aWhTM/fk0bQo0Qa4xt7OtcJOXf83RgoFvo4Or2ab+pKSy3dy8GQ5sFpOt
# NsvLECxycUV/X/qpmOF4P5f4kHlWisr9R6xs1Svf9ToktE82VXQ/jgEoiAvmUuio
# bLLpx7/i6ii4dkMdT+y7eE7fhVsfvS1FqDLStB7xyNMRDlGiITN8kh9kE63bMQ1P
# yaCBpDegi/wIFdsgoSMki3iEBkiyF+5TklatPh25XY7x3hCiQbgs64ElDrjv4k/e
# WJKyiow3jmtzWdD+xQJKT/eqND5jHF9VMqLNAgMBAAGjRjBEMBMGA1UdJQQMMAoG
# CCsGAQUFBwMDMA4GA1UdDwEB/wQEAwIHgDAdBgNVHQ4EFgQUXJLKHJBzYZdTDg9Z
# QMC1/OLMbxUwDQYJKoZIhvcNAQEFBQADggEBAGcRyu0x3vL01a2+GYU1n2KGuef/
# 5jhbgXaYCDm0HNnwVcA6f1vEgFqkh4P03/7kYag9GZRL21l25Lo/plPqgnPjcYwj
# 5YFzcZaCi+NILzCLUIWUtJR1Z2jxlOlYcXyiGCjzgEnfu3fdJLDNI6RffnInnBpZ
# WdEI8F6HnkXHDBfmNIU+Tn1znURXBf3qzmUFsg1mr5IDrF75E27v4SZC7HMEbAmh
# 107gq05QGvADv38WcltjK1usKRxIyleipWjAgAoFd0OtrI6FIto5OwwqJxHR/wV7
# rgJ3xDQYC7g6DP6F0xYxqPdMAr4FYZ0ADc2WsIEKMIq//Qg0rN1WxBCJC/QxggHe
# MIIB2gIBATA9MCkxJzAlBgNVBAMMHlJvYmVydEVibmV0aElUU3lzdGVtQ29uc3Vs
# dGluZwIQPWSBWJqOxopPvpSTqq3wczAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIB
# DDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEE
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUd5GgCRpkIu2/
# v59CMOAN263H8KswDQYJKoZIhvcNAQEBBQAEggEAglQik2H4sXUAS2T7rr5rg1Vm
# /KBjJzi1vegHJJ7TQupg+d7pChKeu+p0koPluGvdLHQWZRiVXPV612feZH7vSitM
# UHXkMhZNP4JFzD7PpiIbj9BwtcDfZVRqMQ0GWCB7wJ8N4ml9kd5pvB9o4iwXhNV4
# fKbCweriusihRoRPwIFmJIqM89MulIruMevcoO6wk4O/6IWjMklbwFCcp5iYbct2
# uJT5ByF7CpBXSYPhVLRNU5Li51lIecrZKKmUiTrh6cEgFJv+PcNlJ83TPFlujfD2
# OC/z1pd9lqThruUOn3H7T0HbgwOCSGKeyUusFHTMVs6ZufOFeRsw82h9RZjlog==
# SIG # End signature block
