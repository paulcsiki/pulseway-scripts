<#
.SYNOPSIS
    Prints the status of Bitlocker for all logical volumes.

.NOTES
    Version:        1.0
    Author:         Alexandru Paul Csiki
    Creation Date:  16/10/2021
    Purpose/Change: First version

.EXAMPLE
    Copy and paste the contents of this script into a Pulseway PowerShell Automation Script.
    Link the newly created script into an Automation Task and run it.
    Create a new report based on the "Task Execution Output" and select the newly create Task as it's data source.
    Run the report to view the results of the script.
#>

$status = Get-BitLockerVolume;
if ($status.Count -eq 0) {
    Write-Error -Category InvalidData "No volumes were detected.";
    Exit(1);
}

$fullyEncryptedVolumes = 0;
for ($i = 0; $i -lt $status.Count; $i++) {
    $currentVolume = $status[$i];

    if ($currentVolume.VolumeStatus -eq 'FullyEncrypted') {
        $fullyEncryptedVolumes++;
    }
}

$allDisksEncrypted = $fullyEncryptedVolumes -eq $status.Count;
if ($allDisksEncrypted) {
    Write-Output "STATUS: All voumes are encrypted";
} elseif ($fullyEncryptedVolumes -gt 0) {
    Write-Output "STATUS: Only $($fullyEncryptedVolumes) volume$(If ($fullyEncryptedVolumes -eq 1) {''} Else {'s'}) encrypted out $($status.Count) total volume $(If ($status.Count -eq 1) {''} Else {'s'}).";
} else {
    Write-Output "STATUS: $($status.Count) volume$(If ($status.Count -eq 1) {' is '} Else {'s are'}) not encrypted.";
}

Write-Output $status
Exit(0);