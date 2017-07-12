##############################################################################
##
## RobertEbneth.VMware.vSphere.Automation 
## Powershell Script to create Powershell Module Manifest
## Release 1.0.0.3
## Date: 2017/07/12
##
## by Robert Ebneth
##
## ChangeLog:
## 1.0.0.3 Initial Release (supports PowerCLI V6.5)
##
##############################################################################

$ModuleName = "RobertEbneth.VMware.vSphere.Automation"
$ModulePath = "D:\Infos\Tools\Scripting\Powershell\VMware\PS Modules Robert\$($ModuleName)\$($ModuleName).psd1"
New-ModuleManifest -Path "$ModulePath"`
-Author "Robert Ebneth" -CompanyName "IT System Consulting Ebneth" -Copyright '(c)2017' `
-ModuleVersion 1.0.0.3 -Description 'PowerCLI Module for VMware vSphere Automation' `
-ProcessorArchitecture 'None' `
-ProjectUri "http://github.com/rebneth/$($ModuleName)" `
-PowerShellVersion 3.0 -RootModule .\$($ModuleName).psm1
Test-ModuleManifest -Path $ModulePath
$content = Get-Content -Path $ModulePath -Raw
$info = Invoke-Expression $content
$info

# SIG # Begin signature block
# MIIFmgYJKoZIhvcNAQcCoIIFizCCBYcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUIIi1vj8Cer5wjCHWoSxifcSN
# N5ygggMmMIIDIjCCAgqgAwIBAgIQPWSBWJqOxopPvpSTqq3wczANBgkqhkiG9w0B
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
# AYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUEp5p9jvrlBDs
# DGzxKm6vDdihiRowDQYJKoZIhvcNAQEBBQAEggEAbBbAfr/+uQorsmpbVvA7/UPV
# LnCgibRat6RSyj9JVPIZLsx3pYXP5e9vTNkb2V8X6guT4YO+gWEtw0aRX+47rFlc
# 5FthbfuBIsGFdDXpDHyYJ3VgGcoKO7ddQA69S3Mg4VxZut2CaDVMvzYEFu4GfzDG
# 8gRP0cOUdtCoZe00pMCdRjTqw30ZNESSahqQRvoRUJb8Z+ibxOk2MW1HBL3VGwP2
# EhV7NKOHQcmnBI/G4wvgko4+PFkwpiqatcEWbQXS36zKnmyO3tyEi9NJ4CVEweWZ
# STJ+ETjeOp8bV0UtKI2WJXrkt+ak8DJnc5DNHWe3AawKLkgJn46WO4A19CsL1Q==
# SIG # End signature block
