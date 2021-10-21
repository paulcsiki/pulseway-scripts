<#
.SYNOPSIS
    Persists the computer identifier used by Pulseway to track endpoint registrations into a text file on a file share to support re-provisioning endpoints from a golden image.

.NOTES
    Version:        1.0
    Author:         Alexandru Paul Csiki
    Creation Date:  01/03/2020
    Purpose/Change: First version

.EXAMPLE
    Copy and paste the contents of this script into a file with the ps1 extension on the golden image.
    Create a scheduled task configured to run the script at startup like this: "powershell -executionpolicy bypass -noninteractive -file c:\pulseway_startup.ps1".
    Make sure that the PC Monitor service has the start mode set to Manual and you have the disabled (do not delete it as it will get re-created) the "PulsewayServiceCheck" scheduled task on the operating system.
	Also confirm that the ComputerIdentifier registry value is deleted from HKLM:\SOFTWARE\MMSOFT Design\PC Monitor.
#>

# Configuration
$username = "PULSEWAY\paul.csiki"
$password = "nottherealpassword"
$smbShareName = "PulsewayMountpoint"
$smbSharePath = "\\10.252.18.227\Pulseway"
$sharedStorageBasePath = $smbShareName + ':\StoredIdentifiers'
$cidFileName = $env:COMPUTERNAME.ToLower() + '.txt'
$fullCidPath = Join-Path -Path $sharedStorageBasePath -ChildPath $cidFileName
$serviceName = 'PC Monitor'
# Helper variables
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $username, ($password | ConvertTo-SecureString -AsPlainText -Force)
# Connect to SMB share
Remove-PSDrive -Name $smbShareName -ErrorAction SilentlyContinue
New-PSDrive -Name $smbShareName -PSProvider FileSystem -Root $smbSharePath -Credential $cred | Out-Null
# Main logic here
if (Test-Path -Path $fullCidPath) {
    $computerIdentifier = Get-Content -Path $fullCidPath
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor' -Name 'ComputerIdentifier' -Value $computerIdentifier
    Start-Service -Name $serviceName
} else {
    Start-Service -Name $serviceName
    while ((Get-Service -Name $serviceName).Status -ne 'Running') {
        Start-Sleep -Seconds 5
    }
    do {
        Start-Sleep -Seconds 5
        $computerIdentifier = Get-ItemProperty -Path 'HKLM:\SOFTWARE\MMSOFT Design\PC Monitor' -Name 'ComputerIdentifier'
    } while ([string]::IsNullOrWhiteSpace($computerIdentifier.ComputerIdentifier))
    Set-Content -Path $fullCidPath -Value $computerIdentifier.ComputerIdentifier
}
# Disconnect the SMB share
Remove-PSDrive -Name $smbShareName -ErrorAction SilentlyContinue 