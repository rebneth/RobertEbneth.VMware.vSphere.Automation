Function VM-DeployfromTab {
<#
.SYNOPSIS
  Mass Deployment for VMs for VMware vCenter 
.DESCRIPTION
  Mass Deployment for VMs for VMware vCenter
  The list of VMs that have to be deployed comes from an external csv file
.SYNTAX
 VM-DeployfromTab [-Start:$true] [-MAXSESSIONS [1...]] [-FILENAME <INPUTFILE>]
 .PARAMETER Start
 .PARAMETER MAXSESSIONS
 .PARAMETER FILENAME
.EXAMPLE
 VM-DeployfromTab
.EXAMPLE
 VM-DeployfromTab -Start:$true
.NOTES
  Release 1.0
  Robert Ebneth
  October, 25th, 2016
.LINK
 http://github.com/rebneth
#>

	#[CmdletBinding()]
	param(
    # We expect the default input file rollout.csv in the same directory as the script
	[Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter the path to the csv input file")]
    [Alias("f")]
	[string]$FILENAME = "$($PSScriptRoot)\rollout.csv",
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
    HelpMessage = "True if You want to start the VMs at the end of the create VM process.")]
	[switch]$Start = $false,
    [Parameter(Mandatory = $False, ValueFromPipeline=$false,
    HelpMessage = "Enter number of max parallel create VM sessions (Default: 4)")]
    [Alias("m")]
	[int]$MAXSESSIONS = "2"
   )

   $vcenter = "vcenter001-betrieb-prod.hal.dbrent.net"
 
    # Check input file with list of VMs to deploy
    if ((Test-Path $FILENAME) -eq $False)
	    { Write-Error "Missing Input File: $FILENAME"; break}

    # Load VMware PS Core Module/SnapIn
    if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
        Add-PSSnapin VMware.VimAutomation.Core }
    # We need VMware Module VMware.VimAutomation.Core (Get-VDPortgroup)
    if(-not(Get-Module -name VMware.VimAutomation.Vds ))
        { Import-Module VMware.VimAutomation.Vds -ErrorAction SilentlyContinue }

    #On demand: asking the admin for vcenter credentials at each run of the script
    if(!$defaultVIServer.IsConnected){
		$credential = Get-Credential -Message "Enter Credentials for $vcenter" -UserName "yourusername@vsphere6.local"
        $Session = Connect-VIServer -Server $vcenter -Force -Credential $credential
		if ($? -eq $false) {break}
		# if we did a successful vCenter Login, then we disconnect at the end 
		$LOGIN_IN_FUNCTION = $true
    }

    ###
    ### Import List of VMs that have to be deployed to an Array
    ### Hash Tables cannot be used as we use an index to this array
    ###
    $VMsToDeploy=@()
    ### We expect the following fields:
    ### vmname,vccluster,resourcepool,vlan,template,customspec,datastorecluster,NumvCPU(opt),vRAMGB(opt),vmfolder
    $VMsToDeploy = Import-Csv $FILENAME -Delimiter ","
    ### We do some basic syntax checking at this point to avoid errors during deployment....
    $TMP_VMsToDeploy = @()
    [INT]$LineCount = 1
    foreach ( $VM_TO_CREATE in $VMsToDeploy ) {
        $LineCount++
        $status = Get-VM -Name $VM_TO_CREATE.VMName -ErrorAction SilentlyContinue
        If ( $? -eq $true ) {
           Write-Host "Error in input file line #$($LineCount): Required VM to create $($VM_TO_CREATE.VMName) already exists"
           continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Cluster $($VM_TO_CREATE.VCCluster) does not exist."
            continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster | Get-ResourcePool $($VM_TO_CREATE.ResourcePool)  -ErrorAction SilentlyContinue |Out-Null
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Resource Pool $($VM_TO_CREATE.ResourcePool) does not exist."
            continue
        }
        $status = Get-Template $VM_TO_CREATE.Template  -ErrorAction SilentlyContinue | Out-Null
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Template $($VM_TO_CREATE.Template) not found"
            continue
        }
        $status = Get-OSCustomizationSpec $VM_TO_CREATE.customspec -ErrorAction SilentlyContinue
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required CustomSpec $($VM_TO_CREATE.customspec) not found"
            continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster | Get-VMHost | Get-VirtualPortGroup -Name $VM_TO_CREATE.Vlan -ErrorAction SilentlyContinue | Out-Null
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required VLAN $($VM_TO_CREATE.Vlan) not found"
            continue
        }
        $status = Get-DatastoreCluster -Name $VM_TO_CREATE.datastorecluster -ErrorAction SilentlyContinue
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Datastore Cluster $($VM_TO_CREATE.datastorecluster) not found"
            continue
        }
        # $VM_TO_CREATE line has passed all checks
        $TMP_VMsToDeploy += $VM_TO_CREATE
    }
    if ( $TMP_VMsToDeploy.Count -ne $VMsToDeploy.Count ) {
        Write-Host "Possible Syntax errors in input file. Aborting." -ForegroundColor Red
        break
    }

    # Finally, we check input file for duplicate VM Names
    $AllVMNames = $VMsToDeploy | Select VMName
    $UniqueVMNames = $VMsToDeploy | Select VMName | Get-Unique -AsString
    if ( diff $AllVMNames $UniqueVMNames ) {
        Write-Host "Error: Input file contains duplicate VM Names" -ForegroundColor Red
        break
    }

    ### Session Table for processing and LOG
	$CREATEVM_SESSION_INFO = @()
	$CREATEVM_LOG = @()

	# For further processing we need a list that will be decreased
	$ServerListe = $VMsToDeploy

    ###
	### Loop for starting clone_from_template sessions
    ###
	while (( $ServerListe.Count -gt "0" ) -or ( $CREATEVM_SESSION_INFO.Count -gt "0" )) {
		# Do we have a 'free' create VM task slot ?
		if (( $ServerListe.Count -gt "0" ) -and ( $CREATEVM_SESSION_INFO.Count -lt $MAXSESSIONS )) {
            # we pick the first VM to create from the list and reduce this list by this VM
            # this cannot be done by any foreach loop as it  might be interrupted one ore more times 
			$VM_TO_CREATE = $ServerListe[0]
			$ServerListe = $ServerListe[1..($ServerListe.count)]

  			#
            # start create VM from template
            #
            Write-Host "Create VM $($VM_TO_CREATE.VMName) from Template $($VM_TO_CREATE.Template)..." -NoNewLine

			$CREATEVM_TASK = New-VM -Location (Get-Folder -Name $($VM_TO_CREATE.vmfolder) -Type VM) `
			-Name $VM_TO_CREATE.VMName `
			-Template $VM_TO_CREATE.Template `
			-ResourcePool $VM_TO_CREATE.resourcepool `
			-Datastore $VM_TO_CREATE.datastorecluster `
			-OSCustomizationSpec $VM_TO_CREATE.customspec `
			-RunAsync:$true
			
			# We better wait 2 seconds until we check the Task status
			Start-Sleep -s 2
			
            # Collect CreateVM Task Details
			$CurrentTaskStatus = Get-Task -Id $CREATEVM_TASK.Id
           	$CREATEVM_TASK_INFO = "" | Select Task, TaskId, VMName, State, PercentComplete, StartTime, FinishTime
            $CREATEVM_TASK_INFO.Task = $CurrentTaskStatus.Name
			$CREATEVM_TASK_INFO.TaskId = $CurrentTaskStatus.Id
			$CREATEVM_TASK_INFO.VMName = $VM_TO_CREATE.VMname
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
			# We sleep for 12 seconds
			Start-Sleep 12
        } ### End

		###
        ### At this point we will check if we have finished sessions to update session list
        ###
		$TMP_CREATEVM_SESSION_INFO = @()
        foreach ( $CREATEVM_SESSION in $CREATEVM_SESSION_INFO ) {				
			$CurrentTaskStatus = Get-Task -Id "$($CREATEVM_SESSION.TaskId)"
			$CHECK_TASK_INFO = "" | Select Task, TaskId, VMName, State, PercentComplete, StartTime, FinishTime
			$CHECK_TASK_INFO.Task = $CREATEVM_SESSION.Task
			$CHECK_TASK_INFO.TaskId = $CREATEVM_SESSION.TaskId
			$CHECK_TASK_INFO.VMName = $CREATEVM_SESSION.VMName
			$CHECK_TASK_INFO.State = $CurrentTaskStatus.State
			$CHECK_TASK_INFO.PercentComplete = $CurrentTaskStatus.PercentComplete
			$CHECK_TASK_INFO.StartTime = $CurrentTaskStatus.StartTime
			$CHECK_TASK_INFO.FinishTime = $CurrentTaskStatus.FinishTime
					
			if ( $CHECK_TASK_INFO.State -eq "Running" ) {
				# Update vMotion Session Info
				$TMP_CREATEVM_SESSION_INFO += $CHECK_TASK_INFO
				}
			  else {
				# Log all completed sessions
				$CREATEVM_LOG += $CHECK_TASK_INFO
				# If a VM was succesfully created, we change Network and start the VM
				if ($CHECK_TASK_INFO.State -eq "Success") {
					$VM = $VMsToDeploy | Where { $_.VMName -eq "$($CHECK_TASK_INFO.VMName)"}
                    # If vCPU/vRAM is provided from csv, we change this for this VM
                    Write-Host "Customizing VM Hardware (vCPU/vRAM)..."
                    if ( $VM.NumvCPU -ne "" ) {
                        Set-VM $VM.VMname -NumCpu $VM.NumvCPU -Confirm:$false
                    }
                    if ( $VM.vRAMGB -ne "" ) {
                        Set-VM $VM.VMname -MemoryGB $VM.vRAMGB -Confirm:$false
                    }
				    Write-Host "Changing VLAN network setting for VM $($VM.VMName)..." -NoNewline
                    $FirstNetworkAdapter = Get-NetworkAdapter -VM $VM.VMname
                    Get-NetworkAdapter -VM $VM.VMname |`
                    Set-NetworkAdapter -NetworkName $($VM.vlan) `
                    -ErrorAction SilentlyContinue `
					-StartConnected:$true `
					-Confirm:$false `
					-Verbose `
					-RunAsync:$false `
                    if ($? -eq $True) {
                        write-host "successfull" -ForegroundColor Green
                        if ($Start -eq $true) { Write-Host "Starting VM $($VM.VMname)..."
                                            Start-VM -Name $VM.VMname }
                        }
                      else {
                        write-host "FAILED" -ForegroundColor Red
                           }
                }
			}
			# Set the currenntly still running sessions
			$CREATEVM_SESSION_INFO = $TMP_CREATEVM_SESSION_INFO
        } ### End foreach session loop
        write-host "Currently running CreateVM Sessions..."
        $CREATEVM_SESSION_INFO | select * | Format-Table -AutoSize
        Write-Host "Remaining number of VMs to deploy: $($ServerListe.Count). Maximum number of concurrent VM depolyments: $($MAXSESSIONS). We wait for 5 Seconds..."
        Start-Sleep 5

	} ### End While Loop Server.Liste

	# At this point we wait until all running Create VM sessions are finished

	# End of VM Deployment - we show the Log
	$CREATEVM_LOG | select * | Format-Table -AutoSize
	$CREATEVM_LOG | Out-GridView
	
	# if we had a vCenter Login at the begin of this function we will disconnect vCenter (re-establish state)
	if ($LOGIN_IN_FUNCTION = $true) {
		    Disconnect-VIServer -Server $vcenter -Confirm:$false}

} ### End Function
