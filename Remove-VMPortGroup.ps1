function Remove-VMPortgroup {
<#
.SYNOPSIS
  PowerCLI Script to delete Standard Switch Portgroups from ESXi Hosts
.DESCRIPTION
.NOTES
  Release 1.1
  Robert Ebneth
  July, 12th
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER VLAN_TO_DELETE
  VLAN_TO_DELETE of PortGroup to be removed
.EXAMPLE
  Remove-VMPortGroup -VLAN_TO_DELETE <VLAN_ID> [ -confirm:$false ]
 #>

[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
param(
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER,
	[Parameter(Mandatory = $True,
	HelpMessage = "Enter VLAN for PortGroup to be deleted")]
    [Alias("vlan")]
	[string]$VLAN_TO_DELETE
)

Begin {
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
    if ( !(Get-Module -Name VMware.VimAutomation.Vds -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Vds
    }
}

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
        $ClusterHosts = Get-Cluster -Name $Cluster | Get-VMHost | Sort Name | Select Name
        foreach ($esxihost in $ClusterHosts) {
            $AllvSwitches = Get-VirtualSwitch -VMHost $($esxihost.Name)
            foreach ($vSwitch in $AllvSwitches ) {
                $PG = Get-VirtualPortGroup -VirtualSwitch $vSwitch | ?{ $_.VLanId -Like "$VLAN_TO_DELETE" }
                # check if there is an portgroup that has to be deleted
                if ($PG) {
                    # Yes, PG exists
                    if ($PSCmdlet.ShouldProcess("$($esxihost.Name)", "Removing ESXi vS Portgroup $($PG.Name) for VLAN $($PG.VLanID)")) {
                        Write-Host "Removing Portgroup $($PG.Name) for VLAN $($PG.VLanID) from ESXi Host $($esxihost.name)..."
                        Get-VMHost $($esxihost.Name) | Get-VirtualPortGroup -Name $($PG.Name) | Remove-VirtualPortGroup -Confirm:$false}
                      else { continue } 
                    }
                   # No, Portgroup does not exist on ESXi Host
                   else { Write-Host "Portgroup for VLAN $VLAN_TO_DELETE on ESXi Host $($esxihost.name) does not exist"; continue}
            }
        } ### End Foreach ESXi Host
    } ### End Foreach Cluster
} ### End Process
} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUPFSqvlfPzHeLAoIDARkxAIXz
# q4WgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUR+HG7TFIdRuc
# cdkG+scGj/qdD2owDQYJKoZIhvcNAQEBBQAEggEAYdCGHrRljhQHLv8qWnhXOmM9
# 49Z5oAS2gPtMnhoRU+VYYR8fHuwk0doKPEKkKGveJBSUjlIeTpyZA+hE89ySrfNP
# KTKof2TBuvzwTe5z49AVoa1uRxQRVoUSWiLtsMkOillPGFSmvZEGjm9fs53JlrBN
# S9bL6KYoNzmM6jdEyI8GhefDoI4RVcm+LCt9xnloPcvdZzdgj5edT7XgUwvBOMzs
# vL3OoAXMkLDlf5Y8rgdTXJT352Rks8mrI6aNtJzjlQ0cYRklETx3vtEe71ZdYj+4
# pUS7mZ7ff3DXDOFlj+Yi/ZFe68ypwTqrQzxsuFFV6twsHkkU2RwDUvkm0t+h/Q==
# SIG # End signature block
