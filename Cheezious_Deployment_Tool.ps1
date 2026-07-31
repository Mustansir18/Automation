[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 -bor [Net.SecurityProtocolType]::Tls13
Set-ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue

Clear-Host
[Console]::Title = "Cheezious_Installation.ps1"

# --- HASH STORE FOR MENU OPTIONS ---
$Hash_RSSU  = "75C47A15DEC794F4571A5B08E1676830CD19169428A666A274B697B03B256D83"
$Hash_POS   = "A30B8E30567073ADB115C157B5CCB7EC27E3199CF25B689913A83748DE20D16B"
$Hash_Kiosk = "48CF3EEB9D24E8326E30144BF4E9DDC1303C3255034DBFFE28B8A7BC876E5D74"

function Test-OptionPassword ($TargetHash, $ModuleName) {
    $MaxAttempts = 3
    $Attempt = 0
    $Authenticated = $false

    Write-Host "
 [SECURITY LOCK] $ModuleName requires authorization." -ForegroundColor Yellow

    while ($Attempt -lt $MaxAttempts -and -not $Authenticated) {
        $Attempt++
        $InputSecure = Read-Host -Prompt " Enter Password for $ModuleName ($Attempt/$MaxAttempts)" -AsSecureString
        
        # Convert SecureString to Plain Text for Hashing
        $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($InputSecure)
        $InputPlain = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        
        # Compute SHA-256 Hash
        $InputBytes = [System.Text.Encoding]::UTF8.GetBytes($InputPlain)
        $InputHashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash($InputBytes)
        $InputHash = [BitConverter]::ToString($InputHashBytes) -replace '-'
        
        if ($InputHash -eq $TargetHash) {
            $Authenticated = $true
            Write-Host " [+] Access Granted for $ModuleName." -ForegroundColor Green
            Start-Sleep -Seconds 1
        } else {
            Write-Host " [-] Invalid Password!" -ForegroundColor Red
        }
    }

    if (-not $Authenticated) {
        Write-Host " [!] Authentication failed. Access Denied." -ForegroundColor Red
    }

    return $Authenticated
}

# --- REAL-TIME TELEMETRY COMPUTATION ---

# 1. Operating System
try {
    $SysOS = (Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue).Caption.Replace("Microsoft ", "").Trim()
} catch { $SysOS = "Windows OS" }

# 2. CPU Full Name
try {
    $SysCPU = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1).Name.Trim() -replace '\s+', ' '
} catch { $SysCPU = "Intel / AMD Processor" }

# 3. Real-Time CPU Utilization (%)
try {
    $CpuLoad = (Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Measure-Object -Property LoadPercentage -Average).Average
    $CpuLoadRound = [math]::Round($CpuLoad)
    $SysCPULoad = "$CpuLoadRound%"
} catch { $SysCPULoad = "N/A" }

# 4. Real-Time RAM Utilization
try {
    $osCim = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    $totalRamGB = $osCim.TotalVisibleMemorySize / 1MB
    $freeRamGB  = $osCim.FreePhysicalMemory / 1MB
    $usedRamGB  = $totalRamGB - $freeRamGB
    $ramPercent = [math]::Round(($usedRamGB / $totalRamGB) * 100)
    $usedRamRounded  = [math]::Round($usedRamGB, 1)
    $totalRamRounded = [math]::Round($totalRamGB, 1)
    $SysRAM = "$usedRamRounded GB / $totalRamRounded GB ($ramPercent%)"
} catch { $SysRAM = "N/A" }

# 5. Local IP Address
try {
    $SysIP = (Get-NetIPAddress -AddressFamily IPv4 -Type Unicast -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike "169.254*" -and $_.IPAddress -ne "127.0.0.1" } | Select-Object -First 1).IPAddress
    if (-not $SysIP) { $SysIP = "N/A" }
} catch { $SysIP = "N/A" }

# 6. DNS Servers
try {
    $dnsAddrs = Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.ServerAddresses } | Select-Object -ExpandProperty ServerAddresses
    if ($dnsAddrs) {
        $SysDNS = (($dnsAddrs | Select-Object -Unique) -join ", ")
    } else { $SysDNS = "N/A" }
} catch { $SysDNS = "N/A" }

# 7. Max Network Link Speed
try {
    $netAdapter = Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object Status -eq 'Up' | Select-Object -First 1
    if ($netAdapter) {
        $SysSpeed = $netAdapter.LinkSpeed
    } else { $SysSpeed = "N/A" }
} catch { $SysSpeed = "N/A" }

# 8. Disk C: Free / Total
try {
    $DiskC = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'" -ErrorAction SilentlyContinue
    $FreeGB = [math]::Round($DiskC.FreeSpace / 1GB)
    $TotalGB = [math]::Round($DiskC.Size / 1GB)
    $SysDisk = "$FreeGB GB Free / $TotalGB GB"
} catch { $SysDisk = "N/A" }

# 9. Shell Version & Timestamp
$SysShell = "PowerShell " + $PSVersionTable.PSVersion.Major + "." + $PSVersionTable.PSVersion.Minor
$SysDate  = (Get-Date).ToString("MMM dd, yyyy  hh:mm tt")

# Truncate two-column field strings if they exceed cell width
if ($SysOS.Length -gt 38)    { $SysOS   = $SysOS.Substring(0,35) + "..." }
if ($SysDNS.Length -gt 38)   { $SysDNS  = $SysDNS.Substring(0,35) + "..." }
if ($SysCPU.Length -gt 88)   { $SysCPU  = $SysCPU.Substring(0,85) + "..." }

# --- TOP BANNER ---
Write-Host ""
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkYellow
Write-Host "|   ____ _   _ _____ _____ _____ _____ _____ _   _ _____                                            |" -ForegroundColor Yellow
Write-Host "|  / ___| | | |  ___|  ___|___  |_   _/ _ \ | | /  ___|                   Created by                |" -ForegroundColor Yellow
Write-Host "| | |   | |_| | |___| |___   / /  | || | | | | | \ \__                   Mustansir Ali              |" -ForegroundColor Yellow
Write-Host "| | |___|  _  |  ___|  ___| / /_ _| || |_| | |_| |___) |                     >_                     |" -ForegroundColor Yellow
Write-Host "|  \____|_| |_|_____|_____|/____|_____\___/ \___/ |____/                                            |" -ForegroundColor Yellow
Write-Host "|                     Spreeding Cheezy Khushiyan                                                   |" -ForegroundColor White
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkYellow

Write-Host ""
Write-Host "------------------------------ [ WELCOME TO CHEEZIOUS INSTALLER ] -----------------------------------" -ForegroundColor Green
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host "| (i) This script will help you install and configure Cheezious systems.                            |" -ForegroundColor Cyan
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkGray

Write-Host ""
Write-Host "------------------------------------ [ SELECT AN OPTION ] ------------------------------------------" -ForegroundColor Magenta

Write-Host "+---------------------------------+ +---------------------------------+ +---------------------------------+" -ForegroundColor DarkGray
Write-Host "| [1] RSSU INSTALLATION           | | [2] POS INSTALLATION            | | [3] KIOSK INSTALLATION          |" -ForegroundColor White
Write-Host "|     Install / Configure Server  | |     Install / Configure POS     | |     Install / Configure Kiosk |" -ForegroundColor Gray
Write-Host "+---------------------------------+ +---------------------------------+ +---------------------------------+" -ForegroundColor DarkGray
Write-Host "+---------------------------------+ +---------------------------------+ +---------------------------------+" -ForegroundColor DarkGray
Write-Host "| [4] SERVER ACTIVATION           | | [5] WINDOWS + EXCEL ACTIVATION  | | [6] EXIT                        |" -ForegroundColor White
Write-Host "|     Activate Server Edition     | |     Activate Win & Office       | |     Close Application           |" -ForegroundColor Gray
Write-Host "+---------------------------------+ +---------------------------------+ +---------------------------------+" -ForegroundColor DarkGray

Write-Host ""
Write-Host "----------------------------------- [ SYSTEM INFORMATION ] -----------------------------------------" -ForegroundColor DarkYellow
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkGray
Write-Host ("| CPU Model:  {0,-85} |" -f $SysCPU) -ForegroundColor Cyan
Write-Host ("| OS:         {0,-38} | IP:        {1,-38} |" -f $SysOS, $SysIP) -ForegroundColor Cyan
Write-Host ("| CPU Load:   {0,-38} | DNS:       {1,-38} |" -f $SysCPULoad, $SysDNS) -ForegroundColor Cyan
Write-Host ("| RAM Used:   {0,-38} | Max Speed: {1,-38} |" -f $SysRAM, $SysSpeed) -ForegroundColor Cyan
Write-Host ("| Disk C:     {0,-38} | Shell:     {1,-38} |" -f $SysDisk, $SysShell) -ForegroundColor Cyan
Write-Host ("| Date:       {0,-38} | Status:    {1,-38} |" -f $SysDate, "Online") -ForegroundColor Cyan
Write-Host "+---------------------------------------------------------------------------------------------------+" -ForegroundColor DarkGray

Write-Host ""
Write-Host " TIP: Use the number keys (1-6) to select an option and press Enter." -ForegroundColor Yellow
Write-Host ""

$Selection = Read-Host " PS C:\Cheezious_Installer>"

# RECONSTRUCT KEY AT RUNTIME
[byte[]]$Masked = @(0x19,0x07,0xF9,0x77,0x30,0x56,0xF3,0x7D,0x35,0x5A,0xF1,0x61,0x09,0x5C,0xE9,0x7B,0x0E,0x54,0xEF,0x66,0x3F,0x5A,0xF1,0x7E,0x37,0x5B,0xF6,0x66,0x6A,0x0F,0xAE,0x24)
[byte[]]$Mask   = @(0x5A,0x3F,0x9C,0x12)
[byte[]]$Key    = New-Object byte[] $Masked.Length

for ($i = 0; $i -lt $Masked.Length; $i++) {
    $Key[$i] = $Masked[$i] -bxor $Mask[$i % $Mask.Length]
}

function Invoke-DecryptedInstaller ($Cipher, $IV, $Label) {
    Write-Host "
  [+] Decrypting and launching $Label..." -ForegroundColor Green
    try {
        $Aes = [System.Security.Cryptography.Aes]::Create()
        $Aes.Key = $Key
        $Aes.IV  = [Convert]::FromBase64String($IV)

        $Decryptor = $Aes.CreateDecryptor()
        $CipherBytes = [Convert]::FromBase64String($Cipher)
        $DecryptedBytes = $Decryptor.TransformFinalBlock($CipherBytes, 0, $CipherBytes.Length)
        $Url = [System.Text.Encoding]::UTF8.GetString($DecryptedBytes)

        $ScriptText = Invoke-RestMethod -Uri $Url -Method Get -UseBasicParsing
        if ([string]::IsNullOrWhiteSpace($ScriptText)) { throw "Downloaded script was empty." }
        Invoke-Expression $ScriptText
    } catch {
        Write-Host "
  [CRITICAL ERROR] Execution failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --- PASSWORD PROTECTED SELECTION HANDLING ---
if ($Selection -eq '1') {
    if (Test-OptionPassword -TargetHash $Hash_RSSU -ModuleName "RSSU Installation") {
        Invoke-DecryptedInstaller -Cipher "YGrA8GEn+mzNLYT/42Nh61a8Ze44LIG80Z8JM7pckXJmIbZN4gLPi7DO1prOmVUX++SnxrOktx7gQPzVB19q1IoVEcy49+guKc9GUBbBVdH/w/BA1qi+eW9n7scrHjoHVPPN1HNLn+luYt3kxDT4su6VZgCz2jd3C/xWvdeJ/01lqQ+gDdapL3iJjmORYVjHoMIHL/mA6w12BRfwWUmXAjm85UP57BLbSwQ5fStulangbt1khFjB/C4BJSUIJLi0Yi8zjsjXwwF2UEXXs7+ifCM3r093Ava2umrt2+Nx/eA=" -IV "wD6moz6DgVTg9pabr8wUpA==" -Label "RSSU Installation"
    }
} elseif ($Selection -eq '2') {
    if (Test-OptionPassword -TargetHash $Hash_POS -ModuleName "POS Installation") {
        Invoke-DecryptedInstaller -Cipher "P7pum6I8tM/IffO1lvR5DbkcdlkpAF9w++gRe0ChItTX/IIFYWM5cEMftDlDgX2cmL5cO1pNcSN+DxaBLxAiLZo2mytzLu5ASpjOGcc5T9AUwsf3zJyy3W+HeSsP2l2Lhls9cpFj/L9umtt2w0DxeqV5BZtOI3a007zpwR6qjYNpqkk+95hTQcUy3GhK6fMLlCo6o0vVIZMyMQYaSjOL1h+tRNz3QEgPuqFfzG+gkydDYupxOQfUm40bpFbXY+bykgGjGpe9NjhN3Zy3ECPmSQ==" -IV "cKrFRK8l/+eUfiz7PxBwSg==" -Label "POS Installation"
    }
} elseif ($Selection -eq '3') {
    if (Test-OptionPassword -TargetHash $Hash_Kiosk -ModuleName "Kiosk Installation") {
        Invoke-DecryptedInstaller -Cipher "Z0GYPey/P3aHCYuhgmkkszmkLk5LkEs7kzdF8l7RJYe2fw9L9ikknzYIFX5UBq3HnjCLyNTPAXAY7ySJDbgXxuEga6Sv8qpIwP3pcWK3lPfgo3wFDuzFt3NoIEJtMlql6wrssq2GFFlzChtWyVD++q+AoHSyz6VFUXRSsMhAmWiaQvSN2kSJeRAYeYH9pNYXlFPbBHOLOnKF4TXHoIT/6osersjgq0XNiZn13Q3wBaPTg2XFEKUkKUleEDZySCVW961wFZ+BDBqpX5vwAcQM1A==" -IV "5itQgNn+Yx3cXD87pwlsOg==" -Label "Kiosk Installation"
    }
} elseif ($Selection -eq '4') {
    Write-Host "
  [+] Running Server Windows Activation in background..." -ForegroundColor Green
    Start-Job -ScriptBlock {
        cscript //nologo C:\Windows\System32\slmgr.vbs -rearm | Out-Null
        DISM /Online /Get-TargetEditions | Out-Null
        DISM /online /Set-Edition:ServerStandard /ProductKey:VDYBN-27WPP-V4HQT-9VMD4-VMK7H /AcceptEula /NoRestart | Out-Null
    } | Out-Null
    Write-Host "  [+] Server activation job initiated." -ForegroundColor Cyan
} elseif ($Selection -eq '5') {
    Write-Host "
  [+] Running Windows + Office/Excel Activation in background..." -ForegroundColor Green
    Start-Job -ScriptBlock {
        irm https://get.activated.win | iex
    } | Out-Null
    Write-Host "  [+] Activation script launched." -ForegroundColor Cyan
} else {
    Write-Host "
  Exiting installer." -ForegroundColor Yellow
    Exit
}

Write-Host "
===================================================================================================" -ForegroundColor DarkYellow
Read-Host " Press ENTER to exit..."
