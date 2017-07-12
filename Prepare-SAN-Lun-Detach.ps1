function Prepare-SAN-LUN-Detach-Remove {
<#
.Synopsis
   This script creates batch files for remove of VMware datastores from ESXi hosts 
.DESCRIPTION
   This Script supports in the process of unmount/detach of SAN Luns from VMware ESXi hosts.
   As this has to be done very, very carefully, this task is not fully automated.
   Instead of this, this script provides 3 files that can be executed step-by-step,
   even partially 

   The complete Process, abreviated, is as follows:

   1.) Make sure DS to be removed is not in use by VMs, Snapshots, or as coredump destination

   From now, this script will support You in the next steps:

   2.) The datastore(s) to be selected for remove
       - can be contained in a Datastorecluster (all DS will be removed)
       - a single DS 
       - multiple DS under a Folder ( this makes sense if You want remove only a couple DS from a cluster ) 

   Run this Script in the propriate way for the previous options
   The Script generates 3 different files in a work dir:

   $($FILEPREFIX)_UNMAP_VSPHERE_SAN_LUNs.txt
   $($FILEPREFIX)_DETACH_VSPHERE_SAN_LUNs.txt
   $($FILEPREFIX)_REMOVE_VSPHERE_SAN_LUNs.txt

   3.) Move Datastores to be removed out of a Datastore Cluster
       Execute $($FILEPREFIX)_UNMAP_VSPHERE_SAN_LUNs.txt
       or:
       Disable Storage IO Control using vSphere Web-Client (if necessary)
       Unmount Datastore(s) from all ESXi Hosts using vSphere Web-Client
       Delete Datastore(s) using vSphere Web-Client

   4.) OPTIONAL TESTING FROM ESXi host commands:

       Pickout 1 ESXi Server on which You want to test this.
       Put this server into maintenance mode. That avoids, if something does not fit, your VMs don't loose their storage
       Execute only this part from the scripts that is intend to be executed for this particulary ESXi host

       After this, check, if everything was done as foreseen

   5.) Execute Script #2
       that sets all the required Datastores to be removed to "Offline"
       
   6.) In coordination with your storage admin team remove access to those LUNs from your Storage array
   
   7.) Execute Script #3
       that removes all the required Datastores from all ESXi hosts

   8.) Rescan All HBAs from all ESXi Hosts

.NOTES
  Source:  Robert Ebneth
  Release: 1.2
  Date:    July, 12th, 2017

.LINK
   For a complete explaination of Detach/Remove of SAN Luns from ESXi hosts see VMware KB2004605 and KB2032893 articles.
   https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2004605
   https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=2032893

   For this Script see
   http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation

.EXAMPLE
   Prepare-SAN-LUN-Detach-Remove F <Foldername that contains DS to be removed> -CLUSTER <vSphere Host Cluster> -OUTPUTDIR <DEFAULT: LOCATION of Script>
.EXAMPLE
   Prepare-SAN-LUN-Detach-Remove DS <Datastorename> -CLUSTER <vSphere Host Cluster> -OUTPUTDIR <DEFAULT: LOCATION of Script>
.EXAMPLE
   Prepare-SAN-LUN-Detach-Remove DSC <ALL DS from DatastoreCluster> -CLUSTER <vSphere Host Cluster> -OUTPUTDIR <DEFAULT: LOCATION of Script>
#>

[CmdletBinding()]
[OutputType([int])]
Param (
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName=$false, Position = 0,
        HelpMessage = "Enter Name of vCenter Datacenter")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("DSC", "DS", "F")]
        [string]$MODE,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName=$false, Position = 1,
        HelpMessage = "Enter Datastore/DatastoreCluster/Folder with Datastores to be removed")]
        [string]$MODEPARAMETER,
        [Parameter(Mandatory = $True, ValueFromPipelineByPropertyName=$false, Position = 2,
        HelpMessage = "Enter Name of vCenter Datacenter")]
        [string]$CLUSTER,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName=$false, Position = 3,
        HelpMessage = "Enter Name of vCenter Datacenter")]
        [string]$OUTPUTDIR
)

    Begin
    {
    }

    Process
    {
    if ( !$OUTPUTDIR ) { $WORK_DIR = Get-Location } 
      else { $WORK_DIR = $OUTPUTDIR }
    $PathValid = Test-Path -Path "$WORK_DIR" -IsValid -ErrorAction Stop
    If ( $PathValid -eq $false ) { break}
 
	# Check and if not loaded add Powershell core module
	if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        	Import-Module VMware.VimAutomation.Core
	}
    
    if ($ESXiCredential) {Remove-Variable ESXiCredential}
    #$ESXiCredential = Get-Credential -Message "Please Enter root password for all ESXi servers" -UserName root
    # pseudo, will be set in batchfile
    $ESXiCredential = ""

    if ($MODE -eq "DS" ) { 
        [ARRAY]$ALL_DS_TO_REMOVE = Get-Datastore -Name "$MODEPARAMETER"
        If ( !$? ) { break}
    }
    if ($MODE -eq "DSC" ) { 
        [ARRAY]$ALL_DS_TO_REMOVE = Get-DatastoreCluster -Name "$MODEPARAMETER" | Get-Datastore # | get-view | select Name,@{n='wwn';e={$_.Info.Vmfs.Extent[0].DiskName}}
        If ( !$? ) { break}
    }
    if ($MODE -eq "F" ) { 
        [ARRAY]$ALL_DS_TO_REMOVE = Get-Folder -Name "$MODEPARAMETER" | Get-Datastore #| get-view | select Name,@{n='wwn';e={$_.Info.Vmfs.Extent[0].DiskName}}
        If ( !$? ) { break}
    }
    $ALL_CLUSTER_HOSTS = Get-Cluster -Name $CLUSTER | Get-VMHost | Sort Name
    If ( !$? ) { break}

    # Now we start creating the outputfiles
    $FILEPREFIX = $CLUSTER
    $OUTPUTFILE1 = "$($WORK_DIR)\$($FILEPREFIX)_DETACH_VSPHERE_SAN_LUNs.txt"
    $OUTPUTFILE2 = "$($WORK_DIR)\$($FILEPREFIX)_REMOVE_VSPHERE_SAN_LUNs.txt"
    $OUTPUTFILE3 = "$($WORK_DIR)\$($FILEPREFIX)_UNMAP_VSPHERE_SAN_LUNs.txt"
    foreach ( $FILE in "$OUTPUTFILE1","$OUTPUTFILE2","$OUTPUTFILE3" ) {
        if ((Test-Path $FILE ) -eq $True)
	        {Remove-Item $FILE }
        Write-Host "Creating File ${FILE}..."
        New-Item $FILE -type file | out-null}


    # Beginn each of both output files with a string that prompts for the ESXi credentials for esxcli commands
    # This credentials will be taken for each ESXi host (if multiple) and has to be the same on each host

    # Set Storage IO Control to disabled
    $string = '$VCCredential = Get-Credential -Message "Please Enter Admin Account for vCenter' + $VCSERVER + '"'
    Write-Host $string
    Add-Content $OUTPUTFILE3 $string
    $string = "connect-viserver -Server $($VCSERVER) -Protocol https -Credential " + '$VCCredential' + " | Out-Null"
    Write-Host $string
    Add-Content $OUTPUTFILE3 $string
    Add-Content $OUTPUTFILE3 "############################################################"
    Add-Content $OUTPUTFILE3 "# Disable Storage IO Control on Datastore(s) to be removed #"
    Add-Content $OUTPUTFILE3 "############################################################"
    foreach ($DS in $ALL_DS_TO_REMOVE) {
	    $string = "Set-Datastore -Datastore $($DS.Name) -StorageIOControlEnabled " + '$false'
	    Write-Host $string
	    Add-Content $OUTPUTFILE3 $string
	}
    
    Add-Content $OUTPUTFILE3 "##################################################"
    Add-Content $OUTPUTFILE3 "# Umount Datastore(s) from affected ESXi Host(s) #"
    Add-Content $OUTPUTFILE3 "##################################################"

    foreach ($DS in $ALL_DS_TO_REMOVE) {
		$hostviewDSDiskName = $DS.ExtensionData.Info.vmfs.extent[0].Diskname
		if ($DS.ExtensionData.Host) {
			$attachedHosts = $DS.ExtensionData.Host
            $string = "# Set Datastore removed from Hosts..."
            Write-Host $string
            Add-Content $OUTPUTFILE3 $string
            $CMD = '$Datastore = Get-Datastore '+$DS.Name
            Write-Host $CMD
            Add-Content $OUTPUTFILE3 $CMD

			Foreach ($VMHost in $attachedHosts) {
                $MOUNTHOST = Get-VMHost -Id $VMHost.Key
                $string = "# Unmounting VMFS Datastore $($DS.Name) from host $($MOUNTHOST)..."
                Write-Host $string
                Add-Content $OUTPUTFILE3 $string
				
                $CMD = '$VMHost = Get-VMHost '+$MOUNTHOST
                Write-Host $CMD
                Add-Content $OUTPUTFILE3 $CMD

				$CMD = '$hostview = Get-View $VMHost.Id'
                $CMD
                #Write-Host $CMD
                Add-Content $OUTPUTFILE3 $CMD

                $CMD = '$StorageSys = Get-View $HostView.ConfigManager.StorageSystem'
                Write-Host $CMD
                Add-Content $OUTPUTFILE3 $CMD

                $CMD = '$StorageSys.UnmountVmfsVolume($Datastore.ExtensionData.Info.vmfs.uuid)'
                Write-Host $CMD
                Add-Content $OUTPUTFILE3 $CMD
			}
		}
	}

    #$string = "disconnect-viserver -Server $($VCSERVER) -Force -Confirm:" + '$False' + " | Out-Null"
    #Write-Host $string
    Add-Content $OUTPUTFILE3 $string

    Add-Content $OUTPUTFILE1 "##########################################################################"
    Add-Content $OUTPUTFILE1 "### Make sure that all Datastores/SAN Luns to be removed are unmounted ###"
    Add-Content $OUTPUTFILE1 "##########################################################################"
    Add-Content $OUTPUTFILE2 "######################################################################################"
    Add-Content $OUTPUTFILE2 "### Make sure that all ESXi Hosts do not have access to all SUN Luns to be removed ###"
    Add-Content $OUTPUTFILE2 "######################################################################################"
    #$string = '$ESXiCredential = Get-Credential -Message "Please Enter root password for all ESXi servers" -UserName root'
    #Write-Host $string
    Add-Content $OUTPUTFILE1 $string
    Add-Content $OUTPUTFILE2 $string
	
    foreach ( $single_host in $ALL_CLUSTER_HOSTS ) { 

        write-Host "#"
	    write-Host "# Remove LUNs from Host $single_host"
        write-Host "#"
	    #$string = '$ESXiCredential = Get-Credential -Message "Please Enter root password for ESXi server $single_host" -UserName root'
        #$string = $string + "connect-viserver -Server $($single_host) $ESXiSERVER -Protocol https -Credential " + '$ESXiCredential' + " | Out-Null"
	    #$string = $string + "`r`n" + '$esxcli = Get-EsxCli -VMHost ' + $($single_host)
	    #Write-Host $string
	    Add-Content $OUTPUTFILE1 $string
	    Add-Content $OUTPUTFILE2 $string
	
        # Now we fillup the file #1 with commands to set SAN Lun offline
        foreach ( $DS_TO_REMOVE in $ALL_DS_TO_REMOVE ) {
		    # we have to generate a string like # $esxcli.storage.core.device.set($null, "naa.60000970000295700331533032384431", $null, $null, $null, $null, $null, $null, "off")
		    #                                     $esxcli.storage.core.device.set($null, $null, "naa.68fc61463c5fa6dfd67c15a1b7055039", $null, $null, $null, $null, $null, $null, $null, $null, $null, "off", $null)
            write-Host "# Permanently remove SAN LUN for Datastore $($DS_TO_REMOVE.Name)"
		    #$string = '$esxcli.storage.core.device.set($null, "' + "$($DS_TO_REMOVE.ExtensionData.Info.vmfs.extent[0].diskname)" +'", $null, $null, $null, $null, $null, $null, "off")'
		    $string = '$esxcli.storage.core.device.set($null, $null, "' + "$($DS_TO_REMOVE.ExtensionData.Info.vmfs.extent[0].diskname)" +'", $null, $null, $null, $null, $null, $null, $null, $null, $null, "off", $null)'
		    Write-Host $string
		    Add-Content $OUTPUTFILE1 $string
		}
	
        # Now we fillup the file #1 with commands to remove/detach SAN Lun
	    foreach ( $DS_TO_REMOVE in $ALL_DS_TO_REMOVE ) {
		    # we have to generate a string like # $esxcli.storage.core.device.detached.remove("naa.60000970000295700331533032384431")
		    # we have to generate a string like # $esxcli.storage.core.device.detached.remove($null, "naa.60000970000295700331533032384431")
            write-Host "# Detach SAN LUN for Datastore $($DS_TO_REMOVE.Name)"
		    #$string = '$esxcli.storage.core.device.detached.remove("' + "$($DS_TO_REMOVE.ExtensionData.Info.vmfs.extent[0].diskname)" + '")'
            $string = '$esxcli.storage.core.device.detached.remove($null, "' + "$($DS_TO_REMOVE.ExtensionData.Info.vmfs.extent[0].diskname)" + '")'
		    write-Host $string
		    Add-Content $OUTPUTFILE2 $string
        }
        $string = '$esxcli.storage.core.device.detached.list()'
	    Write-Host $string
	    Add-Content $OUTPUTFILE2 $string
	
	    #$string = "disconnect-viserver -Server $($single_host) -Force -Confirm:" + '$False' + " | Out-Null"
	    #Write-Host $string
	    Add-Content $OUTPUTFILE1 $string
	    Add-Content $OUTPUTFILE2 $string
	    Write-Host ""
    }

    }
    End
    {
    }
}

# Disconnect-VIServer -Server $VCSERVER -Force -Confirm:$False | Out-Null

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUyihEkM3nuMpQiMlLTYitdM71
# ZfOgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUx/htlS9oRnJU
# wSRbn9ok4H+t5wMwDQYJKoZIhvcNAQEBBQAEggEAJFL7oPQU1gIqhjkVhXkm4TsD
# z4MUOeTFfdAif4YHEEu9h/yw3uXe6ZuZEA4F0dVF8VYqQ/fKej7jz0cttmdSg0we
# TmZqavg6dgwSIfChavTUetkRmfAMorr2g62vO/d9JR3FfMxodSOx94JABer2u+qJ
# Ntq9xWBUWW5TbYRjp1EtNO2RcuysWP2boJ3bxRddIuXK40T2OKo8QfbioCWXnAoG
# r08Dc0SzNcV6bNfMoDwaa1nb9t9rzXWcWxjZJxyMd9epqz/s6K080TMSdW4ae6Xk
# Qh5YBJKJZrgser2zQPD+i9jBm5OZUzGAbro9LS0wXrFCDvzZQNY1CU9aMbxUow==
# SIG # End signature block
