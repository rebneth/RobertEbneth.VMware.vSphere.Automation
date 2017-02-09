function Get-VAAISettings {
<#
.SYNOPSIS
  Get VMware vSphere ESXi Servers VAAI Settings
.DESCRIPTION
  Get VMware vSphere ESXi Servers VAAI Settings
.NOTES
  Release 1.1
  Robert Ebneth
  February, 9th
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
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
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUyGEsdTv+5ARwl5QAjlCGOkH
# eWugggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUQPDevMJoIJjc
# nfBAKIwiVXChOWIwDQYJKoZIhvcNAQEBBQAEggEAEqjeJeU4xrOLKWRqnHocQRAa
# JY3K1t4g9MqE5NTlAMP5Kazrj3/IFmZqygs/VoukP0f4g0RWedQ5lNPfHjv1yVaR
# coLcX/w8fo9KQBZR4Z5jVzjee5FBif9LpnKvup9J93Ez0kj6Z/NYOG6StgYz0CS0
# SEE5ZPPJBV/jQ8QQBACtNxSJsZ/JRI+wBSdaQ8Bx1mK7ff7aee59CUc7yr1FSc0e
# hqsxqdrlYbPFr4/WYz/Ar27qx/7L8+l27jmCrSKwVMV+Zjgbv2Pq7vKtKtcFlcXK
# jnOxCEWX57sGf93U4LXrvcIdThkTyLr+1tRzCq0cYdsOMMVtgKGQs0U7QQaBQQ==
# SIG # End signature block
