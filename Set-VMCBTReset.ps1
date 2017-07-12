function Set-VMCBTReset {
<#
.SYNOPSIS
  Script resets the CBT (Changed Block Tracking) Setting on all VMs based per Cluster
.DESCRIPTION
  Script resets the CBT (Changed Block Tracking) Setting on all VMs based per Cluster
.NOTES
  Release 1.2
  Robert Ebneth
  July, 12th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER Cluster
  Selects only VMs for this vSphere Cluster. If nothing is specified,
  all vSphere Clusters will be taken.
.EXAMPLE
  Set-VMCBTReset -c < vSphere Cluster Name >
#>

[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
param(
	[Parameter(Mandatory = $False, ValueFromPipeline=$true)]
	[Alias("c")]
	[string]$CLUSTER
)

Begin {
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
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
		foreach ($vm in Get-Cluster $Cluster | Get-VM) {
			$view = Get-View $vm
			if ($view.Config.Version -ge "vmx-07" -and $view.Config.changeTrackingEnabled -eq $true) {
				if ($vm.PowerState -eq 'PoweredOff') { Write-Host "CBT cannot be enabled on VM $vm because it is PoweredOff." -ForegroundColor Yellow; continue }
                if ($view.snapshot -ne $null) {Write-Host "CBT cannot be enabled on VM $vm has active snapshots." -ForegroundColor Yellow; continue}
                
                if ($PSCmdlet.ShouldProcess("$($vm)", "Reset CBT Property of VM"))
                    { Write-Host "Reset CBT Property of VM"
                        #Disable CBT 
				        Write-Host "Disabling CBT for $($vm)..."
				        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
				        $spec.ChangeTrackingEnabled = $false 
				        $vm.ExtensionData.ReconfigVM($spec)

                        #Take/Remove Snapshot to reconfigure VM State
				        $SnapName = New-Snapshot -vm $vm -Quiesce -Name "CBT-Rest-Snapshot"
				        $SnapRemove = Remove-Snapshot -Snapshot $SnapName -Confirm:$false 

                        #Enable CBT 
				        Write-Host "Enabling CBT for $($vm)..."
				        $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
				        $spec.ChangeTrackingEnabled = $true 
				        $vm.ExtensionData.ReconfigVM($spec) 
								
				        #Take/Remove Snapshot to reconfigure VM State
				        $SnapName = New-Snapshot -vm $vm -Quiesce -Name "CBT-Verify-Snapshot"
				        $SnapRemove = Remove-Snapshot -Snapshot $SnapName -Confirm:$false
                    }
                  else
                    { Write-Host "Skipping Reset CBT for VM $($vm)..."
                } ### End if else 
			}
		} ### End Foreach VM in cluster
    } ### End Foreach Cluster
} ### End Process

End {
} ### End End

} ### End function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU2m6MIbimo/cwo+IVmb56/7rJ
# ysOgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUXE7QIXEB8EMx
# 7z4nl1UcaP6RXRswDQYJKoZIhvcNAQEBBQAEggEAfgIOV6Oj4zf+pY/3Cg0suIeU
# TOyyl8JYgWFDduguyAUXk85KFgSNfwOvUsNTjlz4T78DweVMg6FefoY5cVbggMsx
# en3n09CU2deC2VphYNyXp5GrOfpmyhGfvaNiP49K90VWHpqEvCdop6RtbZwPVMYi
# YcMS0kgMfYC7kmOv229bfP5lmOEW4hL2biY6dK1ndef6D0v3aIxkCaFXymCjEYKW
# 3WwClQqVwJZel7ysTB0pxTomTS3oBiIJwGgtJUXy136Vpszf8USr1jnSg5jBpfCA
# q+f5PxoWO+1W/Q8lVuVvMSn5f9LQ2cTwjF5lkwusu4096zafJR1Zng/n0ioF2w==
# SIG # End signature block
