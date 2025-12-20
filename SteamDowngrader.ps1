#Requires -Version 5.1
# Steam 32-bit Downgrader with Christmas Theme
# Gets Steam path from registry and runs with specified parameters

# Clear screen
Clear-Host

# Christmas-themed header
Write-Host ""
Write-Host "===============================================================" -ForegroundColor DarkYellow
Write-Host "Steam 32-bit Downgrader - by discord.gg/luatools (join for fun)" -ForegroundColor Cyan
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
        # Add cache-busting to prevent PowerShell cache
        $uri = New-Object System.Uri($Url)
        $uriBuilder = New-Object System.UriBuilder($uri)
        $timestamp = (Get-Date -Format 'yyyyMMddHHmmss')
        if ($uriBuilder.Query) {
            $uriBuilder.Query = $uriBuilder.Query.TrimStart('?') + "&t=" + $timestamp
        } else {
            $uriBuilder.Query = "t=" + $timestamp
        }
        $cacheBustUrl = $uriBuilder.ToString()
        
        # First request to get content length and verify response
        $request = [System.Net.HttpWebRequest]::Create($cacheBustUrl)
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $request.Headers.Add("Pragma", "no-cache")
        $request.Timeout = 30000 # 30 seconds timeout
        $request.ReadWriteTimeout = 30000
        
        try {
            $response = $request.GetResponse()
        } catch {
            Write-Host "  [ERROR] Connection failed: $_" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Connection timeout or failed to connect to server"
        }
        
        # Check response code
        $statusCode = [int]$response.StatusCode
        if ($statusCode -ne 200) {
            $response.Close()
            Write-Host "  [ERROR] Invalid response code: $statusCode (expected 200)" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Server returned status code $statusCode instead of 200"
        }
        
        # Check content length
        $totalLength = $response.ContentLength
        if ($totalLength -le 0) {
            $response.Close()
            Write-Host "  [ERROR] Invalid content length: $totalLength (expected > 0)" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Server did not return valid content length"
        }
        
        $response.Close()
        
        # Second request to download the file (no timeout - allow long downloads)
        $request = [System.Net.HttpWebRequest]::Create($cacheBustUrl)
        $request.CachePolicy = New-Object System.Net.Cache.RequestCachePolicy([System.Net.Cache.RequestCacheLevel]::NoCacheNoStore)
        $request.Headers.Add("Cache-Control", "no-cache, no-store, must-revalidate")
        $request.Headers.Add("Pragma", "no-cache")
        $request.Timeout = -1 # No timeout
        $request.ReadWriteTimeout = -1 # No timeout
        
        try {
            $response = $request.GetResponse()
        } catch {
            Write-Host "  [ERROR] Download connection failed: $_" -ForegroundColor Red
            Write-Host "  [ERROR] URL: $cacheBustUrl" -ForegroundColor Red
            throw "Connection failed during download"
        }
        
        $responseStream = $response.GetResponseStream()
        $targetStream = New-Object -TypeName System.IO.FileStream -ArgumentList $OutFile, Create
        
        $buffer = New-Object byte[] 10KB
        $count = $responseStream.Read($buffer, 0, $buffer.Length)
        $downloadedBytes = $count
        $lastUpdate = Get-Date
        $lastBytesDownloaded = $downloadedBytes
        $lastBytesUpdateTime = Get-Date
        $stuckTimeoutSeconds = 60 # 1 minute timeout for stuck downloads
        
        while ($count -gt 0) {
            $targetStream.Write($buffer, 0, $count)
            $count = $responseStream.Read($buffer, 0, $buffer.Length)
            $downloadedBytes += $count
            
            # Check if download is stuck (no progress for 1 minute)
            $now = Get-Date
            if ($downloadedBytes -gt $lastBytesDownloaded) {
                # Bytes increased, reset stuck timer
                $lastBytesDownloaded = $downloadedBytes
                $lastBytesUpdateTime = $now
            } else {
                # No bytes downloaded, check if stuck
                $timeSinceLastBytes = ($now - $lastBytesUpdateTime).TotalSeconds
                if ($timeSinceLastBytes -ge $stuckTimeoutSeconds) {
                    $targetStream.Close()
                    $responseStream.Close()
                    $response.Close()
                    if (Test-Path $OutFile) {
                        Remove-Item $OutFile -Force -ErrorAction SilentlyContinue
                    }
                    Write-Host ""
                    Write-Host "  [ERROR] Download appears stuck (0 kbps for $stuckTimeoutSeconds seconds)" -ForegroundColor Red
                    Write-Host "  [ERROR] Downloaded: $downloadedBytes bytes, Expected: $totalLength bytes" -ForegroundColor Red
                    throw "Download stalled - no data received for $stuckTimeoutSeconds seconds"
                }
            }
            
            # Update progress every 100ms to avoid too frequent updates
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
        Write-Host "  [ERROR] Download failed: $_" -ForegroundColor Red
        Write-Host "  [ERROR] Error details: $($_.Exception.Message)" -ForegroundColor Red
        if ($_.Exception.InnerException) {
            Write-Host "  [ERROR] Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor Red
        }
        Write-Host ""
        # Throw exception instead of exiting - let caller handle it (fallback function or main script)
        throw $_
    }
}

# Function to download and extract with fallback URL support
function Download-AndExtractWithFallback {
    param(
        [string]$PrimaryUrl,
        [string]$FallbackUrl,
        [string]$TempZipPath,
        [string]$DestinationPath,
        [string]$Description
    )
    
    $urls = @($PrimaryUrl, $FallbackUrl)
    $lastError = $null
    
    foreach ($url in $urls) {
        try {
            # Clean up any existing temp file
            if (Test-Path $TempZipPath) {
                Remove-Item -Path $TempZipPath -Force -ErrorAction SilentlyContinue
            }
            
            $isFallback = ($url -eq $FallbackUrl)
            if ($isFallback) {
                Write-Host "  [INFO] Primary download failed, trying fallback URL..." -ForegroundColor Yellow
            }
            
            Write-Host "  Downloading from: $url" -ForegroundColor Gray
            Download-FileWithProgress -Url $url -OutFile $TempZipPath
            Write-Host "  [SUCCESS] Download complete" -ForegroundColor Green
            
            # Try to extract - this will validate the ZIP
            Write-Host "  Extracting to: $DestinationPath" -ForegroundColor Gray
            Expand-ArchiveWithProgress -ZipPath $TempZipPath -DestinationPath $DestinationPath
            Write-Host "  [SUCCESS] Extraction complete" -ForegroundColor Green
            
            # Clean up temp file
            Remove-Item -Path $TempZipPath -Force -ErrorAction SilentlyContinue
            
            return $true
        } catch {
            $lastError = $_
            $errorMessage = $_.ToString()
            if ($_.Exception -and $_.Exception.Message) {
                $errorMessage = $_.Exception.Message
            }
            
            if ($isFallback) {
                # Both URLs failed
                Write-Host "  [ERROR] Fallback download also failed: $_" -ForegroundColor Red
                throw "Both primary and fallback downloads failed. Last error: $_"
            } else {
                # Check if it's a ZIP validation error or download error that should trigger fallback
                # Cloudflare blocks: ZIP validation errors (HTML page instead of ZIP)
                # Connection issues: timeouts, connection failures, stuck downloads
                if ($errorMessage -match "Invalid ZIP|corrupted|End of Central Directory|PK signature|ZIP file|Connection.*failed|timeout|stalled|stuck|failed to connect") {
                    Write-Host "  [WARNING] Download failed (possible Cloudflare block or connection issue), will try fallback URL..." -ForegroundColor Yellow
                    continue
                } else {
                    # Other error (like invalid response code, authentication, etc.), rethrow
                    throw $_
                }
            }
        }
    }
    
    # Should never reach here, but just in case
    throw $lastError
}

# Function to extract archive with inline progress bar
function Expand-ArchiveWithProgress {
    param(
        [string]$ZipPath,
        [string]$DestinationPath
    )
    
    try {
        # Validate ZIP file exists and has content
        if (-not (Test-Path $ZipPath)) {
            Write-Host "  [ERROR] ZIP file not found: $ZipPath" -ForegroundColor Red
            throw "ZIP file does not exist"
        }
        
        $zipFileInfo = Get-Item $ZipPath -ErrorAction Stop
        if ($zipFileInfo.Length -eq 0) {
            Write-Host "  [ERROR] ZIP file is empty (0 bytes)" -ForegroundColor Red
            throw "ZIP file is empty"
        }
        
        # Check if file starts with ZIP signature (PK header)
        $zipStream = [System.IO.File]::OpenRead($ZipPath)
        $header = New-Object byte[] 4
        $bytesRead = $zipStream.Read($header, 0, 4)
        $zipStream.Close()
        
        if ($bytesRead -lt 4 -or $header[0] -ne 0x50 -or $header[1] -ne 0x4B) {
            Write-Host "  [ERROR] File does not appear to be a valid ZIP file (missing PK signature)" -ForegroundColor Red
            Write-Host "  [ERROR] File size: $($zipFileInfo.Length) bytes" -ForegroundColor Red
            throw "Invalid ZIP file format"
        }
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        
        # Try to open the ZIP file - this will fail if corrupted
        try {
            $zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
        } catch {
            Write-Host "  [ERROR] ZIP file is corrupted or incomplete" -ForegroundColor Red
            Write-Host "  [ERROR] File size: $($zipFileInfo.Length) bytes" -ForegroundColor Red
            Write-Host "  [ERROR] Error: $($_.Exception.Message)" -ForegroundColor Red
            throw "ZIP file is corrupted - download may have been interrupted. Please try again."
        }
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

# Delete steam.cfg if present
$steamCfgPath = Join-Path $steamPath "steam.cfg"
if (Test-Path $steamCfgPath) {
    try {
        Remove-Item -Path $steamCfgPath -Force -ErrorAction Stop
        Write-Host "  [INFO] Removed existing steam.cfg file" -ForegroundColor Gray
    } catch {
        Write-Host "  [WARNING] Could not remove steam.cfg: $_" -ForegroundColor Yellow
    }
}
Write-Host ""

# Step 2: Download and extract Steam x32 Latest Build
Write-Host "Step 2: Downloading and extracting Steam x32 Latest Build..." -ForegroundColor Yellow
$steamZipUrl = "http://files.luatools.work/OneOffFiles/latest32bitsteam.zip"
$steamZipFallbackUrl = "https://github.com/madoiscool/lt_api_links/releases/download/unsteam/latest32bitsteam.zip"
$tempSteamZip = Join-Path $env:TEMP "latest32bitsteam.zip"

try {
    Download-AndExtractWithFallback -PrimaryUrl $steamZipUrl -FallbackUrl $steamZipFallbackUrl -TempZipPath $tempSteamZip -DestinationPath $steamPath -Description "Steam x32 Latest Build"
    Write-Host ""
} catch {
    Write-Host "  [ERROR] Failed to download or extract: $_" -ForegroundColor Red
    Write-Host "  Continuing anyway..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 3: Download and extract zip file (only if millennium.dll is present - to replace it)
Write-Host "Step 3: Checking for Millennium build..." -ForegroundColor Yellow
$millenniumDll = Join-Path $steamPath "millennium.dll"

if (Test-Path $millenniumDll) {
    Write-Host "  [INFO] millennium.dll found, downloading and extracting to replace it..." -ForegroundColor Yellow
    Write-Host "  Location: $millenniumDll" -ForegroundColor White
    $zipUrl = "http://files.luatools.work/OneOffFiles/luatoolsmilleniumbuild.zip"
    $zipFallbackUrl = "https://github.com/madoiscool/lt_api_links/releases/download/unsteam/luatoolsmilleniumbuild.zip"
    $tempZip = Join-Path $env:TEMP "luatoolsmilleniumbuild.zip"

    try {
        Download-AndExtractWithFallback -PrimaryUrl $zipUrl -FallbackUrl $zipFallbackUrl -TempZipPath $tempZip -DestinationPath $steamPath -Description "Millennium build"
        Write-Host ""
    } catch {
        Write-Host "  [ERROR] Failed to download or extract: $_" -ForegroundColor Red
        Write-Host "  Continuing anyway..." -ForegroundColor Yellow
        Write-Host ""
    }
} else {
    Write-Host "  [INFO] millennium.dll not found, skipping download and extraction" -ForegroundColor Cyan
    Write-Host ""
}

# Step 4: Create steam.cfg file
Write-Host "Step 4: Creating steam.cfg file..." -ForegroundColor Yellow
$steamCfgPath = Join-Path $steamPath "steam.cfg"

# Create config file using echo commands as specified
$cfgContent = "BootStrapperInhibitAll=enable`nBootStrapperForceSelfUpdate=disable"
Set-Content -Path $steamCfgPath -Value $cfgContent -Force
Write-Host "  [SUCCESS] steam.cfg created!" -ForegroundColor Green
Write-Host "  Location: $steamCfgPath" -ForegroundColor White
Write-Host ""

# Step 5: Launch Steam
Write-Host "Step 5: Launching Steam..." -ForegroundColor Yellow
$arguments = @("-clearbeta")
Write-Host "  Executable: $steamExePath" -ForegroundColor Gray
Write-Host "  Arguments: $($arguments -join ' ')" -ForegroundColor Gray
Write-Host ""

try {
    $process = Start-Process -FilePath $steamExePath -ArgumentList $arguments -PassThru -WindowStyle Normal
    
    Write-Host "  [SUCCESS] Steam launched successfully!" -ForegroundColor Green
    Write-Host "  Process ID: $($process.Id)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Steam is now running with the config file." -ForegroundColor White
    Write-Host ""
    
} catch {
    Write-Host "  [ERROR] Failed to start Steam: $_" -ForegroundColor Red
    Write-Host ""
}

# ASCII Art
Write-Host ""
Write-Host '                 _...Q._' -ForegroundColor Cyan
Write-Host '               .''       ''.' -ForegroundColor Cyan
Write-Host '              /           \' -ForegroundColor Cyan
Write-Host '             ;.-""--.._ |' -ForegroundColor Cyan
Write-Host '            /''-._____..-''\|' -ForegroundColor Cyan
Write-Host '          .'' ;  o   o    |`;' -ForegroundColor Cyan
Write-Host '         /  /|   ()      ;  \' -ForegroundColor Cyan
Write-Host '    _.-, ''-'' ; ''.__.-''    \  \' -ForegroundColor Cyan
Write-Host '.-"`,  |      \_         / `''`' -ForegroundColor Cyan
Write-Host ' ''._`.; ._    / `''--.,_=-;_' -ForegroundColor Cyan
Write-Host '    \ \|  `\ .\_     /`  \ `._' -ForegroundColor Cyan
Write-Host '     \ \    `/  ``---|    \   (~' -ForegroundColor Cyan
Write-Host '      \ \.  | o   ,   \    (~ (~  ______________' -ForegroundColor Cyan
Write-Host '       \ \`_\ _..-''    \  (\(~   |.------------.|' -ForegroundColor Cyan
Write-Host '        \/  ``        / \(~/     || ALL DONE!! ||' -ForegroundColor Cyan
Write-Host '         \__    __..-'' -   ''.    || """"  """" ||' -ForegroundColor Cyan
Write-Host '          \ \```             \   || discord.gg ||' -ForegroundColor Cyan
Write-Host '          ;\ \o               ;  || /luatools  ||' -ForegroundColor Cyan
Write-Host '          | \ \               |  ||____________||' -ForegroundColor Cyan
Write-Host '          ;  \ \              ;  ''------..------''' -ForegroundColor Cyan
Write-Host '           \  \ \ _.-''\      /          ||' -ForegroundColor Cyan
Write-Host '            ''. \-''     \   .''           ||' -ForegroundColor Cyan
Write-Host '           _.-"  ''      \-''           .-||-.' -ForegroundColor Cyan
Write-Host '           \ ''  '' ''      \           ''..---.- ''' -ForegroundColor Cyan
Write-Host '            \  '' ''      _.'' ' -ForegroundColor Cyan
Write-Host '             \'' ''   _.-''' -ForegroundColor Cyan
Write-Host '              \ _.-''' -ForegroundColor Cyan
Write-Host '               `' -ForegroundColor Cyan
Write-Host ""

# Pause before closing
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
