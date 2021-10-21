<#
.SYNOPSIS
    Sets the DNS servers for NICs with a default gateway and notifies if the DNS settings were changed.

.NOTES
    Version:        1.0
    Author:         Alexandru Paul Csiki
    Creation Date:  16/10/2021
    Purpose/Change: First version

.EXAMPLE
    Copy and paste the contents of this script into a Pulseway PowerShell Automation Script.
    Link the newly created script into an Automation Task and run it.
#>

# Variables to be updated
$primaryDNSServer     = "8.8.8.8";
$secondaryDNSServer   = "1.1.1.1";                     # optional
$pulsewayInstanceName = "";                            # optional
$pulsewayUsername     = "";                            # optional
$pulsewayPassword     = "";                            # optional

$adapters = Get-NetIPConfiguration;
if ($adapters.Count -eq 0) {
    Write-Error -Category InvalidData "No network adapters were detected.";
    Exit(1);
}

$shouldNotify = $false;
for ($i = 0; $i -lt $adapters.Count; $i++) {
    $currentAdapter = $adapters[$i];

    if ($currentAdapter.IPv4DefaultGateway -ne $null) {
        Write-Output "Checking $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription))...";
        $updatePrimaryDNS = ($currentAdapter.DNSServer.Count -lt 1) -or ($currentAdapter.DNSServer[0].Address.ToString() -ne $primaryDNSServer);
        $updateSecondaryDNS = ($secondaryDNSServer -ne "") -and (($currentAdapter.DNSServer.Count -lt 2) -or ($currentAdapter.DNSServer[1].Address.ToString() -ne $secondaryDNSServer));

        if ($updatePrimaryDNS -or $updateSecondaryDNS) {
            Write-Output "Updating interface $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription)) DNS servers...";
            if ($secondaryDNSServer -ne "") {
                Set-DnsClientServerAddress -InterfaceIndex $currentAdapter.InterfaceIndex -ServerAddresses ($primaryDNSServer, $secondaryDNSServer);
            } else {
                Set-DnsClientServerAddress -InterfaceIndex $currentAdapter.InterfaceIndex -ServerAddresses ($primaryDNSServer);
            }
            $shouldNotify = $true;
            Write-Output "Interface $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription)) DNS servers updated.";
        }
    }
}

if ($shouldNotify -and $pulsewayInstanceName -ne "" -and $pulsewayUsername -ne "" -and $pulsewayPassword -ne "") {
    $apiUrl = "https://$pulsewayInstanceName/api/v2/notifications";
    $computerIdentifier = (Get-ItemProperty -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor" -Name "ComputerIdentifier").ComputerIdentifier;
    $computerName = (Get-ItemProperty -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor" -Name "ComputerName").ComputerName;
    $computerGroup = (Get-ItemProperty -Path "HKLM:\SOFTWARE\MMSOFT Design\PC Monitor" -Name "GroupName").GroupName;
    $requestJSON = "{""instance_id"":""$computerIdentifier"",""title"":""DNS servers changed on computer '$computerName' in group '$computerGroup'."",""priority"":""elevated""}";
    $authenticationPair = "$($pulsewayUsername):$($pulsewayPassword)";
    $authenticationPairEncoded = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($authenticationPair));
    $basicAuthHeaderValue = "Basic $authenticationPairEncoded";
    $requestHeaders = @{
        Authorization = $basicAuthHeaderValue
    }

    $result = Invoke-WebRequest -UseBasicParsing -Uri $apiUrl -Headers $requestHeaders -Method Post -Body $requestJSON -TimeoutSec 30 -ContentType "application/json";
    if ($result.StatusCode -eq 200) {
        Write-Output "Notification sent successfully.";
    } else {
        Write-Output "Failed to send the Pulseway notification. Server Response $($result.StatusCode): $($result.Content)";
    }
}
Exit(0);