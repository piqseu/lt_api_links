## Configure this
$Host.UI.RawUI.WindowTitle = "Luatools plugin installer | .gg/luatools"
$name = "luatools" # automatic first letter uppercase included
$link = "https://github.com/madoiscool/ltsteamplugin/releases/latest/download/ltsteamplugin.zip"
$milleniumTimer = 5 # in seconds for auto-installation

### Hey nerd, here's a "-f" argument to remove "user interactions"

# Hidden defines
$isForced = $args -contains "-f"
$ProgressPreference = 'SilentlyContinue' # To hide da blue box thing

#### Logging defines ####
function Log {
    param ([string]$Type, [string]$Message, [boolean]$NoNewline = $false)
    switch ($Type) {
        "OK"   { $foreground = "Green" }
        "INFO" { $foreground = "Blue" }
        "ERR"  { $foreground = "Red" }
        "WARN" { $foreground = "Yellow" }
        "LOG"  { $foreground = "Magenta" }
        "AUX"  { $foreground = "DarkGray" }
        default { $foreground = "White" }
    }

    $date = Get-Date -Format "HH:mm:ss"
    $prefix = if ($NoNewline) { "`r[$date] " } else { "[$date] " }
    Write-Host $prefix -ForegroundColor "Cyan" -NoNewline

    Write-Host "[$Type] $Message" -ForegroundColor $foreground -NoNewline:$NoNewline
}

#### check all da registries for erm steam installation ####
function Get-SteamPath {
    $registryPaths = @(
        "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam",
        "HKLM:\SOFTWARE\Valve\Steam",
        "HKCU:\SOFTWARE\Valve\Steam"
    )
    
    foreach ($regPath in $registryPaths) {
        try {
            $steamPath = (Get-ItemProperty -Path $regPath -ErrorAction Stop).InstallPath
            if ($steamPath -and (Test-Path $steamPath)) {
                return $steamPath
            }
        } catch {
            continue
        }
    }
    
    Log "ERR" "Could not find Steam installation path. Is Steam installed?"
    exit 1
}

function Test-MilleniumInstalled {
    param ([string]$SteamPath)
    
    $requiredFiles = @("millennium.dll", "python311.dll", "user32.dll")
    $missing = @()
    
    foreach ($file in $requiredFiles) {
        $filePath = Join-Path $SteamPath $file
        if (-not (Test-Path $filePath)) {
            $missing += $file
        }
    }
    
    return @{
        Installed = ($missing.Count -eq 0)
        MissingFiles = $missing
    }
}


#### Requirements part ####

# show the steam installatio
$steam = Get-SteamPath
$upperName = $name.Substring(0,1).ToUpper() + $name.Substring(1).ToLower()
Log "INFO" "Steam installation found at: $steam"

# Steamtools check
$hidDllPath = Join-Path $steam "hid.dll"
if (Test-Path $hidDllPath) {
    Log "INFO" "Steamtools already installed"
} else {
    if ($isForced) {
        Log "AUX" "-f argument detected, skipping installation."
        Log "ERR" "Restart the script once steamtools is installed."
        exit 1
    }

    try {
        # fetching and making sure its the right script type beat
        Log "INFO" "Fetching Steamtools installation script..."
        $script = Invoke-RestMethod -Uri "https://steam.run" -ErrorAction Stop
        $keptLines = @()

        foreach ($line in $script -split "`n") {
            $conditions = @( # Removes lines containing one of those
                ($line -imatch "Start-Process" -and $line -imatch "steam"),
                ($line -imatch "steam\.exe"),
                ($line -imatch "Start-Sleep" -or $line -imatch "Write-Host"),
                ($line -imatch "cls" -or $line -imatch "exit"),
                ($line -imatch "Stop-Process" -and -not ($line -imatch "Get-Process"))
            )
            
            if (-not ($conditions -contains $true)) {
                $keptLines += $line
            }
        }

        $SteamtoolsScript = $keptLines -join "`n"

        while (-not (Test-Path $hidDllPath)) {
            Log "ERR" "Steamtools not found."
            Log "AUX" "Install it at your own risk! Close this script if you don't want to."
            Log "WARN" "Pressing any key will install steamtools (UI-less)."
            Write-Host

            [void][System.Console]::ReadKey($true)
            Log "WARN" "Installing Steamtools"
            
            try {
                Invoke-Expression $SteamtoolsScript *> $null
            } catch {
                Log "ERR" "Steamtools installation failed: $($_.Exception.Message)"
                Log "WARN" "Please try again or install manually."
                continue
            }
        }

        Log "OK" "Steamtools installed"
    } catch {
        Log "ERR" "Failed to fetch Steamtools installation script: $($_.Exception.Message)"
        exit 1
    }
}

# Millenium check
$milleniumStatus = Test-MilleniumInstalled -SteamPath $steam
$milleniumInstalling = $false

if (-not $milleniumStatus.Installed) {
    $missingFiles = $milleniumStatus.MissingFiles -join ", "
    Log "WARN" "Millenium files missing: $missingFiles"
    
    # Ask confirmation to download (use -f to skip)
    if (-not $isForced) {
        Log "ERR" "Millenium not found, installation process will start in $milleniumTimer seconds."
        Log "WARN" "Press any key to cancel the installation."
        
        for ($i = $milleniumTimer; $i -ge 0; $i--) {
            # Whether a key was pressed
            if ([Console]::KeyAvailable) {
                Write-Host
                Log "ERR" "Installation cancelled by user."
                exit 1
            }

            Log "LOG" "Installing Millenium in $i second(s)... Press any key to cancel." $true
            Start-Sleep -Seconds 1
        }
        Write-Host
    } else {
        Log "ERR" "Millenium not found, installation process will instantly start (-f argument)."
    }

    Log "INFO" "Installing Millenium..."
    
    try {
        $installScript = Invoke-WebRequest -Uri 'https://steambrew.app/install.ps1' -UseBasicParsing -ErrorAction Stop
        Invoke-Expression $installScript.Content *> $null
        
        # Verify installation succeeded
        Start-Sleep -Seconds 2 # Give installation time to complete
        $verifyStatus = Test-MilleniumInstalled -SteamPath $steam
        
        if ($verifyStatus.Installed) {
            Log "OK" "Millenium installation completed and verified."
            $milleniumInstalling = $true
        } else {
            $stillMissing = $verifyStatus.MissingFiles -join ", "
            Log "WARN" "Millenium installation completed but some files are still missing: $stillMissing"
            Log "WARN" "Installation may have partially failed. Continuing anyway..."
            $milleniumInstalling = $true
        }
    } catch {
        Log "ERR" "Millenium installation failed: $($_.Exception.Message)"
        exit 1
    }
} else {
    Log "INFO" "Millenium already installed"
}



#### Plugin part ####
# Ensuring \Steam\plugins
$pluginsDir = Join-Path $steam "plugins"
if (-not (Test-Path $pluginsDir)) {
    try {
        New-Item -Path $pluginsDir -ItemType Directory -Force | Out-Null
        Log "INFO" "Created plugins directory"
    } catch {
        Log "ERR" "Failed to create plugins directory: $($_.Exception.Message)"
        exit 1
    }
}

$pluginPath = Join-Path $pluginsDir $name # Defaulting if no install found

# Checking for existing plugin named "$name"
try {
    $existingPlugins = Get-ChildItem -Path $pluginsDir -Directory -ErrorAction SilentlyContinue
    foreach ($plugin in $existingPlugins) {
        $pluginJsonPath = Join-Path $plugin.FullName "plugin.json"
        if (Test-Path $pluginJsonPath) {
            try {
                $json = Get-Content $pluginJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
                if ($json.name -eq $name) {
                    Log "INFO" "Plugin already installed, updating it"
                    $pluginPath = $plugin.FullName # Replacing default path
                    break
                }
            } catch {
                Log "AUX" "Skipping invalid plugin.json at $pluginJsonPath"
                continue
            }
        }
    }
} catch {
    Log "WARN" "Error checking for existing plugins: $($_.Exception.Message)"
}

# Installation 
$tempZipPath = Join-Path $env:TEMP "$name.zip"

try {
    Log "LOG" "Downloading $name from $link"
    Invoke-WebRequest -Uri $link -OutFile $tempZipPath -UseBasicParsing -ErrorAction Stop
    
    if (-not (Test-Path $tempZipPath)) {
        throw "Downloaded file not found"
    }
    
    $fileSize = (Get-Item $tempZipPath).Length
    if ($fileSize -eq 0) {
        throw "Downloaded file is empty"
    }
    
    Log "LOG" "Unzipping $name ($([math]::Round($fileSize/1KB, 2)) KB)"
    
    # Ensure target directory exists
    if (-not (Test-Path $pluginPath)) {
        New-Item -Path $pluginPath -ItemType Directory -Force | Out-Null
    }
    
    Expand-Archive -Path $tempZipPath -DestinationPath $pluginPath -Force -ErrorAction Stop
    
    # Verify plugin.json exists after extraction
    $extractedPluginJson = Join-Path $pluginPath "plugin.json"
    if (Test-Path $extractedPluginJson) {
        Log "OK" "$upperName installed successfully at $pluginPath"
    } else {
        Log "WARN" "$upperName extracted but plugin.json not found. Installation may be incomplete."
    }
} catch {
    Log "ERR" "Plugin installation failed: $($_.Exception.Message)"
    if (Test-Path $tempZipPath) {
        Remove-Item $tempZipPath -ErrorAction SilentlyContinue
    }
    exit 1
} finally {
    # Cleanup temp file
    if (Test-Path $tempZipPath) {
        Remove-Item $tempZipPath -ErrorAction SilentlyContinue
    }
}


# Result showing
Write-Host
if ($milleniumInstalling) {
    Log "WARN" "Steam startup will be longer, don't panic and don't touch anything in Steam!"
}

# Waiting input (unless -f argument passed)
if (-not $isForced) {
    Log "OK" "Press any key to restart Steam and finish the installation!"
    [void][System.Console]::ReadKey($true)
} else {
    Log "OK" "Restarting Steam and toggling the plugin on"
}

# Toggle the plugin on (restarts steam)
try {
    Start-Process "steam://millennium/settings/plugins/enable/$name" -ErrorAction Stop
    Log "OK" "Steam should now restart. Plugin should be enabled after Steam restarts! Enjoy! If you paid for this you got scammed btw discord.gg/luatools"
} catch {
    Log "WARN" "Could not launch Steam protocol handler. Please manually enable the plugin in Steam settings."
    Log "INFO" "Plugin files are located at: $pluginPath"
}
