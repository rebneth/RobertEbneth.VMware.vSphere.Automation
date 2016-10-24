Function VM-Deploy-from-Tab {
<#
.SYNOPSIS
  Mass Deployment for VMs for VMware vCenter 
.DESCRIPTION
  Mass Deployment for VMs for VMware vCenter
  The list of VMs that have to be deployed comes from an external csv file
.SYNTAX
 VM-Deploy-from-Tab [-Start:$true] [-MAXSESSIONS [1...]] [-FILENAME <INPUTFILE>]
 .PARAMETER Start
 .PARAMETER MAXSESSIONS
 .PARAMETER FILENAME
.EXAMPLE
 VM-Deploy-from-Tab
.EXAMPLE
 VM-Deploy-from-Tab -Start:$true
.NOTES
  Release 1.0
  Robert Ebneth
  October, 9th, 2016
.LINK
 http://github.com/rebneth
#>

	#[CmdletBinding()]
	param(
	[Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter the path to the tsv input file")]
    [Alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\rollout.tsv",
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
    HelpMessage = "True if You want to start the VMs at the end of the create VM process.")]
	[switch]$Start = $false,
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
    HelpMessage = "Enter number of max parallel create VM sessions (Default: 4)")]
    [Alias("m")]
	[int]$MAXSESSIONS = "4"
   )

	$CREATEVM_SESSION_INFO = @()
	$CREATEVM_LOG = @()
 
 if ((Test-Path $FILENAME) -eq $False)
	{ Write-Error "Missing Input File: $FILENAME"; break}

 if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
    Add-PSSnapin VMware.VimAutomation.Core
}
 
    $vcenter = "vcenter.hal.dbrent.net"

    #On demand: asking the admin for vcenter credentials at each run of the script
    if(!$Session.IsConnected){
		$credential = Get-Credential -Message "Enter Credentials for $vcenter" -UserName "yourusername@vsphere6.local"
#        $Session = Connect-VIServer -Server $vcenter -Force -Credential $credential
		if ($? -eq $false) {break}
		# if we did a successful vCenter Login, then we disconnect at the end 
		$LOGIN_IN_FUNCTION = $true
    }

    # Import List of VMs that have to be deployed to an Array
    # Hash Tables cannot be used as we use an index to this array
    $VMsToDeploy=@()
    $VMsToDeploy = Import-Csv $FILENAME -Delimiter ","
#    Import-Csv $FILENAME -Delimiter ","| ForEach-Object {
#        $server = @{name=$_.vmname;
#        template=$_.template;
#        vlan=$_.vlan;
#        resourcepool=$_.resourcepool;
#        customspec=$_.customspec;
#        datastore=$_.datastore;
#        vmfolder=$_.vmfolder}

#        $VMsToDeploy += @{$server.name=$server}
#    }

	# For further processing we need a list that will be decreased
	$ServerListe = $VMsToDeploy

	### Loop for starting clone_from_template sessions
	while ( $ServerListe.Count -gt "0" ) {
		# Do we have a 'free' create VM task slot ?
		if ( $CREATEVM_SESSION_INFO.Count -lt $MAXSESSIONS ) {
			$VM_TO_CREATE = $ServerListe[0]
            # Let's start with some checks...
            # Get-Template -Name $VM_TO_CREATE.Template
            # Get-OSCustomizationSpec
            # $VMHost = Get-Cluster $Cluster | Get-VMHost -State Connected | Get-Random
            # $CapacityKB = Get-Hardddisk -Template $VM_TO_CREATE.Template | Measure-Object -Sum | Select-Object -ExpandProperty Sum
            # Get-Datastore --VMHost $VMHost | `
            # ?{($_FreeSpaceMB*1mb) -gt (($CapacityKB * 1kb) *1.1)}
            
			# start create VM from template
            Write-Host "Create VM $($VM_TO_CREATE.VMName) from Template $($VM_TO_CREATE.Template)..." -NoNewLine

#			$CREATEVM_TASK = New-VM -Location (Get-Folder -Name $VM_TO_CREATE.vmfolder -Type VM) `
#			-Name $VM_TO_CREATE.Name `
#			-Server $Session `
#			-Template (Get-Template -Name $VM_TO_CREATE.template -Server $Session) `
#			-ResourcePool $VM_TO_CREATE.resourcepool `
#			-Datastore $VM_TO_CREATE.datastore `
#			-OSCustomizationSpec $VM_TO_CREATE.customspec `
#			-RunAsync:$true
			# As we started the Create VM action, we remove this VM/Server from our list
			$ServerListe = $ServerListe[1..($ServerListe.count)]
			
			# We better wait 5 seconds until we check the Task status
			Start-Sleep -s 5
			
			$CurrentTaskStatus = Get-Task -Id $CREATEVM_TASK.Id
           	$CREATEVM_TASK_INFO = "" | Select Task, TaskId, VMName, VMHost, VMDestDatastore, State, PercentComplete, StartTime, FinishTime
            $CREATEVM_TASK_INFO.Task = "CreateVM_Task"
			$CREATEVM_TASK_INFO.TaskId = $CREATEVM_TASK.Id
			$CREATEVM_TASK_INFO.VMName = $VM_TO_CREATE.VMname
			$CREATEVM_TASK_INFO.VMHost = $VMHost
            $CREATEVM_TASK_INFO.VMDestDatastore = $Dest_Datastore
			$CREATEVM_TASK_INFO.State = $CurrentTaskStatus.State
			$CREATEVM_TASK_INFO.PercentComplete = $CurrentTaskStatus.PercentComplete
			$CREATEVM_TASK_INFO.StartTime = $CurrentTaskStatus.StartTime
			$CREATEVM_TASK_INFO.FinishTime = $CurrentTaskStatus.FinishTime
				
			if  ( $CurrentTaskStatus.State -eq "Running" ) {
				write-host "started successfully" -ForegroundColor Green
            	# Update CreateVM Session List
            	$CREATEVM_SESSION_INFO += $CREATEVM_TASK_INFO
            	}
			  else {
			    write-host "FAILED" -ForegroundColor Red
				# Update SvMotion_Log
            	$CREATEVM_LOG += $CREATEVM_TASK_INFO
				}
			Write-Host ""
			# We sleep for 25 seconds
			Start-Sleep 25

			# At this point we will check if we have finished sessions to update session list
			$TMP_CREATEVM_SESSION_INFO = @()
            foreach ( $CREATEVM_SESSION in $CREATEVM_SESSION_INFO ) {				
				$CurrentTaskStatus = Get-Task -Id "$($CREATEVM_SESSION.TaskId)"
				$CREATEVM_TASK_INFO = "" | Select Task, TaskId, VMName, VMHost, VMDestDatastore, State, PercentComplete, StartTime, FinishTime
				$CREATEVM_TASK_INFO.Task = $CREATEVM_SESSION.Task
				$CREATEVM_TASK_INFO.TaskId = $CREATEVM_SESSION.TaskId
				$CREATEVM_TASK_INFO.VMName = $CREATEVM_SESSION.VMName
			    $CREATEVM_TASK_INFO.VMHost = $VMHost
                $CREATEVM_TASK_INFO.VMDestDatastore = $Dest_Datastore
				$CREATEVM_TASK_INFO.State = $CurrentTaskStatus.State
				$CREATEVM_TASK_INFO.PercentComplete = $CurrentTaskStatus.PercentComplete
				$CREATEVM_TASK_INFO.StartTime = $CurrentTaskStatus.StartTime
				$CREATEVM_TASK_INFO.FinishTime = $CurrentTaskStatus.FinishTime
					
				if ( $CurrentTaskStatus.State -eq "Running" ) {
					# Update vMotion Session Info
					$TMP_CREATEVM_SESSION_INFO += $CREATEVM_TASK_INFO
					}
				  else {
					# Log all completed sessions
					$CREATEVM_LOG += $CREATEVM_TASK_INFO
					# If a VM was succesfully created, we change Network and start the VM
					if ($CurrentTaskStatus.State -eq "Completed") {
						$VM = $VMsToDeploy | Where { $_.Name -eq "$($CurrentTaskStatus.VMName)"}
					    Write-Output $("trying to set adapter on " + $VM.VMname)

                        Get-NetworkAdapter -VM $VM.name |`
                        Set-NetworkAdapter -PortGroup (Get-VDPortGroup -Name $VM.vlan ) `
                        -VM (Get-VM $VM.VMname -ErrorAction SilentlyContinue) `
                        #-Name "Network adapter 1" `
                        -ErrorAction SilentlyContinue `
						-StartConnected:$true `
						-Confirm:$false `
						-Verbose `
						-RunAsync:$false `
                        if ($? -eq $True) {
                            if ($Start -eq $true) { Start-VM -Name $VM.VMname }
                        }
					}
				  }
			    # Set the currenntly still running sessions
			    $CREATEVM_SESSION_INFO = $TMP_CREATEVM_SESSION_INFO
		    }
            write-host "Running Create VM Sessions..."
            $CREATEVM_SESSION_INFO | select * | Format-Table -AutoSize
            Write-Host "We wait for 5 Seconds..."
            Start-Sleep 5
        }
	} ### End Loop Server.Liste

	# At this point we wait until all running Create VM sessions are finished

	# End of VM Deployment - we show the Log
	$CREATEVM_LOG | select * | Format-Table -AutoSize
	$CREATEVM_LOG | Out-GridView
	
	# if we had a vCenter Login at the begin of this function we will disconnect vCenter (re-establish state)
	if ($LOGIN_IN_FUNCTION = $true) {
		    Disconnect-VIServer -Server $vcenter -Confirm:$false}

} ### End Function
