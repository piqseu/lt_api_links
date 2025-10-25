# LuaTools API Updater Script
# This script finds LuaTools plugins and updates their API configuration
# https://github.com/SteamClientHomebrew/Millennium

# Set console encoding to UTF-8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Define ANSI escape sequences for colored output
$BoldPurple = [char]27 + '[38;5;219m'
$BoldGreen = [char]27 + '[1;32m'
$BoldYellow = [char]27 + '[1;33m'
$BoldRed = [char]27 + '[1;31m'
$BoldLightBlue = [char]27 + '[38;5;75m'
$ResetColor = [char]27 + '[0m'

# API URL for downloading api.json
$apiUrl = "https://luatools.vercel.app/api.json"

Write-Output "${BoldPurple}++${ResetColor} LuaTools API Updater / Atualizador de API LuaTools"
Write-Output "${BoldPurple}++${ResetColor} Searching for Steam installation... / Procurando instalacao do Steam...`n"

# Function to display bilingual messages
function Write-Bilingual {
    param([string]$message)
    Write-Output "${BoldPurple}::${ResetColor} $message"
}

function Write-Success {
    param([string]$message)
    Write-Output "${BoldGreen}++${ResetColor} $message"
}

function Write-Error {
    param([string]$message)
    Write-Output "${BoldRed}[!]${ResetColor} $message"
}

function Write-Warning {
    param([string]$message)
    Write-Output "${BoldYellow}[!]${ResetColor} $message"
}

# Get Steam path from registry
try {
    $steamPath = (Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -Name "SteamPath" -ErrorAction Stop).SteamPath
    if (-not $steamPath) {
        throw "Steam path not found in registry"
    }
    
    # Convert registry path format (remove double backslashes and convert forward slashes)
    $steamPath = $steamPath -replace '\\\\', '\' -replace '/', '\'
    
    Write-Success "Steam path found: $steamPath / Caminho do Steam encontrado: $steamPath"
} catch {
    Write-Error "Steam path not found in registry / Caminho do Steam nao encontrado no registro"
    Write-Error "Make sure Steam is installed / Certifique-se de que o Steam esta instalado"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

# Validate Steam directory exists
if (-not (Test-Path -Path $steamPath)) {
    Write-Error "Steam directory not found: $steamPath / Diretorio do Steam nao encontrado: $steamPath"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

# Check for plugins folder
$pluginsPath = Join-Path -Path $steamPath -ChildPath "plugins"
if (-not (Test-Path -Path $pluginsPath)) {
    Write-Error "Plugins folder not found, make sure Millennium is installed! / Pasta de plugins nao encontrada, certifique-se de que o Millennium esta instalado!"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

Write-Success "Plugins folder found / Pasta de plugins encontrada"
Write-Bilingual "Searching for LuaTools plugins... / Procurando plugins LuaTools..."

# Find all backend folders in plugins directory
$backendFolders = Get-ChildItem -Path $pluginsPath -Directory -Filter "backend" -Recurse -ErrorAction SilentlyContinue

if ($backendFolders.Count -eq 0) {
    Write-Warning "No backend folders found / Nenhuma pasta backend encontrada"
    Write-Error "LuaTools plugin not installed, make sure it is installed / Plugin LuaTools nao instalado, certifique-se de que esta instalado"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

Write-Bilingual "Found $($backendFolders.Count) backend folder(s) / Encontrada(s) $($backendFolders.Count) pasta(s) backend"

# Find LuaTools plugins by checking update.json files
$luatoolsPlugins = @()

foreach ($backendFolder in $backendFolders) {
    $updateJsonPath = Join-Path -Path $backendFolder.FullName -ChildPath "update.json"
    
    if (Test-Path -Path $updateJsonPath) {
        try {
            $updateJson = Get-Content -Path $updateJsonPath -Raw | ConvertFrom-Json -ErrorAction Stop
            
            # Check if this is a LuaTools plugin (check both direct repo and nested github.repo)
            $isLuaTools = $false
            if ($updateJson.repo -eq "ltsteamplugin") {
                $isLuaTools = $true
            } elseif ($updateJson.github -and $updateJson.github.repo -eq "ltsteamplugin") {
                $isLuaTools = $true
            }
            
            if ($isLuaTools) {
                $luatoolsPlugins += $backendFolder.FullName
                Write-Success "Found LuaTools plugin: $($backendFolder.FullName) / Plugin LuaTools encontrado: $($backendFolder.FullName)"
            }
        } catch {
            Write-Warning "Could not read update.json in $($backendFolder.FullName) / Nao foi possivel ler update.json em $($backendFolder.FullName)"
        }
    }
}

if ($luatoolsPlugins.Count -eq 0) {
    Write-Error "LuaTools plugin not installed, make sure it is installed / Plugin LuaTools nao instalado, certifique-se de que esta instalado"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

Write-Success "Found $($luatoolsPlugins.Count) LuaTools plugin(s) / Encontrado(s) $($luatoolsPlugins.Count) plugin(s) LuaTools"

# Download api.json
Write-Bilingual "Downloading API configuration... / Baixando configuracao da API..."
try {
    $tempApiPath = Join-Path -Path $env:TEMP -ChildPath "api.json"
    Invoke-WebRequest -Uri $apiUrl -OutFile $tempApiPath -UserAgent "LuaTools-API-Updater/1.0" -ErrorAction Stop
    Write-Success "API configuration downloaded successfully / Configuracao da API baixada com sucesso"
} catch {
    Write-Error "Failed to download API configuration / Falha ao baixar configuracao da API"
    Write-Error "Error: $($_.Exception.Message) / Erro: $($_.Exception.Message)"
    Read-Host "Press any key to exit / Pressione qualquer tecla para sair"
    exit 1
}

# Copy api.json to each LuaTools plugin folder
Write-Bilingual "Updating LuaTools plugins... / Atualizando plugins LuaTools..."

$successCount = 0
foreach ($pluginPath in $luatoolsPlugins) {
    try {
        $destinationPath = Join-Path -Path $pluginPath -ChildPath "api.json"
        Copy-Item -Path $tempApiPath -Destination $destinationPath -Force -ErrorAction Stop
        Write-Success "Updated: $pluginPath / Atualizado: $pluginPath"
        $successCount++
    } catch {
        Write-Error "Failed to update: $pluginPath / Falha ao atualizar: $pluginPath"
        Write-Error "Error: $($_.Exception.Message) / Erro: $($_.Exception.Message)"
    }
}

# Clean up temporary file
if (Test-Path -Path $tempApiPath) {
    Remove-Item -Path $tempApiPath -Force
}

# Display summary
Write-Output ""
Write-Success "Update completed successfully! / Atualizacao concluida com sucesso!"
Write-Bilingual "Updated $successCount out of $($luatoolsPlugins.Count) plugin(s) / Atualizado(s) $successCount de $($luatoolsPlugins.Count) plugin(s)"

if ($successCount -lt $luatoolsPlugins.Count) {
    $failedCount = $luatoolsPlugins.Count - $successCount
    Write-Warning "$failedCount plugin(s) failed to update / $failedCount plugin(s) falharam na atualizacao"
}

Write-Output ""
Write-Bilingual "Press any key to restart Steam... / Pressione qualquer tecla para reiniciar o Steam..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Kill Steam process
Write-Bilingual "Closing Steam... / Fechando Steam..."
try {
    Get-Process -Name "steam" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction Stop
    Write-Success "Steam process closed / Processo Steam fechado"
} catch {
    Write-Warning "No Steam process found or could not close / Nenhum processo Steam encontrado ou nao foi possivel fechar"
}

# Wait 2 seconds
Start-Sleep -Seconds 2

# Start Steam with -clearbeta flag
Write-Bilingual "Starting Steam with -clearbeta flag... / Iniciando Steam com flag -clearbeta..."
try {
    $steamExe = Join-Path -Path $steamPath -ChildPath "Steam.exe"
    if (Test-Path -Path $steamExe) {
        Start-Process -FilePath $steamExe -ArgumentList "-clearbeta"
        Write-Success "Steam started successfully / Steam iniciado com sucesso"
    } else {
        Write-Error "Steam.exe not found / Steam.exe nao encontrado"
    }
} catch {
    Write-Error "Failed to start Steam / Falha ao iniciar Steam"
    Write-Error "Error: $($_.Exception.Message) / Erro: $($_.Exception.Message)"
}

Write-Output ""
Write-Success "Script completed / Script finalizado"
