function Set-VAAISettings {
<#
.SYNOPSIS
  Set VMware vSphere ESXi Servers VAAI Settings
.DESCRIPTION
  Set VMware vSphere ESXi Servers VAAI Settings
.NOTES
  Release 1.1
  Robert Ebneth
  February, 9th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.EXAMPLE
  Get-VAAISettings -Cluster <vSphere Cluster Name> -ATS 0 -WRITESAME 0 -XCOPY 0
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
	[Alias("WRITESAME")]
	[string]$HardwareAcceleratedInit = "0",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false, Position = 3)]
    [ValidateRange(0,1)] 
	[Alias("XCOPY")]
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
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU+8hpVpRMOTbQe5WXAck/G088
# zRCgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUmRZh2K+3IhMA
# Efq925k/Z7UCGcwwDQYJKoZIhvcNAQEBBQAEggEAO5iQSrz2jn4/tFzvYaYQXLal
# RCVlBFc1VA0zMtbBwHAKFxVjpg9vSu+u9zDWfioS0ILTkNCdoBL0ZnKdF1uszCcS
# gCrjggG9lCKKJmr2rjMQcT9y2XoWldB5fR3jq7xY5MnHmRAcbVQdEiIrWzK0e7F2
# c+i6DDN/0AORg72RvDdHLAEPii52bD+k0o8H4UPvsO1TfXHZnAJ/F2rMBAgzwnx2
# lmLDx6ch4ADUKRtFuGtxk+LbN+2mk6lvOPYO/IihdEAVwjN5/8rOHgYfxeocMwcD
# TZSVTuWVbgkMkeU4wLupJydDfFhnQjCHi4qxlyQwLIzsWHCbFm+SnW4Xy17xJQ==
# SIG # End signature block
