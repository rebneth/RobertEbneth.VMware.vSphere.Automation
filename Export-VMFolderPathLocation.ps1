function Export-VMFolderPathLocation {
<#
.SYNOPSIS
  Creates a csv file with VMware VM's FolderPath
.DESCRIPTION
  Creates a csv file with VMware VM's FolderPath 
.NOTES
  Release 1.0
  Robert Ebneth
  March, 27th, 2017
.LINK
  http://github.com/rebneth/RobertEbneth.VMware.vSphere.Automation
.PARAMETER Filename
  The path and filename of the CSV file to use when exporting
  DEFAULT: $($env:USERPROFILE)\vSwitch_to_vmnic_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv
.EXAMPLE
  Export-VMFolderPathLocation -FILENAME d:\VMFolderPath.csv
#>

param(
    [Parameter(Mandatory = $false, Position = 1)]
    [alias("f")]
    [string]$FILENAME = "$($env:USERPROFILE)\VM_Folderpath_Location_$(get-date -f yyyy-MM-dd-HH-mm-ss).csv"
)


	# Check and if not loaded add powershell snapin
	if (-not (Get-PSSnapin VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
		Add-PSSnapin VMware.VimAutomation.Core}
    # We need the common function CheckFilePathAndCreate
    Get-Command "CheckFilePathAndCreate" -errorAction SilentlyContinue | Out-Null
    if ( $? -eq $false) {
        Write-Error "Function CheckFilePathAndCreate is missing."
        break
    }
    $OUTPUTFILENAME = CheckFilePathAndCreate "$FILENAME"


    Write-Host "############################################################"
    Write-Host "# Export vCenter VM Folder Structure and VM FolderLocation #"
    Write-Host "############################################################"	

    
    ###
    ### Export of the Folder Location for VMs
    ###

    $DataCenter = Get-Datacenter |select Name, Id
    $ALL_VM_Folders = Get-Folder -Type VM |select Name, Id, Parent, ParentId
    $AllVMs = Get-VM | Select Name, FolderId | Sort Name

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

    $VMFolderLocation = foreach ($vm in $AllVMs) {
        Select -InputObject $vm -Property @{N="VMName";E={$vm.Name}},
                                          @{N="VMFolderPath";E={($AllFolderInfo | Where { $_.FolderId -eq $vm.FolderId }).FolderPath}}
    }

    $VMFolderLocation | Sort VMName
    Write-Host "Writing Outputfile $($OUTPUTFILENAME)..."
    $VMFolderLocation | Export-csv -Delimiter ";" $OUTPUTFILENAME -Encoding UTF8 -noTypeInformation

} ### End Function
# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUXKFUlzUhtREKYOkFn5YwP1zs
# IBigggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUYff8Mweix2U1
# zbz6qPwqQbHSCMswDQYJKoZIhvcNAQEBBQAEggEAHkNgEG3MBo5tInNTMWjE1MEc
# 4acdBhLS5mvUFuYsWz6tHFhh7LSNqeV5BLEu2YJ8mh5fFfeS7nEyUtKjRS/5rHP1
# FG9r94+MMxkgAQMQlsNHIWQMwoTOUmM3I7p4pWjE70QqCpXY1cnnf+qB51FfIdwt
# zpj4p8HIuOHeyEtUTWTrhVm/Q0/gTLYT7H4MsgbUzFHyaADHlnmhG4xo562UvUDZ
# 57fVLLGs4gvwlv1UMtLyiSCOHVKvxpIJVYqIOCK8zfLh7SPWFyL8/Y10RDa2IUta
# 1cdro1Gtp5DVzOUeMvNZDtmjPjxoIAAUQnk284u65G39yOS7BiHtPZQpvXix/A==
# SIG # End signature block
