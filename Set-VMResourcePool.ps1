function Set-VMResourcePool {
<#
.SYNOPSIS
  Check Resource Pool Setting for each VM from a vSphere Cluster
.DESCRIPTION
  Reads previous Backup File for Ressource Pool Settings for VMs
  Check Resouurce Pool Setting for each VM from a vSphere Cluster.
  If it differs from Backup Resource Pool settings. VM will be moved
  to that Resource Pool.
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER Cluster
  Selects only ressource pools / VMs location from this vSphere Cluster.
  If nothing is specified, all vSphere Clusters will be taken.
.PARAMETER FILENAME
  Name of the csv input file for the VMs relation to resource pool
.EXAMPLE
  Set-VMResourcePool.ps1 -Cluster <vSphere Cluster name>
#>

# We support Move of VMs to different Resource Pool only if -Confirm:$true
[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
param(
    [Parameter(Mandatory = $True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$true,
    HelpMessage = "Enter Name of vCenter Cluster")]
    [string]$Cluster,
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter the path to the Resource Pool Backup file for import")]
    [Alias("f")]
	[string]$FILENAME = "$($env:USERPROFILE)\vCenter_VMResourcePoolLocation.csv"
)

Begin {
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
    if ((Test-Path $FILENAME) -eq $False)
	    { Write-Error "Missing Input File: $FILENAME"; break}

    Write-Host "###############################################"
    Write-Host "# Check/Set Resource Pool Setting for each VM #"
    Write-Host "###############################################"

    Write-Host "Reading File $($FILENAME)..."
    $BackupVMsResourcePoolPath = Import-Csv $FILENAME
}

Process {

    $ClusterName = $Cluster
    $AllVMsResourcePoolPath = $BackupVMsResourcePoolPath | Where { $_.ResourcePoolPath -Like "\$ClusterName\*" } 
    foreach ( $vm in $AllVMsResourcePoolPath ) {
        Write-Host "Analyzing Backup Resource Pool Info for VM $($vm.VMname)"
        $ResourcePoolHirarchie = $vm.ResourcePoolPath.Split('\')
        $Cluster = $ResourcePoolHirarchie[1]
        # Check #1 - Does vCenter Clustername from VM's Path match with existing vCenter clusters?
        Get-Cluster -Name $Cluster | Out-Null
        If ( $? -ne $true ) {
            Write-Error "vCenter Cluster $Cluster for VM $($vm.VMname) does not exist. Nothing to do."
            continue
        }
        # Check #2 - Is VM entry from csv known to previous vCenter Cluster ? 
        $VMvCenterInventory = Get-Cluster -Name $Cluster | Get-VM $vm.VMname -ErrorAction SilentlyContinue
        If ( $? -ne $true ) {
            Write-Error "vCenter Cluster $Cluster does not own VM $($vm.VMname). VM $($vm.VMname) cannot be moved to a Resource Pool for this cluster. Skipping this VM..."
            continue
        }
        # Check #3 - We check the resource pool path for this VM upward
        # This works for 10 Levels
        $LocResourcePool = Get-Cluster -Name $Cluster | Get-ResourcePool | Where { $_.Name -eq "Resources" }
        for ( $i=2; $i -le 10; $i++ ) {
            # Do we have upper Resource Pools for this Resoure Pool ? Then this field is not empty and contains name of upper Resource Pools
            if ( $ResourcePoolHirarchie[$i] ) {
                # We have to check the persistence of the upper resource pools
                #Write-Host $vm.VMname            
                Write-Verbose "Checking Ressource Pool $($ResourcePoolHirarchie[$i])"
                $LocResourcePool = Get-ResourcePool -Name $ResourcePoolHirarchie[$i] -Location $LocResourcePool -ErrorAction SilentlyContinue
                If ( $? -ne $true ) {
                    Write-Error "Resource Pool $ResourcePoolHirarchie[$i] within Path $($vm.ResourcePoolPath) not found"
                    $RPCHECK = $false
                    break }
                  else { $RPCHECK = $true
                }
            }
        }
        # Check #3 - if any of previous Resource Pool checks was false, we skip any action for this VM - this means 'continue' to foreach loop
        if ( $RPCHECK -eq $false ) {
            continue }

        # Check #4 - check VM's Resource Pool Position of path from csv and current Resource Pool (if any)
        # if it is the same, nothing has to be done
        if ( $($VMvCenterInventory.ResourcePoolId) -eq $($LocResourcePool.Id) ) {
            Write-Warning "VM $($vm.VMname) is already in Resource Pool $($vm.ResourcePoolPath). Nothing will be done."
        }
        # Now we know that we have to move the VM to the Resource Pool Path from csv entry for this VM
        else {
            $doit = $PSCmdlet.ShouldProcess("WhatIf: ","Moving VM $($vm.VMName) to Resource Pool $($vm.ResourcePoolPath)")
            if ($doit) {
                if ($PSCmdlet.ShouldProcess("Moving VM $($vm.VMName) to Resource Pool $($vm.ResourcePoolPath)", "Änderungen am System"))
                    {Write-Host "Moving VM $($vm.VMName) to Resource Pool $($vm.ResourcePoolPath)"
                    Move-VM -VM (Get-vm $vm.VMName) -Destination (Get-ResourcePool $($LocResourcePool.Name))
                }
                else { Write-Host "Skipping Move VM $($vm.VMName) to Resource Pool $($vm.ResourcePoolPath)" }
            }
        }
    }
} ### End Process
} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmYywqK0VduLvIfwE+x2A/U4H
# C3CgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU4lwjSiFhGLe+
# 9lC2phh40o1M4JEwDQYJKoZIhvcNAQEBBQAEggEAElUl3hWJx5PRT1OBE9DyywsW
# dGItDf6YWHHvxeMhXsph9pz7sO74QY2d7ziZ1vLYsn1n0+HKvTOgwq1MO5gMcu/J
# BuhKiD2+dsazjiSy1ERsbNiBYfQ1UB8Coz9qovPl6jBLFzzdsIWFo8iDsFw4nvC2
# F4nXKiqYaAvuTrQPNtOv58/nXuu3fgHOFzKh790Exm/aPSB7TLuR4Xs1cXHlUpar
# xi3JcRO9cAvDL7vY6VR33YOYAyIcbkuB5oK/GVfrzUoDOXe6tUJies7/Vo/IhP2S
# 7DSAh4rXwmGZXqpdFO5rn+48bnp7rg035b7N9bzmmt0/lOkcX/r1dO3zcjmNVg==
# SIG # End signature block
