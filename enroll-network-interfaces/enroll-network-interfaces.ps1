<#
.SYNOPSIS
    Enrolls network interfaces that are active into Pulseway.

.NOTES
    Version:        1.0
    Author:         Alexandru Paul Csiki
    Creation Date:  28/04/2022

.EXAMPLE
    Copy and paste the contents of this script into a Pulseway PowerShell Automation Script.
    Link the newly created script into an Automation Task and run it.
#>

$adapters = Get-NetAdapter;
if ($adapters.Count -eq 0) {
    Write-Error -Category InvalidData "No network adapters were detected.";
    Exit(1);
}

$interfacesToEnroll = [System.Collections.ArrayList]@();
for ($i = 0; $i -lt $adapters.Count; $i++) {
    $currentAdapter = $adapters[$i];

    if ($currentAdapter.Status -eq 'Up' -and -not ($currentAdapter.Virtual) -and -not ($currentAdapter.Hidden) -and $currentAdapter.MacAddress -ne '') {
        Write-Output "Enrolling $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription))...";
        $interfacesToEnroll.Add($currentAdapter.InterfaceGuid) | Out-Null;
    }
}

if ($interfacesToEnroll.Count -gt 0) {
    if (-not(Test-Path -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\NetworkInterfaces")) {
        New-Item -Force -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\NetworkInterfaces";
    }

    for ($i = 0; $i -lt $interfacesToEnroll.Count; $i++) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\NetworkInterfaces" -Name "Service$($i)" -Value $interfacesToEnroll[$i].ToString();
    }
    Set-ItemProperty -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor\NetworkInterfaces" -Name "Count" -Value $interfacesToEnroll.Count.ToString();
    Exit(0);
}

Write-Output "No active adapters found.";
Exit(1);