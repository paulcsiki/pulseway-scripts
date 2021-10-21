<#
.SYNOPSIS
    Erases data on all drives and resets the operating system to a vanilla state.

.NOTES
    Version:        1.0
    Author:         David Retzer
    Creation Date:  30/04/2020
    Purpose/Change: First version
	Source:         https://techcommunity.microsoft.com/t5/windows-deployment/factory-reset-windows-10-without-user-intervention/m-p/1349038/highlight/true#M559

.EXAMPLE
    Copy and paste the contents of this script into a Pulseway PowerShell Automation Script.
    Run the script against the system you wish to remotely wipe.
	The script may take a few minutes to start the remote wipe process.
	
	WARNING:
	$methodname can be either "doWipeMethod" or "doWipeProtectedMethod". The later one will also wipe all data from the disks, especially if you want to refurbish the devices. The downside is that "doWipeProtectedMethod" can leave some clients (depending on configuration and hardware) in an unbootable state.

	Additionally "doWipeMethod" can be canceled by the user (power cycle for example), "doWipeProtectedMethod" cannot be canceled. It automatically resumes after a reboot until done. The higher risk is worth it most of the time. If you want to be sure that the devices will be in a usable state after the wipe, use "doWipeMethod" instead.
#>

$namespaceName = "root\cimv2\mdm\dmmap"
$className = "MDM_RemoteWipe"
$methodName = "doWipeProtectedMethod"

$session = New-CimSession

$params = New-Object Microsoft.Management.Infrastructure.CimMethodParametersCollection
$param = [Microsoft.Management.Infrastructure.CimMethodParameter]::Create("param", "", "String", "In")
$params.Add($param)

$instance = Get-CimInstance -Namespace $namespaceName -ClassName $className -Filter "ParentID='./Vendor/MSFT' and InstanceID='RemoteWipe'"
$session.InvokeMethod($namespaceName, $instance, $methodName, $params)
Exit(0);