<#
.SYNOPSIS
  Export Resource Pools from vSphere Cluster
  Export Location of vSphere Clusters VMs within Resource Pools
.DESCRIPTION
  Export Resource Pools from vSphere Cluster
  Export Location of vSphere Clusters VMs within Resource Pools
  This can be used day-by-day for a logical backup of
  VMware vCenter Resource Pool Settings. VMware vCenter
  Resource Pool Settings can be reconstructed by Script
  Set-VMResourcePool
.NOTES
  Release 1.0
  Robert Ebneth
  October, 10th, 2016
.EXAMPLE
  Export-vCenterResourcePools -Cluster <vSphere Cluster name>
.EXAMPLE
  Get-Cluster | Export-vCenterResourcePools
#>

Function Export-vCenterResourcePools {

    [CmdletBinding()]
    param(
    [Parameter(Mandatory = $True, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, Position = 0,
    HelpMessage = "Enter Name of vCenter Cluster")]
    [string]$Cluster
 #  [Parameter(Mandatory = $True, ValueFromPipeline=$false, ValueFromPipelineByPropertyName=$false, Position = 1,
 #  HelpMessage = "Enter the path to the csv output file")]
 #  [string]$FILENAME
    )

Begin {
	#$OUTPUTFILENAME = CheckFilePathAndCreate VMPowerState.csv $FILENAME
    $AllResourcePools = @()
    $AllVMsResourcePoolPath = @()

    Write-Host "#####################################################"
    Write-Host "# Export vCenter Resource Pools and their Structure #"
    Write-Host "#####################################################"	
	}

Process {
    $ClusterName = $Cluster
    $ClusterRP = Get-Cluster $ClusterName | Get-ResourcePool
    $RPRoot =  $ClusterRP | Where { $_.Name -eq "Resources"}
 
    ###
    ### Export of the Resource Pool Properties
    ###

    Write-Host "Exporting vCenter Cluster $Clustername Resource Pool Properties ..."
    foreach ( $ResPool in ($ClusterRP | where { $_.Name -ne "Resources"})) {
        $ResPoolPath = ""
        $CheckResPoolLevel = $ResPool
        while ( $CheckResPoolLevel.ParentId -ne $RPRoot.Id ) {
            $UpperResPool = $ClusterRP | Where { $_.Id -eq $CheckResPoolLevel.ParentId }
            $ResPoolPath = "\" + $UpperResPool.Name + "$ResPoolPath"
            $CheckResPoolLevel = $UpperResPool
        }
        $ResourcePool = "" | Select Path 
        $ResourcePool.Path = "\" + $RPRoot.Parent + "$ResPoolPath"
        $ResourcePool | Add-Member -Name 'Properties' -Value $ResPool -MemberType NoteProperty
        $AllResourcePools += $ResourcePool
    }

    ###
    ### Export of the Resource Pool Location for VMs
    ###

    $vms = Get-Cluster $ClusterName | Get-VM |Select Name, ResourcePoolId | Sort Name
    $LocResourcePool = Get-Cluster -Name $ClusterName | Get-ResourcePool | Where { $_.Name -eq "Resources" }

    Write-Host "Exporting vCenter Cluster $Clustername VM's Resource Pool Info..."
    Foreach( $vm in $vms) {
        $ResPoolPath = ""
        $CheckResPoolId = $vm.ResourcePoolId
        # Get Upper Resource Pool Tree
        while ( $CheckResPoolId -ne $RPRoot.Id ) {
            #Write-Host $vm.Name $CheckResPoolId $RPRoot.Id
            $UpperResPool = $ClusterRP | Where { $_.Id -eq $CheckResPoolId }
            $ResPoolPath = "\" + $UpperResPool.Name + "$ResPoolPath"
            $CheckResPoolId = $UpperResPool.ParentId
        }
        $VMResourcePool = "" | Select VMname
        $VMResourcePool.VMName = $vm.Name
        $ResPoolPath = "\" + $RPRoot.Parent + "$ResPoolPath"
        $VMResourcePool | Add-Member -Name 'ResourcePoolPath' -Value "$ResPoolPath" -MemberType NoteProperty
        $AllVMsResourcePoolPath += $VMResourcePool
    }
} ### End Process

End {
    $FILENAME = "$($PSScriptRoot)\vCenter_ResourcePools.xml"
    Write-Host "Writing File $($FILENAME)..."
    $AllResourcePools | Export-Clixml $FILENAME

    $FILENAME = "$($PSScriptRoot)\vCenter_VMResourcePoolLocation.csv"
    Write-Host "Writing File $($FILENAME)..."
    $AllVMsResourcePoolPath | Select VMname, ResourcePoolPath | Export-Csv $FILENAME -NoTypeInformation
} ### End End
} ### End Function