function VM-PowerCycle {
<#
.SYNOPSIS
  Cmdlet will power-cycle all VMs for a given VMware vCenter Cluster or from Inputfile
.DESCRIPTION
  Cmdlet will shutdown all VMs for a given VMware vCenter Cluster or from Inputfile.
  After a given Downtime ( Default:30 seconds) the previously powered down VMs will
  be powered on and the VMware Tools and the IP Interface of the VM will be checked.
  All actions will be logged to a given csv file.

  Because this Script has a critical impact to VMs of Your VI infrastructure,
  this powershell script is running in 'High' Impact State and shutdown / power off
  actions to the VMs have to be confirmed. (Confirm ? Yes to each VM or Yes to all VMs)

  You can overwrite this confirming question by using the '-Confirm:$false' Option
.NOTES
  Release 1.0
  Robert Ebneth
  October, 22nd, 2016
.LINK
  http://github.com/rebneth
.EXAMPLE
  VM-PowerCycle -Cluster <vSphere Cluster name>
.EXAMPLE
  VM-PowerCycle -Cluster <vSphere Cluster name>  -Confirm:$false
#> 

	# Because this Script has an critical Impact to VMs,
	# it is running in 'High' Impact State and shutdown action has to be confirmed
    [CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
    param(
    [Parameter(Mandatory = $True,
    ValueFromPipeline=$True,
    ValueFromPipelineByPropertyName=$true,
    HelpMessage = "Enter Name of vCenter Cluster")]
	[Alias("c")]
    [string]$Cluster,
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter the path to the Resource Pool Backup file for import")]
    [Alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\VM-PowerCycle_Action_LOG.csv"
	)
	
Begin {
	# Load required functions from PS Script module
	# Adding PowerCLI core snapin
	if (!(get-pssnapin -name VMware.VimAutomation.Core -erroraction silentlycontinue)) {
		add-pssnapin VMware.VimAutomation.Core
	}
	
	#$OUTPUTFILENAME = CheckFilePathAndCreate VMPowerState.csv $FILENAME
    $OUTPUTFILENAME = $FILENAME
	
	# In this table we save all completed actions and this is written to disk at the end
	$ActionLogTable = @()
	# In this table we save the state of the current running actions
	$RunningTaskTable = @()
    # Temporary Table to allocate VM's HostId to its ESXi FQDN
    ### $HostIDs = Get-VMHost | select Name, Id, Parent | Sort-Object Name
    $HostIDs = Import-Clixml D:\HostIDs.xml
    $AllVMs = Import-Clixml D:\AllVMs.xml
}

  Process {

  $vmlist = "dhcpd01-2015","dhcpd01-2062","dhcpd01-2072","vm1","vm2","vm3"
    
	foreach ( $vm in $vmlist ) {
		# We define an Action/Current State List for each VM
		# The Flags Field represents the following States:
		# x = Shutdown triggered
		# x = PowerOff triggered
		# x = PowerOff reached
		# x = PowerOn triggered
		# x = PoweredOn and VMTools running
		# x = PoweredOn but not reachable by ping
		# x = PoweredOn and successfully ping'd
		$VMActionInfo = "" | select ClusterName,VMHost,VMName,PowerState,VMToolsStatus,ShutdownTask,ShutdownTaskId,ShutdownTaskState,ShutdownStartTime,ShutdownFinishTime,PowerOnTaskId,PowerOnTaskState,PowerOnStartTime,PowerOnFinishTime,Flags,TaskState,Remark
		$VMActionInfo.VMName = $vm
		###### Replacement: $VMInfo = Get-VM $vm -ErrorAction SilentlyContinue
        $VMInfo = $AllVMs | Where { $_.Name -eq "$vm" }
		# If we do not have this VM then we LOG and skip to the next VM
		###If ( $? -eq $False ) {
        if ( $VMInfo.Name -ne "$vm" ) {
            $VMActionInfo.VMName = $vm
			$VMActionInfo.TaskState = "Failed"
			$VMActionInfo.Remark = "Unkown VM $vm in vCenter"
			$ActionLogTable += $VMActionInfo
			continue
		}
		# Now it it clear that VM exists and we can fill up the next Info for this VM
        $VMHostInfo = $HostIDs | Where { $_.Id -eq $VMInfo.VMHostId }
        $VMActionInfo.ClusterName = $VMHostInfo.Parent
		$VMActionInfo.VMHost = $VMInfo.VMHost
		$VMActionInfo.Powerstate = $VMInfo.PowerState
		$VMActionInfo.VMToolsStatus = $VMInfo.Guest.Extensiondata.ToolsVersionStatus
		If ( $($VMInfo.PowerState).Value -eq "PoweredOff" ) {
			$VMActionInfo.TaskState = "Failed"
			$VMActionInfo.Remark = "VM $($VMInfo.Name) is already PoweredOff. No action executed."
			$ActionLogTable += $VMActionInfo
			continue
		}
		# We begin to shutdown the VMs
		# If VMTools are running by shutdown GuestOS Command, if VMTools are not running by PowerOff Command

        # This action is critical to Your VI environment. Action(s) has/have to be confirmed
        $doit = $PSCmdlet.ShouldProcess("WhatIf: $($VMInfo.Name)","Shutdown VM Guest OS / Stop VM")
        if ($doit) {

            if (( $VMInfo.VMToolsStatus -ne "guestToolsNotInstalled" ) -and ( $VMInfo.VMToolsStatus -ne "guestToolsUnmanaged" )) {
                if ($PSCmdlet.ShouldProcess("$($VMInfo.Name)", "Shutdown VM Guest OS "))
                    {Write-Host "Shutdown Guest OS from VM $($VMInfo.Name)..." -NoNewline
                    $ShutdownVM_TASK = Stop-VMGuest -VM $VMInfo.Name -RunAsync -ErrorAction SilentlyContinue
                    $VMActionInfo.Flags = "1"
			        # We better wait 2 seconds until we check the Task status
			        Start-Sleep -s 2
			        ### $CurrentTaskStatus = Get-Task -Id $ShutdownVM_TASK.Id
                    $CurrentTaskStatus = Import-Clixml D:\TaskInfo.xml			
                    }
                  else {
                    Write-Host "Skipping Shutdown Guest OS from VM $($VMInfo.Name)"
                    $VMActionInfo.TaskState = "Failed"
			        $VMActionInfo.Remark = "Shutdown Guest OS from VM $($VMInfo.Name) interrupted by user. No further action will be done."
			        $ActionLogTable += $VMActionInfo
                    continue
                }
              }
              else {
                if ($PSCmdlet.ShouldProcess("$($VMInfo.Name)", "Shutdown VM Guest OS "))
                    {Write-Host "PowerOff VM $($VMInfo.Name)..." -NoNewline
                    $ShutdownVM_TASK = Stop-VM -VM $VMInfo.Name -RunAsync -ErrorAction SilentlyContinue
                    $VMActionInfo.Flags = "1"
			        # We better wait 2 seconds until we check the Task status
			        Start-Sleep -s 2
			        ### $CurrentTaskStatus = Get-Task -Id $ShutdownVM_TASK.Id
                    $CurrentTaskStatus = Import-Clixml D:\TaskInfo.xml			
                    }
                  else {
                    Write-Host "Skipping Shutdown Guest OS from VM $($Info.VMName)"
                    $VMActionInfo.TaskState = "Failed"
			        $VMActionInfo.Remark = "PowerOff VM $($VMInfo.Name) interrupted by user. No further action will be done."
			        $ActionLogTable += $VMActionInfo
                    continue
                }
            }
        }

		# Now we can provide the VMActionInfo with the triggered Task Info
		$VMActionInfo.ShutdownTask = $CurrentTaskStatus.Task
		$VMActionInfo.ShutdownTaskId = $CurrentTaskStatus.Id        
		$VMActionInfo.ShutdownTaskState = $CurrentTaskStatus.State
		#$VMActionInfo.PercentComplete = $CurrentTaskStatus.PercentComplete
		$VMActionInfo.ShutdownStartTime = $CurrentTaskStatus.StartTime
		$VMActionInfo.ShutdownFinishTime = $CurrentTaskStatus.FinishTime
		if  ( $CurrentTaskStatus.State -eq "Running" ) {
			write-host "started successfully" -ForegroundColor Green
           	# Update CreateVM Session List
            $VMActionInfo.TaskState = "RUNNING"
           	$RunningTaskTable += $VMActionInfo
           	}
		  else {
		    write-host "FAILED" -ForegroundColor Red
			# Update Log and break
            $VMActionInfo.TaskState = "Failed"
            $ActionLogTable += $VMActionInfo
			continue
		}
        ### $VMActionInfo
	} ### End Foreach
	
    ###
    ### Watch for finished Tasks
    ###
	
	$VMsToBeCompleted = $RunningTaskTable.Count
    #While ( $VMsToBeCompleted -ne "0" ) 
	    #$TMPVMActionInfo = "" | select ClusterName,VMHost,VMName,PowerState,VMToolsStatus,ShutdownTask,ShutdownTaskId,ShutdownTaskState,ShutdownStartTime,ShutdownFinishTime,PowerOnTaskId,PowerOnTaskState,PowerOnStartTime,PowerOnFinishTime,Flags,TaskState,Remark
        foreach ( $RunningTask in $RunningTaskTable ) {
			switch ($RunningTask.State) {
			  0 {"xx"}
			  1 {"yy"}
			}
		}
        $RunningTaskTable = "" | select ClusterName,VMHost,VMName,PowerState,VMToolsStatus,ShutdownTask,ShutdownTaskId,ShutdownTaskState,ShutdownStartTime,ShutdownFinishTime,PowerOnTaskId,PowerOnTaskState,PowerOnStartTime,PowerOnFinishTime,Flags,TaskState,Remark
        $RunningTaskTable.Count
    #}

    $ActionLogTable += $RunningTaskTable
	
   } ### End Process
 
End {
    Write-Host "VM-PowerCycle FINISHED. Writing Logfile $OUTPUTFILENAME"
	$ActionLogTable | Export-csv -Delimiter ";" $OUTPUTFILENAME -noTypeInformation
 } ### End End 
   
} ### End Function
 