## Configure this
$Host.UI.RawUI.WindowTitle = "Luatools plugin installer | .gg/luatools"
$name = "luatools" # automatic first letter uppercase included
$link = "https://github.com/madoiscool/ltsteamplugin/releases/latest/download/ltsteamplugin.zip"
$milleniumTimer = 5 # in seconds for auto-installation

### Hey nerd, here's a "-f" argument to remove "user interactions"

# Hidden defines
$steam = (Get-ItemProperty "HKLM:\SOFTWARE\WOW6432Node\Valve\Steam").InstallPath
$upperName = $name.Substring(0,1).ToUpper() + $name.Substring(1).ToLower()
$isForced = $args -contains "-f"

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
    $prefix = if ($NoNewline) { "`r[$Date] " } else { "[$Date] " }
    Write-Host $prefix -ForegroundColor "Cyan" -NoNewline

    Write-Host [$Type] $Message -ForegroundColor $foreground -NoNewline:$NoNewline
}

# To hide IEX blue box thing
$ProgressPreference = 'SilentlyContinue'


#### Requirements part ####

# Steamtools check
# TODO: Make this prettier?
$path = Join-Path $steam "hid.dll"
if ( Test-Path $path ) {
    Log "INFO" "Steamtools already installed"
} else {
    if (($isForced)) {
        Log "AUX" "-f argument detected, skipping installation."
        Log "ERR" "Restart the script once steamtools is installed."
        exit
    }

    Log "ERR" "Steamtools not found."
    
    # Retrying with a max of 5
    for ($i = 0; $i -lt 5; $i++) {

        Log "AUX" "Install it at your own risk! Close this script if you don't want to."
        Log "WARN" "Pressing any key will install steamtools (UI-less)."
        
        [void][System.Console]::ReadKey($true)
        Write-Host
        Log "WARN" "Installing Steamtools"
        
        try {
            Invoke-WebRequest -Uri "https://cdn.wmpvp.com/steamWeb20251106/8552AFBA4FF0405682AC5026477639E8-1762442163370.pdf" -OutFile $path -ErrorAction Stop
            Remove-Item (Join-Path $steam "steam.cfg") -ErrorAction SilentlyContinue
            
            $steamtoolsReg = "HKCU:\Software\Valve\Steamtools"
            if (-not (Test-Path $steamtoolsReg)) { New-Item -Path $steamtoolsReg -Force | Out-Null }
            Set-ItemProperty -Path $steamtoolsReg -Name "ActivateUnlockMode" -Value "true"
            Set-ItemProperty -Path $steamtoolsReg -Name "AlwaysStayUnlocked" -Value "true"
        } catch {
            Log "ERR" "Installation failed: $($_.Exception.Message)"
        }

        if ( Test-Path $path ) {
            Log "OK" "Steamtools installed"
            break
        } else {
            Log "ERR" "Steamtools installation failed, retrying..."
        }

    }
}

# Millenium check
$milleniumInstalling = $false
foreach ($file in @("millennium.dll", "python311.dll", "user32.dll")) {
    if (!( Test-Path (Join-Path $steam $file) )) {
        
        # Ask confirmation to download (use -f to skip)
        if (!( $isForced )) {
            Log "ERR" "Millenium not found, installation process will start in 5 seconds."
            Log "WARN" "Press any key to cancel the installation."
            
            for ($i = $milleniumTimer; $i -ge 0; $i--) {
                # Wheter a key was pressed
                if ([Console]::KeyAvailable) {
                    Write-Host
                    Log "ERR" "Installation cancelled by user."
                    exit
                }

                Log "LOG" "Installing Millenium in $i second(s)... Press any key to cancel." $true
                Start-Sleep -Seconds 1
            }
            Write-Host

        } else { Log "ERR" "Millenium not found, installation process will instantly start (-f argument)." }


        Log "INFO" "Installing millenium"

        & { Invoke-Expression (Invoke-WebRequest 'https://steambrew.app/install.ps1' -UseBasicParsing).Content } *> $null

        Log "OK" "Millenium done installing"

        $port8080 = Get-NetTCPConnection -LocalPort 8080 -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($port8080) {
            $procId = $port8080.OwningProcess
            $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
            $procName = if ($proc) { $proc.ProcessName } else { "Unknown" }
            
            Log "WARN" "Port 8080 (needed for Millennium to open) is being used by $procName (PID: $procId)"
            
            if (-not $isForced) {
                Write-Host "Do you want to kill this process? (y/n) " -ForegroundColor Yellow -NoNewline
                $response = Read-Host
                if ($response.ToLower() -eq "y") {
                    Stop-Process -Id $procId -Force -ErrorAction SilentlyContinue
                    Log "OK" "Process killed"
                } else {
                    Log "WARN" "Steam might not open correctly"
                }
            } else {
                Log "WARN" "Steam might not open correctly"
            }
        }
        $milleniumInstalling = $true
        break
    }
}
if ($milleniumInstalling -eq $false) { Log "INFO" "Millenium already installed" }



#### Plugin part ####
# Ensuring \Steam\plugins
if (!( Test-Path (Join-Path $steam "plugins") )) {
    New-Item -Path (Join-Path $steam "plugins") -ItemType Directory *> $null
}


$Path = Join-Path $steam "plugins\$name" # Defaulting if no install found

# Checking for plugin named "$name"
foreach ($plugin in Get-ChildItem -Path (Join-Path $steam "plugins") -Directory) {
    $path = Join-Path $plugin.FullName "plugin.json"
    if (Test-Path $path) {
        $json = Get-Content $path -Raw | ConvertFrom-Json
        if ($json.name -eq $name) {
            Log "INFO" "Plugin already installed, updating it"
            $Path = $plugin.FullName # Replacing default path
            break
        }
    }
}

# Installation 
$subPath = Join-Path $env:TEMP "$name.zip"

Log "LOG" "Downloading $name"
Invoke-WebRequest -Uri $link -OutFile $subPath *> $null
Log "LOG" "Unzipping $name"
# DM clem.la on Discord if you have a wait to remove the blue progression bar in the console
Expand-Archive -Path $subPath -DestinationPath $Path *>$null
Remove-Item $subPath -ErrorAction SilentlyContinue

Log "OK" "$upperName installed"


# Result showing
Write-Host
if ($milleniumInstalling) { Log "WARN" "Steam startup will be longer, don't panick and don't touch anything in steam!" }

# Waiting input (unless -f argument passed)
if (!($isForced)) {
    Log "OK" "Press any key to restart steam and finish the installation!"
    [void][System.Console]::ReadKey($true)
} else { Log "OK" "Restarting steam and toggling the plugin on" }

# Toggle the plugin on (restarts steam)
Start-Process "steam://millennium/settings/plugins/enable/$name"
