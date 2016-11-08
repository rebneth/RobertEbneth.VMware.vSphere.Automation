function Set-VMResourcePool {
<#
.SYNOPSIS
  Check Resouurce Pool Setting for each VM from a vSphere Cluster
.DESCRIPTION
  Reads previous Backup File for Ressource Pool Settings for VMs
  Check Resouurce Pool Setting for each VM from a vSphere Cluster.
  If it differs from Backup Resource Pool settings. VM will be moved
  to that Resource Pool.
.NOTES
  Release 1.0
  Robert Ebneth
  November, 2nd, 2016
.LINK
  http://github.com/rebneth
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
	[string]$FILENAME = "$($PSScriptRoot)\vCenter_VMResourcePoolLocation.csv"
)

Begin {

    if ((Test-Path $FILENAME) -eq $False)
	    { Write-Error "Missing Input File: $FILENAME"; break}

    if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Add-PSSnapin VMware.VimAutomation.Core }

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