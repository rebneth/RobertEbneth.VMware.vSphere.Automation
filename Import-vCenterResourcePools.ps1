Function Import-vCenterResourcePools {
<#
.SYNOPSIS
  Import Resource Pools for vSphere Cluster
.DESCRIPTION
  Import Resource Pools for vSphere Cluster
.NOTES
  Release 1.1
  Robert Ebneth
  February, 9th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.EXAMPLE
  Import-vCenterResourcePools -Cluster <vSphere Cluster name>
.EXAMPLE
  Get-Cluster | Import-vCenterResourcePools
#>


[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
    HelpMessage = "Enter Name of vCenter Cluster")]
    [string]$Cluster,
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
    HelpMessage = "Overwrite DRS Settings if Resource Pool exists?")]
    [Alias("f")]
	[switch]$Force = $false
	[Parameter(Mandatory = $True, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false, Position = 1,
	HelpMessage = "Enter the path to the xml input file")]
	[string]$FILENAME
)

Begin {
	#$OUTPUTFILENAME = CheckFilePathAndCreate VMPowerState.csv $FILENAME
    $AllResourcePools = @()
    $AllVMsResourcePoolPath = @()

    Write-Host "#####################################################"
    Write-Host "# Import vCenter Resource Pools and their Structure #"
    Write-Host "#####################################################"
    $FILENAME = "$($PSScriptRoot)\vCenter_ResourcePools.xml"
    if ((Test-Path $FILENAME) -eq $False)
		{ Write-Error "Missing Input File: $FILENAME"; break}
	$BackupResourcePools = Import-Clixml $FILENAME	
	}


Process {
    $ClusterName = $Cluster
    $AllResourcePools = $BackupResourcePools | Where { $_.Path -Like "\$($ClusterName)*" }

foreach ( $RP in $AllResourcePools ) {
    $ResourcePoolHirarchie = $RP.Path.Split('\')
    $ClusterName = $ResourcePoolHirarchie[1]
    # We check if there is a corresponding vCenter Cluster
    $status = Get-Cluster -Name $ClusterName | Out-Null
    If ( $? -ne $true ) {
        Write-Error "vCenter Cluster $ClusterName does not exist. Ressource Pool could not be created."
        break
    }
    # This works for 10 Levels
    $LocResourcePool = Get-Cluster -Name $ClusterName | Get-ResourcePool | Where { $_.Name -eq "Resources" }
    for ( $i=2; $i -le 10; $i++ ) {
        # Do we have upper Resource Pools for this Resoure Pool ? Then this field is not empty and contains name of upper Resource Pools
        if ( $ResourcePoolHirarchie[$i] ) {
            # We have to check the persistence of the upper resource pools
            Write-Verbose $RP.Properties.Name            
            Write-Verbose "Checking Upper Ressource Pool $($ResourcePoolHirarchie[$i]) below Path $($RP.Path)"
            $LocResourcePool = Get-ResourcePool -Name $ResourcePoolHirarchie[$i] -Location $LocResourcePool
            If ( $? -ne $true ) {
                Write-Error "Resource Pool $ResourcePoolHirarchie[$i] within Path $RP.Path not found"
                break
            }
        }
          # Now we know all upper Resource Pools are present
          else {
            # Now we check if the Resource Pool that has to be created alredy exists
            Get-ResourcePool -Name $RP.Properties.Name -Location $LocResourcePool -ErrorAction SilentlyContinue
            If ( $? -eq $true ) {
                If ( $Force -eq $false ) {
                    Write-Warning "Resource Pool $($RP.Properties.Name) in upper Resource Pool Path $($RP.Path) already exists. Nothing will be done."
                    }
                  else
                    {
                    Write-Warning "Resource Pool $($RP.Properties.Name) in upper Resource Pool Path $($RP.Path) already exists."
                    Write-Warning "Force-Mode! Overwriting ResourcePool Settings!"
                    # For the 'Set-ResourcePool' Command there are some dependencies according the parameters that have to be considered
                    # -NumCpuShares requires -CpuSharesLevel set to 'Custom'
                    # -NumMemShares requires -MemSharesLevel set to 'Custom'
                    if ( $($RP.Properties.CpuSharesLevel) -eq "Custom" ) {
                        Set-ResourcePool -ResourcePool $($RP.Properties.Name) -CpuSharesLevel $($RP.Properties.CpuSharesLevel) -NumCpuShares $($RP.Properties.NumCpuShares)
                        }
                    if ( $($RP.Properties.MemSharesLevel) -eq "Custom" ) {
                        Set-ResourcePool -ResourcePool $($RP.Properties.Name) -MemSharesLevel $($RP.Properties.MemSharesLevel) -NumMemShares $($RP.Properties.NumMemShares)
                        }
                    Set-ResourcePool -ResourcePool $($RP.Properties.Name) `
                    -CpuExpandableReservation  ([System.Convert]::ToBoolean($RP.Properties.CpuExpandableReservation)) `
                    -CpuLimitMHz $RP.Properties.CpuLimitMHz `
                    -CpuReservationMHz $RP.Properties.CpuReservationMHz `
                    -MemExpandableReservation ([System.Convert]::ToBoolean($RP.Properties.MemExpandableReservation)) `
                    -MemLimitMB $RP.Properties.MemLimitMB `
                    -MemReservationMB $RP.Properties.MemReservationMB | Out-Null
                    }
                break
            }
            Write-Host "Creating RP $($RP.Properties.Name) in upper Resource Pool Path $($RP.Path)"

            New-ResourcePool -Location $LocResourcePool -Name $RP.Properties.Name`
            # For the 'Set-ResourcePool' Command there are some dependencies according the parameters that have to be considered
            # -NumCpuShares requires -CpuSharesLevel set to 'Custom'
            # -NumMemShares requires -MemSharesLevel set to 'Custom'
            if ( $($RP.Properties.CpuSharesLevel) -eq "Custom" ) {
                Set-ResourcePool -ResourcePool $($RP.Properties.Name) -CpuSharesLevel $($RP.Properties.CpuSharesLevel) -NumCpuShares $($RP.Properties.NumCpuShares)
                }
            if ( $($RP.Properties.MemSharesLevel) -eq "Custom" ) {
                Set-ResourcePool -ResourcePool $($RP.Properties.Name) -MemSharesLevel $($RP.Properties.MemSharesLevel) -NumMemShares $($RP.Properties.NumMemShares)
                }
            Set-ResourcePool -ResourcePool $($RP.Properties.Name) `
            -CpuExpandableReservation  ([System.Convert]::ToBoolean($RP.Properties.CpuExpandableReservation)) `
            -CpuLimitMHz $RP.Properties.CpuLimitMHz `
            -CpuReservationMHz $RP.Properties.CpuReservationMHz `
            -MemExpandableReservation ([System.Convert]::ToBoolean($RP.Properties.MemExpandableReservation)) `
            -MemLimitMB $RP.Properties.MemLimitMB `
            -MemReservationMB $RP.Properties.MemReservationMB | Out-Null
            break
          } ### End Else
    } ### End For   
} ### End foreach ResourcePool from xml

} ### End Process
} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPKPISLj0l8EpsSD3maT9rjbX
# DeagggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUGt06KbKHTVbi
# UUMXeDGm/1xSfCkwDQYJKoZIhvcNAQEBBQAEggEAZXsVPF6fliQ8JmZEvlDAb4JM
# AzSD8WnIk22Wx5L26dE5KZTR6Y25Y2i0vDM25YYNVINC3fUakOPfNIEwsrJN+CoL
# qZU+cayEeOC64nUPcvat7EHnbSkRJ2ojQw8ZG54jplTjsseb3Jhslgv83ipofscT
# +CAg5v0IX0WkWGoSgMNJ1hHbJMh9bI0GNQo5VrFvflqvGCjLzGi8Mg/rl0dt6Zop
# JWGeeAXoDX79iyygdOSdcgoQRLkEwREoHTscHPWWRZVG/aWyBrbG4ZndEkjBtMCt
# A3AkK3JXA0VNKlGkmU+agaLFFE5DERmF00Wu/AdPNuurlM23GrijBNVTCD3UTw==
# SIG # End signature block
