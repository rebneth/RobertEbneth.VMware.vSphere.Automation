function Set-VMHostiSCSISettings {
<#
.SYNOPSIS
  PowerCLI Script to Update iSCSI Software Initiator Settings on ESXi Hosts
.DESCRIPTION
  PowerCLI Script to Update iSCSI Software Initiator Settings on ESXi Hosts
  The desired destination configuration is applied. That means, existing
  iSCSI Target Bindings, that were not needed anymore, will be deleted.
  New iSCSI Target Bindings for the ESXi Host will be added.
  PowerCLI Session must be connected to vCenter Server using Connect-VIServer
.NOTES
  Release 1.0
  Robert Ebneth
  November, 25rd, 2016
.LINK
  http://github.com/rebneth
.PARAMETER VMHosts
  Name
.PARAMETER targets
  allows the following Syntaxes
  "10.202.1.101", "10.202.1.103", "10.202.2.102"
  and in one String seperated by , ; or ' ':
  "192.168.1.1,192.168.1.2; 10.10.1.1 1"
.EXAMPLE
  Get-VMhost <ESXiHostname> | Set-VMHostiSCSISettings -targets 1.1.1.1, 2.2.2.2 [ -confirm:$false ]
.EXAMPLE
  Get-Cluster | Get-VMhost | Sort Name | Set-VMHostiSCSISettings -targets 1.1.1.1, 2.2.2.2
 #>
[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
 param(
   [Parameter(Mandatory = $True,
   ValueFromPipeline=$True,
   ValueFromPipelineByPropertyName=$true,
   HelpMessage = "Enter Name of ESXi Host")]
   [string]$Name,
   [Parameter(Mandatory = $True,
   ValueFromPipeline=$False,
   HelpMessage = "Enter iSCSI Target(s)")]
   [string[]]$targets
)

Begin {
}

Process {

    # We have to split multiple IP-Adresses separated by ; , or ' '
    $targets = $targets.split(",")
    $targets = $targets.split(";")
    $targets = $targets.trim()
    $targets = $targets.split(" ")
    $targets = $targets.trim()
    # We have to check the Vaildation of each IP-Address
    foreach ($target in $targets) {
        $IPvalid = [Bool]($target -as [IPAddress])
        If ( $IPvalid -eq $False ) { Throw "Invalid IP-Adress: $target" }
    } ### End foreach

    # Within this script we use $VMHost instead of $Name
    $VMHost = $Name
    # Check/Enable Software iSCSI Adapter on each host
    $SoftwareIScsiEnabled = Get-VMHostStorage -VMHost $VMHost
    If ( !$? ) { break}
    if ( $SoftwareIScsiEnabled -eq $false ) {
        Write-Host "Enabling Software iSCSI Adapter on $VMHost ..."
        Get-VMHostStorage -VMHost $VMHost | Set-VMHostStorage -SoftwareIScsiEnabled $True
        If ( $? ) { Write-Host "Software iSCSI could not be enabled. Break." -ForegroundColor Red }
        # Just a sleep to wait for the adapter to load
		Start-Sleep -Seconds 10 
        }
      else { Write-Host "Software iSCSI on host $VMHost is already enabled." -ForegroundColor Green }
    $hba = Get-VMHost $VMHost | Get-VMHostHba -Type iScsi | Where {$_.Model -eq "iSCSI Software Adapter"}
    If ( $? -eq $false ) { break }

    # Remove of existing iSCSI Target Bindings that are not listed in the '-targets' list 
    $CurrentISCSITargets = Get-IScsiHbaTarget -IScsiHba $hba -Type Send
    If ( !$? ) { break }
    foreach ( $existingtarget in $CurrentISCSITargets ) {
            $TargetExists = $false
            foreach ($target in $targets){
                if ( $($existingtarget.Address) -eq $target ) {
                $TargetExists = $true; break
                }                
            }
            If ($TargetExists -eq $false) {
                if ($PSCmdlet.ShouldProcess("$($VMHost)", "Remove iSCSI target-binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"))
                    { Write-Host "Removing existing iSCSI Target $($existingtarget.Address):$($existingtarget.Port) from Host $VMHost $($hba.Device)..."
                    Get-IScsiHbaTarget -IScsiHba $hba -Address "$($existingtarget.Address):$($existingtarget.Port)" -Type Send | Remove-IScsiHbaTarget -Confirm:$false | Out-Null}
                  else
                    { Write-Host "Skipping removal of iSCSI Target Binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"
                } ### End if else 
            }
        } ### End foreach

        # Try to add iSCSI Targets
        foreach($target in $targets){
            if(Get-IScsiHbaTarget -IScsiHba $hba -Type Send | Where {$_.Address -cmatch $target}){
                Write-Host "The iSCSI target $target already exists on $VMHost $($hba.Device)" -ForegroundColor Green
            }
            else{
                Write-Host "The iSCSI target $target doesn't exist on $VMHost $($hba.Device)" -ForegroundColor Yellow
                if ($PSCmdlet.ShouldProcess("$($VMHost)", "Creating iSCSI Target Binding $($target):$($existingtarget.Port) for adapter $($hba.Device)"))
                    { Write-Host "Creating iSCSI target $target" -ForegroundColor Yellow
                    New-IScsiHbaTarget -IScsiHba $hba -Address $target | Out-Null
                    If ( $? ) { Write-Host "iSCSI target $target successfully added." -ForegroundColor Green }
                  else { Write-Host "Skipping creating of iSCSI Target Binding $($existingtarget.Address):$($existingtarget.Port) for adapter $($hba.Device)"
                } 
            }                
        } ### End foreach
    } ### End foreach
  
    ###
    ### At the end we do a Rescan on all HBAs and then a Rescan for VMFS volumes
    ###
    Write-Host "Rescan all HBAs on host $VMHost"
    Get-VMHostStorage -VMHost $VMHost -RescanAllHba | Out-Null
	Write-Host "Rescan VMFS on host $VMHost"
    Get-VMHostStorage -VMHost $VMHost -RescanVmfs | Out-Null

  } ### End Process

} ### End Function
