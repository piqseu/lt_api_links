## Configure this
$Host.UI.RawUI.WindowTitle = "Luatools plugin installer | .gg/luatools"
$name = "luatools" # automatic first letter uppercase included
$link = "https://github.com/madoiscool/ltsteamplugin/releases/latest/download/ltsteamplugin.zip"
$stLink = "https://steamtools.net/download.html"
$milleniumTimer = 5 # in seconds

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


#### Requirements part ####

# Steamtools check
# TODO: Make this prettier?
$path = Join-Path $steam "hid.dll"
if (!( Test-Path $path )) {
    function Print_Install {
        Log "ERR" "Install steamtools then press any key."
        Log "WARN" "Get steamtools at your own risks!"
    }

    if (($isForced)) {
        Log "INFO" "$stLink (first button)"
        Log "AUX" "-f argument detected, skipping link opening."
        Log "ERR" "Restart the script once steamtools is installed."
        exit
    }

    Print_Install
    Write-Host

    # Start-Sleep -Milliseconds 500
    Start-Process "$stLink"
    [void][System.Console]::ReadKey($true)

    $amount = 1
    while (!( Test-Path $path )) {
        $amount++
        Print_Install
        Log "INFO" "$stLink (first button)"
        if ($amount % 3 -eq 0) { Log "WARN" "Make sure $path exists. Restart the script if it's bugged." }
        
        [void][System.Console]::ReadKey($true)
        Write-Host
    }

    Log "OK" "Steamtools installed"

} else { Log "INFO" "Steamtools already installed" }

# Millenium check
$milleniumInstalling = $false
foreach ($file in @("millennium.dll", "python311.dll", "user32.dll")) {
    if (!( Test-Path (Join-Path $steam $file) )) {
        
        # Ask confirmation to download (use -f to skip)
        if (!( $isForced )) {
            Log "ERR" "Millenium not found, installation process will start in 5 seconds."
            Log "WARN" "Press any key to cancel the installation."
            
            for ($i = $milleniumTimer; $i -ge 0; $i--) {
                # Si une touche a été enfoncée
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
Expand-Archive -Path $subPath -DestinationPath $Path *> $null
Remove-Item $subPath # Cleanup

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