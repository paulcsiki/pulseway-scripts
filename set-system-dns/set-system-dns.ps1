<#
.SYNOPSIS
    Sets the DNS servers for NICs with a default gateway and notifies if the DNS settings were changed.

.NOTES
    Version:        1.0
    Author:         Alexandru Paul Csiki
    Creation Date:  16/10/2021
    Change Date:    02/11/2021
    Purpose/Change: Added support for IPv6

.EXAMPLE
    Copy and paste the contents of this script into a Pulseway PowerShell Automation Script.
    Link the newly created script into an Automation Task and run it.
#>

# Variables to be updated
$primaryIPv4DNSServer     = "8.8.8.8";
$secondaryIPv4DNSServer   = "1.1.1.1";                 # optional
$primaryIPv6DNSServer     = "2001:4860:4860::8888";    # optional
$secondaryIPv6DNSServer   = "2001:4860:4860::8844";    # optional
$pulsewayInstanceName     = "";                        # optional
$pulsewayUsername         = "";                        # optional
$pulsewayPassword         = "";                        # optional

$adapters = Get-NetIPConfiguration;
if ($adapters.Count -eq 0) {
    Write-Error -Category InvalidData "No network adapters were detected.";
    Exit(1);
}

$shouldNotify = $false;
for ($i = 0; $i -lt $adapters.Count; $i++) {
    $currentAdapter = $adapters[$i];

    if ($currentAdapter.IPv4DefaultGateway -ne $null -or $currentAdapter.IPv6DefaultGateway -ne $null) {
        Write-Output "Checking $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription))...";
        $updateDNS = $false;
        $primaryIPv6Found = $false;
        $secondaryIPv6Found = $false;
        $primaryIPv4Found = $false;
        $secondaryIPv4Found = $false;

		for ($j = 0; $j -lt $currentAdapter.DNSServer.Count; $j++) {
			$currentDNSServer = $currentAdapter.DNSServer[$j];
            for ($k = 0; $k -lt $currentDNSServer.ServerAddresses.Count; $k++) {
                $currentServerIP = $currentDNSServer.ServerAddresses[$k];

                if ($currentDNSServer.AddressFamily -eq 23) { # 23 = 'IPv6'
                    if ($primaryIPv6Found) {
                        if ($secondaryIPv6DNSServer -eq '' -or $secondaryIPv6DNSServer -ne $currentServerIP) {
                            $updateDNS = $true;
                            break;
                        }

                        $secondaryIPv6Found = $true;
                    } elseif ($secondaryIPv6Found) {
                        $updateDNS = $true;
                        Write-Output "More than two IPv6 DNS Servers found.";
                        break;
                    } else {
                        if ($primaryIPv6DNSServer -eq '') {
                            continue;
                        }

                        if ($primaryIPv6DNSServer -ne $currentServerIP) {
                            $updateDNS = $true;
                            break;
                        }
                        $primaryIPv6Found = $true;
                    }
                } else {
                    if ($primaryIPv4Found) {
                        if ($secondaryIPv4DNSServer -eq '' -or $secondaryIPv4DNSServer -ne $currentServerIP) {
                            $updateDNS = $true;
                            break;
                        }

                        $secondaryIPv4Found = $true;
                    } elseif ($secondaryIPv4Found) {
                        $updateDNS = $true;
                        Write-Output "More than two IPv4 DNS Servers found.";
                        break;
                    } else {
                        if ($primaryIPv4DNSServer -ne $currentServerIP) {
                            $updateDNS = $true;
                            break;
                        }
                        $primaryIPv4Found = $true;
                    }
                }
            }
		}
		
        if ($updateDNS -ne $true) {
            if ($secondaryIPv4DNSServer -ne '' -and $secondaryIPv4Found -ne $true) {
                $updateDNS = $true;
            } elseif ($primaryIPv6DNSServer -ne '' -and $primaryIPv6DNSServer -ne $true) {
                $updateDNS = $true;
            } elseif ($secondaryIPv6DNSServer -ne '' -and $secondaryIPv6DNSServer -ne $true) {
                $updateDNS = $true;
            }
        }

        if ($updateDNS) {
            Write-Output "Updating interface $($currentAdapter.InterfaceAlias) ($($currentAdapter.InterfaceDescription)) DNS servers...";
            Set-DnsClientServerAddress -InterfaceIndex $currentAdapter.InterfaceIndex -ServerAddresses ($primaryIPv4DNSServer, $secondaryIPv4DNSServer, $primaryIPv6DNSServer, $secondaryIPv6DNSServer);
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