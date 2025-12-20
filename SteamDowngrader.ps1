#Requires -Version 5.1
# Steam 32-bit Downgrader with Christmas Theme
# Gets Steam path from registry and runs with specified parameters

# Clear screen
Clear-Host

# Christmas-themed header
Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "        Steam 32-bit Downgrader - Custom SteamHomeBrew Edition!" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host ""

# Function to get Steam path from registry
function Get-SteamPath {
    $steamPath = $null
    
    Write-Host "Searching for Steam installation..." -ForegroundColor Gray
    
    # Try HKCU first (User registry)
    $regPath = "HKCU:\Software\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "SteamPath" -ErrorAction SilentlyContinue).SteamPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    # Try HKLM (System registry)
    $regPath = "HKLM:\Software\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    # Try 32-bit registry on 64-bit systems
    $regPath = "HKLM:\Software\WOW6432Node\Valve\Steam"
    if (Test-Path $regPath) {
        $steamPath = (Get-ItemProperty -Path $regPath -Name "InstallPath" -ErrorAction SilentlyContinue).InstallPath
        if ($steamPath -and (Test-Path $steamPath)) {
            return $steamPath
        }
    }
    
    return $null
}

# Function to download file with inline progress bar
function Download-FileWithProgress {
    param(
        [string]$Url,
        [string]$OutFile
    )
    
    try {
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $response = $request.GetResponse()
        $totalLength = $response.ContentLength
        $response.Close()
        
        $request = [System.Net.HttpWebRequest]::Create($Url)
        $response = $request.GetResponse()
        $responseStream = $response.GetResponseStream()
        $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $OutFile, Create
        
        $buffer = New-Object byte[] 10KB
        $count = $responseStream.Read($buffer, 0, $buffer.Length)
        $downloadedBytes = $count
        $lastUpdate = Get-Date
        
        while ($count -gt 0) {
            $targetStream.Write($buffer, 0, $count)
            $count = $responseStream.Read($buffer, 0, $buffer.Length)
            $downloadedBytes += $count
            
            # Update progress every 100ms to avoid too frequent updates
            $now = Get-Date
            if (($now - $lastUpdate).TotalMilliseconds -ge 100) {
                if ($totalLength -gt 0) {
                    $percentComplete = [math]::Round(($downloadedBytes / $totalLength) * 100, 2)
                    $downloadedMB = [math]::Round($downloadedBytes / 1MB, 2)
                    $totalMB = [math]::Round($totalLength / 1MB, 2)
                    
                    # Update progress on same line
                    $progressBarLength = [math]::Floor($percentComplete / 2)
                    $progressBar = "=" * $progressBarLength
                    $progressBar = $progressBar.PadRight(50)
                    Write-Host "`r  Progress: [$progressBar] $percentComplete% ($downloadedMB MB / $totalMB MB)" -NoNewline -ForegroundColor Cyan
                } else {
                    # Show bytes downloaded if total length unknown
                    $downloadedMB = [math]::Round($downloadedBytes / 1MB, 2)
                    Write-Host "`r  Progress: Downloaded $downloadedMB MB..." -NoNewline -ForegroundColor Cyan
                }
                $lastUpdate = $now
            }
        }
        
        # Final update to show 100%
        if ($totalLength -gt 0) {
            $downloadedMB = [math]::Round($downloadedBytes / 1MB, 2)
            $totalMB = [math]::Round($totalLength / 1MB, 2)
            $progressBar = "=" * 50
            Write-Host "`r  Progress: [$progressBar] 100.00% ($totalMB MB / $totalMB MB)" -NoNewline -ForegroundColor Cyan
        } else {
            $downloadedMB = [math]::Round($downloadedBytes / 1MB, 2)
            Write-Host "`r  Progress: Downloaded $downloadedMB MB... Complete!" -NoNewline -ForegroundColor Cyan
        }
        
        Write-Host "" # New line after progress
        $targetStream.Close()
        $responseStream.Close()
        $response.Close()
        
        return $true
    } catch {
        Write-Host ""
        throw $_
    }
}

# Function to extract archive with inline progress bar
function Expand-ArchiveWithProgress {
    param(
        [string]$ZipPath,
        [string]$DestinationPath
    )
    
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        $entries = $zip.Entries
        
        # Count only files (exclude directories)
        $fileEntries = @()
        foreach ($entry in $entries) {
            if (-not ($entry.FullName.EndsWith('\') -or $entry.FullName.EndsWith('/'))) {
                $fileEntries += $entry
            }
        }
        $totalFiles = $fileEntries.Count
        $extractedCount = 0
        $lastUpdate = Get-Date
        
        foreach ($entry in $entries) {
            $entryPath = Join-Path $DestinationPath $entry.FullName
            
            # Create directory if it doesn't exist
            $entryDir = Split-Path $entryPath -Parent
            if ($entryDir -and -not (Test-Path $entryDir)) {
                New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
            }
            
            # Skip if entry is a directory
            if ($entry.FullName.EndsWith('\') -or $entry.FullName.EndsWith('/')) {
                continue
            }
            
            # Extract the file
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $entryPath, $true)
            $extractedCount++
            
            # Update progress every 50ms
            $now = Get-Date
            if (($now - $lastUpdate).TotalMilliseconds -ge 50) {
                $percentComplete = [math]::Round(($extractedCount / $totalFiles) * 100, 2)
                $progressBarLength = [math]::Floor($percentComplete / 2)
                $progressBar = "=" * $progressBarLength
                $progressBar = $progressBar.PadRight(50)
                Write-Host "`r  Progress: [$progressBar] $percentComplete% ($extractedCount / $totalFiles files)" -NoNewline -ForegroundColor Cyan
                $lastUpdate = $now
            }
        }
        
        # Final update to show 100%
        $progressBar = "=" * 50
        Write-Host "`r  Progress: [$progressBar] 100.00% ($totalFiles / $totalFiles files)" -NoNewline -ForegroundColor Cyan
        
        Write-Host "" # New line after progress
        $zip.Dispose()
        
        return $true
    } catch {
        Write-Host ""
        throw $_
    }
}

# Step 0: Get Steam path from registry
Write-Host "Step 0: Locating Steam installation..." -ForegroundColor Yellow
$steamPath = Get-SteamPath
$steamExePath = $null

if (-not $steamPath) {
    Write-Host "  [ERROR] Steam installation not found in registry." -ForegroundColor Red
    Write-Host "  Please ensure Steam is installed on your system." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor DarkYellow
    Write-Host "Process completed. Press any key to exit..." -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor DarkYellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$steamExePath = Join-Path $steamPath "Steam.exe"

if (-not (Test-Path $steamExePath)) {
    Write-Host "  [ERROR] Steam.exe not found at: $steamExePath" -ForegroundColor Red
    Write-Host "  The Steam directory exists but Steam.exe is missing." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "===============================================================" -ForegroundColor DarkYellow
    Write-Host "Process completed. Press any key to exit..." -ForegroundColor Green
    Write-Host "===============================================================" -ForegroundColor DarkYellow
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

Write-Host "  [SUCCESS] Steam found!" -ForegroundColor Green
Write-Host "  Location: $steamPath" -ForegroundColor White
Write-Host ""

# Step 1: Kill all Steam processes
Write-Host "Step 1: Killing all Steam processes..." -ForegroundColor Yellow
$steamProcesses = Get-Process -Name "steam*" -ErrorAction SilentlyContinue
if ($steamProcesses) {
    foreach ($proc in $steamProcesses) {
        try {
            Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
            Write-Host "  [INFO] Killed process: $($proc.Name) (PID: $($proc.Id))" -ForegroundColor Gray
        } catch {
            Write-Host "  [WARNING] Could not kill process: $($proc.Name)" -ForegroundColor Yellow
        }
    }
    Start-Sleep -Seconds 2
    Write-Host "  [SUCCESS] All Steam processes terminated" -ForegroundColor Green
} else {
    Write-Host "  [INFO] No Steam processes found running" -ForegroundColor Cyan
}
Write-Host ""

# Step 2: Create steam.cfg file
Write-Host "Step 2: Creating steam.cfg file..." -ForegroundColor Yellow
$steamCfgPath = Join-Path $steamPath "steam.cfg"

# Create config file using echo commands as specified
$cfgContent = "BootStrapperInhibitAll=enable`nBootStrapperForceSelfUpdate=disable"
Set-Content -Path $steamCfgPath -Value $cfgContent -Force
Write-Host "  [SUCCESS] steam.cfg created!" -ForegroundColor Green
Write-Host "  Location: $steamCfgPath" -ForegroundColor White
Write-Host ""

# Step 3: Download and extract zip file
Write-Host "Step 3: Downloading and extracting Millennium build..." -ForegroundColor Yellow
$zipUrl = "http://files.luatools.work/OneOffFiles/luatoolsmilleniumbuild.zip"
$tempZip = Join-Path $env:TEMP "luatoolsmilleniumbuild.zip"

try {
    Write-Host "  Downloading from: $zipUrl" -ForegroundColor Gray
    Download-FileWithProgress -Url $zipUrl -OutFile $tempZip
    Write-Host "  [SUCCESS] Download complete" -ForegroundColor Green
    
    Write-Host "  Extracting to: $steamPath" -ForegroundColor Gray
    Expand-ArchiveWithProgress -ZipPath $tempZip -DestinationPath $steamPath
    Write-Host "  [SUCCESS] Extraction complete" -ForegroundColor Green
    
    # Clean up temp file
    Remove-Item -Path $tempZip -Force -ErrorAction SilentlyContinue
    Write-Host ""
} catch {
    Write-Host "  [ERROR] Failed to download or extract: $_" -ForegroundColor Red
    Write-Host "  Continuing anyway..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 4: Launch Steam
Write-Host "Step 4: Launching Steam..." -ForegroundColor Yellow
$arguments = @(
    "-forcesteamupdate"
    "-forcepackagedownload"
    "-overridepackageurl"
    "http://web.archive.org/web/20251122131734if_/media.steampowered.com/client"
    "-exitsteam"
)

Write-Host "  Executable: $steamExePath" -ForegroundColor Gray
Write-Host "  Arguments: $($arguments -join ' ')" -ForegroundColor Gray
Write-Host ""

try {
    $process = Start-Process -FilePath $steamExePath -ArgumentList $arguments -PassThru -WindowStyle Normal
    
    Write-Host "  [SUCCESS] Steam launched successfully!" -ForegroundColor Green
    Write-Host "  Process ID: $($process.Id)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Steam is now running with the downgrade parameters." -ForegroundColor White
    Write-Host "Please wait for Steam to complete the update process." -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "  [ERROR] Failed to start Steam: $_" -ForegroundColor Red
    Write-Host ""
}

# Pause before closing
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Process completed. Press any key to exit..." -ForegroundColor Green
Write-Host "===============================================================" -ForegroundColor DarkYellow
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
