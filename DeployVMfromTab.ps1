Function DeployVMfromTab {
<#
.SYNOPSIS
  Mass Deployment for VMware vSphere VMs from csv input file
.DESCRIPTION
  Mass Deployment for VMware vSphere VMs from csv input file
  The list of VMs that have to be deployed comes from an external csv file
  The process contains Clone VM from Template, Setting Network, optional vCPU/vRAM
  and starting the VM (optional by specifying -Start cmdlet switch) 
  The csv file must contain the following fields:
  vmname,vccluster,resourcepool,vlan,template,customspec,datastorecluster,
  NumvCPU(optional, but has to be "" if not defined),vRAMGB(optional...),vmfolder
.NOTES
  Release 1.1a
  Robert Ebneth
  May, 11th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER FILENAME
  Name of csv based input file for the VMs to be created from template
  Default: $($PSScriptRoot)\rollout.csv
.PARAMETER MAXSESSIONS
  Specifies how much VMs will be created in parallel.
  To avoid too many iops on storage array
  Default: 2
.PARAMETER Start
  Specifies if the VM should be PoweredOn after cloning from template
  Default: false
.PARAMETER VCENTER
.EXAMPLE
 DeployVMfromTab
.EXAMPLE
 DeployVMfromTab -Start:$true
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
	[int]$MAXSESSIONS = "2",
	[Parameter(Mandatory = $False, ValueFromPipeline=$false,
	HelpMessage = "Enter vCenter Name")]
    [Alias("vc")]
	[string]$VCENTER
)
 
    # Check input file with list of VMs to deploy
    if ((Test-Path $FILENAME) -eq $False)
	    { Write-Error "Missing Input File: $FILENAME"; break}

    # Load VMware PS Core Module/SnapIn
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
    # We need VMware Module VMware.VimAutomation.Vds (Get-VDPortgroup)
    if ( !(Get-Module -Name VMware.VimAutomation.Vds -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Vds
    }
    #On demand: asking the admin for vcenter credentials at each run of the script
    if(!$defaultVIServer.IsConnected){
		$credential = Get-Credential -Message "Enter Credentials for $vcenter" -UserName "yourusername@vsphere6.local"
        $Session = Connect-VIServer -Server $vcenter -Force -Credential $credential
		if ($? -eq $false) {break}
		# if we did a successful vCenter Login, then we disconnect at the end 
		$LOGIN_IN_FUNCTION = $true
      else
        { $LOGIN_IN_FUNCTION = $false }
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
		Write-Host "Verify input file line #$($LineCount), entries for VM $($VM_TO_CREATE.VMName)..."
        $status = Get-VM -Name $VM_TO_CREATE.VMName -ErrorAction SilentlyContinue
        If ( $? -eq $true ) {
           Write-Host "Error in input file line #$($LineCount): Required VM to create $($VM_TO_CREATE.VMName) already exists" -ForegroundColor Red
           continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Cluster $($VM_TO_CREATE.VCCluster) does not exist." -ForegroundColor Red
            continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster | Get-ResourcePool $($VM_TO_CREATE.ResourcePool)  -ErrorAction SilentlyContinue |Out-Null
        If ( $? -eq $false ) {
			Write-Host "FAILED" -ForegroundColor Red
            Write-Host "Error in input file line #$($LineCount): Required Resource Pool $($VM_TO_CREATE.ResourcePool) does not exist." -ForegroundColor Red
            continue
        }
        $status = Get-Template $VM_TO_CREATE.Template  -ErrorAction SilentlyContinue | Out-Null
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Template $($VM_TO_CREATE.Template) not found" -ForegroundColor Red
            continue
        }
        $status = Get-OSCustomizationSpec $VM_TO_CREATE.customspec -ErrorAction SilentlyContinue
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required CustomSpec $($VM_TO_CREATE.customspec) not found" -ForegroundColor Red
            continue
        }
        $status = Get-Cluster $VM_TO_CREATE.VCCluster | Get-VMHost | Get-VirtualPortGroup -Name $VM_TO_CREATE.Vlan -ErrorAction SilentlyContinue | Out-Null
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required VLAN $($VM_TO_CREATE.Vlan) not found" -ForegroundColor Red
            continue
        }
        $status = Get-DatastoreCluster -Name $VM_TO_CREATE.datastorecluster -ErrorAction SilentlyContinue
        If ( $? -eq $false ) {
            Write-Host "Error in input file line #$($LineCount): Required Datastore Cluster $($VM_TO_CREATE.datastorecluster) not found" -ForegroundColor Red
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
    $AllVMNames = $VMsToDeploy | Select VMName | Sort VMName
    $UniqueVMNames = $VMsToDeploy | Select VMName | Sort VMName | Get-Unique -AsString
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
                        Set-VM $VM.VMname -NumCpu $VM.NumvCPU -Confirm:$false | Out-Null
                    }
                    if ( $VM.vRAMGB -ne "" ) {
                        Set-VM $VM.VMname -MemoryGB $VM.vRAMGB -Confirm:$false | Out-Null
                    }
				    Write-Host "Changing VLAN network setting for VM $($VM.VMName)..." -NoNewline
                    $FirstNetworkAdapter = Get-NetworkAdapter -VM $VM.VMname
                    Get-NetworkAdapter -VM $VM.VMname -Name "$($FirstNetworkAdapter[0].Name)" |`
                    Set-NetworkAdapter -NetworkName $($VM.vlan) `
                    -ErrorAction SilentlyContinue `
					-StartConnected:$true `
					-Confirm:$false `
					-Verbose `
					-RunAsync:$false
                    if ($? -eq $True) {
                        write-host "successfull" -ForegroundColor Green
                        if ($Start -eq $true) { Write-Host "Starting VM $($VM.VMname)..."
                                            Start-VM -VM $VM.VMname }
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

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDCyjNd8QSrpeFVqZFgdy9oZu
# 78GgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU8uiTFBt85KPZ
# CUo9B9fFSUUZAegwDQYJKoZIhvcNAQEBBQAEggEAKMh+pO6O12jYhprVG+kwaabr
# Y4Y5j3wWtfMm2UJ7fAHF66ex5wrd8kyS/sEtkah6i7xYP1ScbLNTAKKqJOjGu9iv
# 2alj1IX4SSHmNi3l5aPAweWolV7frDbLfMdRgRasm+mezhPHoPrmPFL74zLCWjWi
# WIN3IT5zSxJGjnsiHkijLcGT64OdcMNFvXIX2+gD3wlLacAPXUi/KM6RHUoyK+87
# xjnBoWJOejPlZj3DWwXXfk4HpNA2JvTDDOhrtwKQKr6kcI67nGq+ne08IH/kWF6j
# MiP8q+DBa7679ogAOmUYXQl0y49eXpWTesSYtHfETnRCFNnsGGMVcmry1810tA==
# SIG # End signature block
