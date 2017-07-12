function Set-VMFolderPathLocation {
<#
.SYNOPSIS
  Check FolderPath from all VMs against stored FolderPath
  If different, move VM to stored Folder Path for this VM
.DESCRIPTION
  Check FolderPath from all VMs against stored FolderPath
  If different, move VM to stored Folder Path for this VM
  to that Resource Pool.
.NOTES
  Release 1.1
  Robert Ebneth
  July, 12thth, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER FILENAME
  Name of the csv input file for the VMs Folder Location
.EXAMPLE
  Set-VMFolderPathLocation -FILENAME d:\VMFolderPath.csv
#>

# We support Move of VMs to different Folder only if -Confirm:$true
[CmdletBinding(ConfirmImpact='High', SupportsShouldProcess=$true )]
param(
    [Parameter(Mandatory = $false, Position = 1)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\VM_Folderpath_Location_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)

    ########
    # Main #
    ########

    # Check and if not loaded add Powershell core module
    if ( !(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) ) {
        Import-Module VMware.VimAutomation.Core
    }
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
    if ((Test-Path -Path $($FILENAME) ) -eq $False)
	    { Write-Error "Missing Input File: $FILENAME"; break}

    Write-Host "##################################################################"
    Write-Host "# Check VMware VMs FolderLocation and optional move VM to Folder #"
    Write-Host "##################################################################"	

    Write-Host "Reading File $($FILENAME)..."
    $BackupVMsFolderPath = Import-Csv -Delimiter ";" $FILENAME

    ###
    ### Create current Folder structure for VMs
    ###

    $DataCenter = Get-Datacenter |select Name, Id
    $ALL_VM_Folders = Get-Folder -Type VM |select Name, Id, Parent, ParentId
    $AllVMs = Get-VM | Select Name, FolderId | Sort name

    $AllFolderInfo = foreach($VMFolder in $ALL_VM_Folders) {
                Select -InputObject $VMFolder -Property @{N="FolderName";E={$VMFolder.Name}},
                                                        @{N="FolderId";E={$VMFolder.Id}},
                                                        @{N="Parent";E={$VMFolder.Parent}},
                                                        @{N="ParentId";E={$VMFolder.ParentId}},
                                                        @{N="FolderPath";E={                                                        
        $FolderPath = ""
        $FolderToCheck = $VMFolder
        While ($FolderToCheck.ParentId -ne $DataCenter.Id) {
            $UpperFolder = $ALL_VM_Folders | Where { $_.Id -eq $FolderToCheck.ParentId }
            $FolderPath = "\" + "$($FolderToCheck.Name)" + $FolderPath
            $FolderToCheck = $UpperFolder
        }
        $FolderPath = "\" + "$($FolderToCheck.Name)" + $FolderPath
        $FolderPath}}
    }

    $CurrentVMFolderLocation = foreach ($vm in $AllVMs) {
        Select -InputObject $vm -Property @{N="VMName";E={$vm.Name}},
                                          @{N="VMFolderPath";E={($AllFolderInfo | Where { $_.FolderId -eq $vm.FolderId }).FolderPath}}
    }

    ###
    ### Start VMs FolderCheck
    ###
    
    foreach ($vm in $CurrentVMFolderLocation) {
        # check if there is a FolderPathInfo for this VM in input file
        $storedVMFolderPathInfo = $BackupVMsFolderPath | Where { $_.VMName -eq $vm.VMName }
        if (-not $storedVMFolderPathInfo ) {
            Write-Host "FolderPath for VM $($vm.VMName) not found in input file. Nothing to do..." -ForegroundColor Red
            continue
        }
        if ( "$($vm.VMFolderPath)" -eq "$($storedVMFolderPathInfo.VMFolderPath)" ) {
            Write-Host "VM $($vm.VMName) already in FolderPath $($vm.VMFolderPath). Nothing to do..."
            continue
        }
        Write-Host "VM $($vm.VMName) has to be moved from Folder $($vm.VMFolderPath) to Folder $($storedVMFolderPathInfo.VMFolderPath)" -ForegroundColor Yellow
        $DestinationFolder = $AllFolderInfo | Where { $_.FolderPath -eq $($storedVMFolderPathInfo.VMFolderPath)}
        if ( -not $DestinationFolder ) {
            Write-Host "Destination Folder $($storedVMFolderPathInfo.VMFolderPath) for VM $($vm.VMName) not Found. Create Destination Folder $($storedVMFolderPathInfo.VMFolderPath) and repeat script." -ForegroundColor Red
            continue }
        $doit = $PSCmdlet.ShouldProcess("WhatIf: ","Moving VM $($vm.VMName) to FolderPath $($storedVMFolderPathInfo.VMFolderPath)")
            if ($doit) {
                if ($PSCmdlet.ShouldProcess("$($storedVMFolderPathInfo.VMFolderPath)", "Moving VM $($vm.VMName) to new Destination Folder "))
                    {Write-Host "Moving VM $($vm.VMName) to Folder $($storedVMFolderPathInfo.VMFolderPath)"
                    Move-VM -VM $($vm.VMName) -Destination (Get-Folder -Id $($DestinationFolder.FolderId))
                }
                else { Write-Host "Skipping Move VM $($vm.VMName) to Folder $($storedVMFolderPathInfo.VMFolderPath)" }
            }
    }

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUp+7+ta37xzpezkLacUb8tBTv
# th+gggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQU+EDmXGiIQ3ig
# m3oYoi9uSZJ3DEkwDQYJKoZIhvcNAQEBBQAEggEARiUu1bfFOEdB/C56fY9rJAo5
# GeSnYlLzgzmGlJ4d7yqKYnNotkLMsXpL40Xd8BHvqK3V0vMCPP2ZbVMZU0V2aI2F
# IgIh5slMXdmYf2yVqdWdZXXpi/gS3Ao+r/61T5GFb+/2FM+hq1jVova8saDzEj0o
# BQfYfmzhwznsLNPpGzprZz3QuSvbEOy8BDLipeDtP0y4xn2a/eOK85ohX2euUKKC
# P2CQHNIFQncvHBR8O1xSUgrm6Aj4tJT55A1FNuVARtgveE/QM3ZfSfVXOZ7ayRa8
# 16TmmUgoVwwKw3W42NHA7wVscgKrEmDWs4eh2/sL3VrvO0uh4iIuP5nCch3aKA==
# SIG # End signature block
