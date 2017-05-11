function vSphereHardening-VM {
<#
.SYNOPSIS
  Checks a VMware Virtual Machine against VMware Security Hardening Guide
  and optionally changes VMs security based settings 
.DESCRIPTION
  Checks a VMware Virtual Machine against VMware Security Hardening Guide
  and optionally changes VMs security based settings
  http://www.vmware.com/security/hardening-guides.html
.NOTES
  Release 1.0a
  Robert Ebneth
  May, 11th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER VMName
  Name of the VMware Virtual Machine
.PARAMETER CHANGE_MODE
  CHANGE_MODE (m) defines, if this function should also apply the recommended settings
  DEFAULT: $false - Report Mode only
.PARAMETER CBTReset
  Only valid if CHANGE_MODE = $true
  This executes a CBT Disable/Enable, both followed by temporary VM snapshots
  As this may have a greater impact (increasing backup data), we decided to to this optional 
.PARAMETER INPUTFILENAME
  The path and filename of the CSV file that contains the hardening settings from VMware
  The csv file is an extraction from the Original vSphere Security Hardening Guide
  saved as ";" Semicolon based csv file  
  DEFAULT: $($PSScriptRoot)\vSphere_6_hardening_settings.csv
.PARAMETER RECOMMENDATIONFILENAME
  Logfile for recommended changes to the VM that were NOT executed
  DEFAULT: $($env:USERPROFILE)\VMware_vSphere_Hardening_VM_Recommendations_$(get-date -f yyyy-MM-dd-HH-mm-ss).cs
.PARAMETER ACTIONFILENAME
  Logfile for recommended changes to the VM that were executed    
  DEFAULT: $($env:USERPROFILE)\VMware_vSphere_Hardening_VM_change_actions_report_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  vSphereHardening-VM -VMname <VMName> -i <Input file for vSphere Hardening Settings>
#>

param(
    [Parameter(Mandatory = $true, Position = 1)]
    [alias("n")]
    [string]$VMName = "VMName",
    [Parameter(Mandatory = $false, Position = 2)]
    [alias("m")]
    [string]$CHANGE_MODE = $false,
    [Parameter(Mandatory = $false, Position = 3)]
    [alias("CBT")]
    [string]$CBTReset = $false,
    [Parameter(Mandatory = $false, Position = 4)]
    [alias("i")]
    [string]$INPUTFILENAME = "$($PSScriptRoot)\vSphere_6_hardening_settings.csv",
    [Parameter(Mandatory = $false, Position = 5)]
    [alias("r")]
    [string]$RECOMMENDATIONFILENAME = "$($env:USERPROFILE)\VMware_vSphere_Hardening_VM_Recommendations_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv",
    [Parameter(Mandatory = $false, Position = 6)]
    [alias("a")]
    [string]$ACTIONFILENAME = "$($env:USERPROFILE)\VMware_vSphere_Hardening_VM_change_actions_report_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

Begin {
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }

    # Check all outputfilenames
    $OUTPUTFILENAME1 = CheckFilePathAndCreate "$RECOMMENDATIONFILENAME"
    $OUTPUTFILENAME2 = CheckFilePathAndCreate "$ACTIONFILENAME"
    #
    # Applying all Settings from vSphere Hardening Guide, VM Section (Input via csv file)
    #
    if ((Test-Path $INPUTFILENAME) -eq $False) {
        Write-Error "Missing Input File: $INPUTFILENAME"; break}
    $VMTargetAdvSettings = Import-Csv -Delimiter ";" $INPUTFILENAME  

    #
    # Add some settings beyond the vSphere Security Hardening Guide to the action list
    # This affects VM Logging, Snapshots
    #
    # disk.enableUUID for Linux VMs
    if ( ($VM.ExtensionData.Config.GuestFullName -Like "CentOS*") -or ($VM.ExtensionData.Config.GuestFullName -Like "U*") ) {
        $VMAdvancedOption = "" | Select GuidelineID, ConfigurationParameter, DEFAULT_VALUE, TARGET_VALUE, ActionType
        $VMAdvancedOption.GuidelineID = "Recommendation for Backup Tools"
        $VMAdvancedOption.ConfigurationParameter = "disk.enableUUID"
        $VMAdvancedOption.DEFAULT_VALUE = "NULL"
        $VMAdvancedOption.TARGET_VALUE = "true"
        $VMAdvancedOption.ActionType = "Add"
        $VMTargetAdvSettings += $VMAdvancedOption
    }
    # log.rotateSize
    $VMAdvancedOption = "" | Select GuidelineID, ConfigurationParameter, DEFAULT_VALUE, TARGET_VALUE, ActionType
    $VMAdvancedOption.GuidelineID = "VMware KB8182749: Log rotation and logging options for vmware.log"
    $VMAdvancedOption.ConfigurationParameter = "log.rotateSize"
    $VMAdvancedOption.DEFAULT_VALUE = "NULL"
    $VMAdvancedOption.TARGET_VALUE = "1048576"
    $VMAdvancedOption.ActionType = "Add"
    $VMTargetAdvSettings += $VMAdvancedOption
    # log.keepOld
    $VMAdvancedOption = "" | Select GuidelineID, ConfigurationParameter, DEFAULT_VALUE, TARGET_VALUE, ActionType
    $VMAdvancedOption.GuidelineID = "VMware KB8182749: Log rotation and logging options for vmware.log"
    $VMAdvancedOption.ConfigurationParameter = "log.keepOld"
    $VMAdvancedOption.DEFAULT_VALUE = "NULL"
    $VMAdvancedOption.TARGET_VALUE = "25"
    $VMAdvancedOption.ActionType = "Add"
    $VMTargetAdvSettings += $VMAdvancedOption

    # Reporting
    $ToDoReport = @()
    $ExecutionReport = @()
    
    write-host ""
    write-host "########################################################################"
    write-host "# Start vSphere VM Hardening based on VMware Security hardening Guides #"
    write-host "# http://www.vmware.com/security/hardening-guides.html                 #"
    write-host "########################################################################"

} ### End Begin

Process {

write-host ""
write-host "Verified VM Object: $VMname"
write-host ""

[INT]$CheckNr = 1
$vm = Get-VM $VMname

# Load the VMs current Advanced settings
$VMCurrentAdvSettings = Get-VM $vm.Name | Get-AdvancedSetting | Sort Name  | Select Entity, Name, Value

# Enable CBT on VMs
# https://kb.vmware.com/selfservice/microsites/search.do?language=en_US&cmd=displayKC&externalId=1031873

Write-host "VMware Hardening Step $($CheckNr): VM options - Advanced settings - ctkEnabled = true (Enable CBT)..."
if ( $CHANGE_MODE -eq $true ) {
    if ( $CBTReset -eq $true ) {
	    Write-Host "Reset CBT Property of VM"
	    #Disable CBT 
	    Write-Host "Disabling CBT for $($vm)..."
	    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	    $spec.ChangeTrackingEnabled = $false 
	    $vm.ExtensionData.ReconfigVM($spec)

        #Take/Remove Snapshot to reconfigure VM State
	    $SnapName = New-Snapshot $vm -Quiesce -Name "CBT-Rest-Snapshot"
	    $SnapRemove = Remove-Snapshot -Snapshot $SnapName -Confirm:$false 
        #Enable CBT 
	    Write-Host "Enabling CBT for $($vm)..."
	    $spec = New-Object VMware.Vim.VirtualMachineConfigSpec
	    $spec.ChangeTrackingEnabled = $true 
	    $vm.ExtensionData.ReconfigVM($spec) 
								
	    #Take/Remove Snapshot to reconfigure VM State
	    $SnapName = New-Snapshot $vm -Quiesce -Name "CBT-Verify-Snapshot"
	    $SnapRemove = Remove-Snapshot -Snapshot $SnapName -Confirm:$false

        $ActionLog = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue, Result
        $ActionLog.VMname = $VMName
        $ActionLog.Guideline = "VMware KB1031873"
        $ActionLog.RequiredActionType = "Disable/Enable CBT"
        $ActionLog.CurrentValue = "N/A"
        $ActionLog.TargetValue = "N/A"
        $ActionLog.Result = "successful"
        $ExecutionReport += $ActionLog
        }
      else {
        Write-Host -ForegroundColor Green "cmdlet parameter CBTReset set to false. Skipping CBT Reset"
    }
    }
  else {
    if ( $CBTReset -eq $true ) {
        $RequiredAction = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue
        $RequiredAction.VMname = $VMName
        $RequiredAction.Guideline = "VMware KB1031873"
        $RequiredAction.RequiredActionType = "Disable/Enable CBT"
        $RequiredAction.CurrentValue = "N/A"
        $RequiredAction.TargetValue = "N/A"
        $ToDoReport += $RequiredAction
    }
}

# vSphere hardening Guide - MaxConnections = 2
$maxConnections = New-Object VMware.Vim.optionvalue
$maxConnections.Key = "RemoteDisplay.maxConnections"
$maxConnections.Value = "2"
Write-host -NoNewline "VMware Hardening Step $($CheckNr): Checking VM options - VMware Remote Console options - maxconnections = $($maxConnections.Value) ... "
if ( $vm.ExtensionData.Config.MaxMksConnections -ne $maxConnections.Value ) {
    if ( $CHANGE_MODE -eq $true ) {
        $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
        $vmConfigSpec.extraconfig = $maxConnections
        $ActionLog = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue, Result
        $ActionLog.VMname = $VMName
        $ActionLog.Guideline = "N/A"
        $ActionLog.RequiredActionType = "Change VM Option MaxMksConnections"
        $ActionLog.CurrentValue = $vm.ExtensionData.Config.MaxMksConnections
        $ActionLog.TargetValue = $($maxConnections.Value)
        $vm.ExtensionData.ReconfigVM($vmConfigSpec)            
        if ($? -eq $true ) {
            Write-Host -ForegroundColor Green "successful"
            $ActionLog.Result = "successful"
            $ExecutionReport += $ActionLog }
          else {
            Write-Host -ForegroundColor Red "FAILED"
            $ActionLog.Result = "FAILED"
            $ExecutionReport += $ActionLog }
         } ### End If Change Mode
      else {
        Write-Host "Required Action: Set VM Option MaxMksConnections to Target Value $($maxConnections.Value)"
        $RequiredAction = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue
        $RequiredAction.VMname = $VMName
        $RequiredAction.Guideline = "N/A"
        $RequiredAction.RequiredActionType = "Change VM Option MaxMksConnections"
        $RequiredAction.CurrentValue = $vm.ExtensionData.Config.MaxMksConnections
        $RequiredAction.TargetValue = $($maxConnections.Value)
        $ToDoReport += $RequiredAction
    }}
  else
    { Write-Host -ForegroundColor Green "ok"
}
$CheckNr++

#
# Execute all tests from the action list
#
foreach ( $VMAdvancedOption in $VMTargetAdvSettings ) {
$TEST_PROPERTY = $VMCurrentAdvSettings | Where { $_.Name -eq $($VMAdvancedOption.ConfigurationParameter) }
$String = "VMware Hardening Step $($CheckNr): Guideline Id: $($VMAdvancedOption.GuidelineID) - Parameter: $($VMAdvancedOption.ConfigurationParameter) Current Value: "+'"'+"$($TEST_PROPERTY.Value)"+'" ... '
Write-host -NoNewline $String
if ( ! $TEST_PROPERTY ) {
    if ( $VMAdvancedOption.ActionType -eq "Add" ) {
        Write-Host -ForegroundColor Yellow "Not set - Action required"
        if ( $CHANGE_MODE -eq $true ) {
            Write-Host -NoNewline "According Hardening Guide - Action Type Add - adding VM Option - Advanced Setting Parameter: $($VMAdvancedOption.ConfigurationParameter) = $($VMAdvancedOption.TARGET_VALUE) ... "
            $VMAdvOptionParameter = New-Object VMware.Vim.optionvalue
            $VMAdvOptionParameter.Key = $($VMAdvancedOption.ConfigurationParameter)
            $VMAdvOptionParameter.Value = $($VMAdvancedOption.TARGET_VALUE)
            $vmConfigSpec = New-Object VMware.Vim.VirtualMachineConfigSpec
            $vmConfigSpec.extraconfig = $VMAdvOptionParameter
            $ActionLog = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue, Result
            $ActionLog.VMname = $VMName
            $Actionlog.Guideline = $($VMAdvancedOption.GuidelineID)
            $ActionLog.RequiredActionType = "Change Advanced Parameter $($VMAdvancedOption.ConfigurationParameter)"
            $ActionLog.CurrentValue = "NULL"
            $ActionLog.TargetValue = $($VMAdvancedOption.TARGET_VALUE)
            $vm.ExtensionData.ReconfigVM($vmConfigSpec)
            if ($? -eq $true ) {
                Write-Host -ForegroundColor Green "successful"
                $ActionLog.Result = "successful"
                $ExecutionReport += $ActionLog }
            else {
                Write-Host -ForegroundColor Red "FAILED"
                $ActionLog.Result = "FAILED"
                $ExecutionReport += $ActionLog }
            } ### End If Change Mode
          else {
            Write-Host "Required Action according vSphere Hardening Guide: Adding VM $VMName Advanced Setting Parameter: $($VMAdvancedOption.ConfigurationParameter) Target Value: $($VMAdvancedOption.TARGET_VALUE)"
            $RequiredAction = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue
            $RequiredAction.VMname = $VMName
            $RequiredAction.Guideline = $($VMAdvancedOption.GuidelineID)
            $RequiredAction.RequiredActionType = "Add Advanced Parameter $($VMAdvancedOption.ConfigurationParameter)"
            $RequiredAction.CurrentValue = "NULL"
            $RequiredAction.TargetValue = $($VMAdvancedOption.TARGET_VALUE)
            $ToDoReport += $RequiredAction        }
        } ### End If ActionType
      else {
        Write-Host -ForegroundColor Green "ok - Parameter not set, but no action required"
    } ### Else If ActionType
    } ### End If $TEST_PROPERTY (Parameter is not set)
  ### Parameter is already set
  else {
    if ( $($TEST_PROPERTY.Value) -eq $($VMAdvancedOption.TARGET_VALUE) ) {
        Write-Host -ForegroundColor Green "ok" }
      else {
        Write-Host -ForegroundColor Yellow "target value differs from current value - Action required"
        if ( $CHANGE_MODE -eq $true ) {
            Write-Host -NoNewline "*** Changing *** Advanced Setting Parameter: $($VMAdvancedOption.ConfigurationParameter) = $($VMAdvancedOption.TARGET_VALUE) ... "
            $ActionLog = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue, Result
            $ActionLog.VMname = $VMName
            $ActionLog.Guideline = $($VMAdvancedOption.GuidelineID)
            $ActionLog.RequiredActionType = "Change Advanced Parameter $($VMAdvancedOption.ConfigurationParameter)"
            $ActionLog.CurrentValue = $($TEST_PROPERTY.Value)
            $ActionLog.TargetValue = $($VMAdvancedOption.TARGET_VALUE)
            Get-VM $vm.Name | Get-AdvancedSetting -Name $($VMAdvancedOption.ConfigurationParameter) | Set-AdvancedSetting -Value $($VMAdvancedOption.TARGET_VALUE)
            if ($? -eq $true ) {
                Write-Host -ForegroundColor Green "successful"
                $ActionLog.Result = "successful"
                $ExecutionReport += $ActionLog }
            else {
                Write-Host -ForegroundColor Red "FAILED"
                $ActionLog.Result = "FAILED"
                $ExecutionReport += $ActionLog }
            } ### End If Change Mode
          else {
            Write-Host "Required Action according vSphere Hardening Guide: Changing VM $VMName Advanced Setting Parameter: $($VMAdvancedOption.ConfigurationParameter) Target Value: $($VMAdvancedOption.TARGET_VALUE)"
            $RequiredAction = "" | Select VMname, Guideline, RequiredActionType, CurrentValue, TargetValue 
            $RequiredAction.VMname = $VMName
            $RequiredAction.Guideline = $($VMAdvancedOption.GuidelineID)
            $RequiredAction.RequiredActionType = "Change Advanced Parameter $($VMAdvancedOption.ConfigurationParameter)"
            $RequiredAction.CurrentValue = $($TEST_PROPERTY.Value)
            $RequiredAction.TargetValue = $($VMAdvancedOption.TARGET_VALUE)
            $ToDoReport += $RequiredAction
        }
    }
}
$CheckNr++
} ### End Foreach AdvancedOption

} ### End Process

End {
    # Generate Report
    $ToDoReport | Sort VMName, RequiredActionType | Out-GridView
    $ExecutionReport | Sort VMName, RequiredActionType | Out-GridView
    Write-Host ""
    Write-Host "Writing Outputfile $($OUTPUTFILENAME1)..."
    $ToDoReport | Export-csv -Delimiter ";" $OUTPUTFILENAME1 -noTypeInformation -Encoding UTF8
    Write-Host "Writing Outputfile $($OUTPUTFILENAME2)..."
    $ExecutionReport | Export-csv -Delimiter ";" $OUTPUTFILENAME2 -noTypeInformation -Encoding UTF8
} ### End End

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUv81mIgLxqU9s2YOZAGl/CRrv
# xFOgggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUSJaU2y8d6dem
# Ee/dOxBLaLPhw9owDQYJKoZIhvcNAQEBBQAEggEABsP/GXB9E7E2VgCdg4YYou98
# 7Nat9q6G93u+opAb2cI9gS3jfcn2XxLqr8vCLpCbHR6W4qukCxTTXotMHqHAA6xA
# X6ht/+mSY0XxBTaVyMF8HnlASq4EmVF0p1AQJM2+q3dULxawKWSwl1P9G4Ga3eVu
# D/M2WW3KLWRVFmtTynMPMZrjJtFyX6FI18+lwyCQSa48V5RB4Lg69i9BykAynWcd
# KPLkPoqCj53CkBm0+nn0smxSP2hkTU20HC7A6DtI/lHKUCI9D0LBLHjkMVifg1zw
# aeyUlkXPj/aWSnH+B/pBCU6aGXusrev9razJL80HYTp633d1dGc7fwHeteFWuQ==
# SIG # End signature block
