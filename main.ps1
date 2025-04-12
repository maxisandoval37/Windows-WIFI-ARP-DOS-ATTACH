[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Scan-Networks {
    Write-Host "Scanning available Wi-Fi networks..." -ForegroundColor Cyan
    $rawOutput = netsh wlan show networks mode=bssid

    if (-not $rawOutput) {
        Write-Host "No Wi-Fi networks found." -ForegroundColor Red
        exit
    }

    $networks = @()
    $currentSSID = ""
    foreach ($line in $rawOutput) {
        if ($line -match "^\s*SSID\s+\d+\s+:\s+(.+)$") {
            $currentSSID = $matches[1]
            if (-not $networks.Contains($currentSSID)) {
                $networks += $currentSSID
            }
        }
    }

    return @{ SSIDs = $networks; RawData = $rawOutput }
}

function Show-Networks($networkList) {
    Write-Host "`nAvailable Wi-Fi Networks:" -ForegroundColor Green
    for ($i = 0; $i -lt $networkList.Count; $i++) {
        Write-Host "[$($i+1)] $($networkList[$i])"
    }
}

function Show-NetworkDetails($selectedSSID, $rawData) {
    Write-Host "`nShowing details for: $selectedSSID`n" -ForegroundColor Yellow
    $show = $false
    foreach ($line in $rawData) {
        if ($line -match "^\s*SSID\s+\d+\s+:\s+(.+)$") {
            $show = ($matches[1].Trim() -eq $selectedSSID)
        }
        if ($show) {
            Write-Host $line
        }
    }
}

# Main loop
do {
    $result = Scan-Networks
    $ssids = $result["SSIDs"]
    $raw = $result["RawData"]

    Show-Networks $ssids

    $validSelection = $false
    do {
        $input = Read-Host "`nSelect a network number to view details (or type 'q' to quit)"
        if ($input -eq 'q') { exit }

        if ($input -match '^\d+$') {
            $index = [int]$input - 1
            if ($index -ge 0 -and $index -lt $ssids.Count) {
                $validSelection = $true
                $selected = $ssids[$index]
                Show-NetworkDetails $selected $raw
            } else {
                Write-Host "Number out of range." -ForegroundColor Red
            }
        } else {
            Write-Host "Invalid input. Please enter a number or 'q' to quit." -ForegroundColor Red
        }
    } while (-not $validSelection)

    Write-Host "`nDo you want to view another network? (y/n)"
    $continue = Read-Host
} while ($continue -eq 'y')