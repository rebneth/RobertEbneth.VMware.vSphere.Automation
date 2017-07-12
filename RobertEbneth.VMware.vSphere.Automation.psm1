#################################################################################
##
## RobertEbneth.VMware.vSphere.Automation.psm1
## Cmdlets and Functions that are used for VMware vSphere Deployment / Automation
## Release 1.0.0.3
## Date: 2017/07/12
##
## by Robert Ebneth
##
#################################################################################

# Load external Powershell functions
. $PSScriptRoot\Create-ESXiNetworkPortgroup.ps1
. $PSScriptRoot\DeployVMfromTab.ps1
. $PSScriptRoot\Export-VMFolderPathLocation.ps1
. $PSScriptRoot\Export-vCenterResourcePools.ps1
. $PSScriptRoot\Import-vCenterResourcePools.ps1
. $PSScriptRoot\Prepare-SAN-Lun-Detach.ps1
. $PSScriptRoot\Remove-vDSPortgroup.ps1
. $PSScriptRoot\Set-VMFolderPathLocation.ps1
. $PSScriptRoot\Set-VMResourcePool.ps1
. $PSScriptRoot\Set-VAAISettings.ps1
. $PSScriptRoot\Get-VAAISettings.ps1
. $PSScriptRoot\Set-VMHostiSCSISettings.ps1
. $PSScriptRoot\Get-VMHostsshConfig.ps1
. $PSScriptRoot\Get-VMHostNTPConfig.ps1
. $PSScriptRoot\Set-VMCBTenable.ps1
. $PSScriptRoot\Set-VMCBTReset.ps1
. $PSScriptRoot\vSphereHardening-VM.ps1


# This is optional but Best Practice
Export-ModuleMember -function DeployVMfromTab
Export-ModuleMember -function Export-VMFolderPathLocation
Export-ModuleMember -function Export-vCenterResourcePools
Export-ModuleMember -function Import-vCenterResourcePools
Export-ModuleMember -function Prepare-SAN-Lun-Detach-Remove
Export-ModuleMember -function Remove-vDSPortgroup
Export-ModuleMember -function Set-VMFolderPathLocation
Export-ModuleMember -function Set-VMResourcePool
Export-ModuleMember -function Set-VAAISettings
Export-ModuleMember -function Get-VAAISettings
Export-ModuleMember -function Set-VMHostiSCSISettings
Export-ModuleMember -function Get-VMHostsshConfig
Export-ModuleMember -function Get-VMHostNTPConfig
Export-ModuleMember -function Set-VMCBTenable
Export-ModuleMember -function Set-VMCBTReset
Export-ModuleMember -function vSphereHardening-VM