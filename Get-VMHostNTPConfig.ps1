function Get-VMNTPConfig {
<#
.SYNOPSIS
  Creates a csv file with ESXi Server's NTP Config
.DESCRIPTION
  The function will export the ESXi server's NTP Config.
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Reporting
.PARAMETER Cluster
  Selects only ESXi server from this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.PARAMETER Filename
  Output filename
  If not specified, default is $($env:USERPROFILE)\ESXi_Pkgs_releases_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Get-VMNTPConfig -Filename “C:\ESXi_NTP.csv”
#>

[CmdletBinding()]
param(
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER,
    [Parameter(Mandatory = $False)]
    [Alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\VMNTPConfig_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)


Begin {
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
	$OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"
    $report = @()
} ### End Begin

Process {

    # If we do not get Cluster from Input, we take them all from vCenter
	If ( !$Cluster ) {
		$Cluster_to_process = (Get-Cluster | Select Name).Name | Sort}
	  else {
		$Cluster_to_process = $CLUSTER
	}
    
	foreach ( $Cluster in $Cluster_to_process ) {
	    $ClusterInfo = Get-Cluster $Cluster
        If ( $? -eq $false ) {
		    Write-Host "Error: Required Cluster $($Cluster) does not exist." -ForegroundColor Red
		    break
        }
        $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Sort Name | Select Name, ExtensionData
        foreach($vmhost in $ClusterHosts) {
            $HostConfig = “” | Select Cluster, HostName, NTPRunningStatus, NTPpolicy, TimeZone, NTPServer1, NTPServer2, NTPServer3, NTPServer4
            $HostConfig.Cluster = $Cluster
            $HostConfig.HostName = $vmhost.Name
            $ntpservice = $vmhost.ExtensionData.Config.service.Service | where -property “key” -match “ntpd”
            $HostConfig.NTPRunningStatus = $ntpservice.Running
            $HostConfig.NTPpolicy = $ntpservice.Policy
            $HostConfig.TimeZone = $vmhost.ExtensionData.Config.DateTimeInfo.TimeZone.Name
            $HostConfig.NTPServer1 = $($vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig.Server[0])
            $HostConfig.NTPServer2 = $($vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig.Server[1])
            $HostConfig.NTPServer3 = $($vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig.Server[2])
            $HostConfig.NTPServer4 = $($vmhost.ExtensionData.Config.DateTimeInfo.NtpConfig.Server[3])
            $report+=$HostConfig
        } ### Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process

End {
    Write-Host "Writing ESXi NTP info to file $($OUTPUTFILENAME)..."
    $report | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
    $report | FT -AutoSize
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU7/2lhDllyf+enktIEB1UynbN
# piagggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8w7K7ZvEbgMO
# mnet+82MVjFBXzQwDQYJKoZIhvcNAQEBBQAEggEAbA7z9R57n5fDmGI9nD2Dl8p9
# ilTYYTC7FTw5GQxapnvdZjTnh7HOaACpV7/nbhxxxfomUi+WZwdalu8GQzzg+XYr
# +3HuVmPyCfgbXnquRCa9uTRggr+EdcKiOvfrGBMelx9B/it0qAOl8SYCvxi8nT7J
# Q0QMjzDt1D2NKDaZhi49NqqbtBAcTcjmdSHFNAVYbb3Mojyk/a1F1fTqDp+sZAU0
# 0CGRc3evPCFO/3JvTG0O/FPVFqs1XjEzbYCuMRU9jBksQxdOlL2gxCX4PHrkDovi
# 0tEK+aM10RU8aE4mf1x2didFvZhtDOY0kmHoaqA0s14nkWfjiqO/e/qkEsyTwQ==
# SIG # End signature block
