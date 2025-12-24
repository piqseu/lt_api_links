#Requires -Version 5.1
# Clean Lua Script - Removes bad Lua files from Steam stplug-in folder

# Clear screen
Clear-Host

# Header
Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "Lua Cleaner - by discord.gg/luatools" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# Step 0: Get Steam path from registry
Write-Host "Step 0: Locating Steam installation..." -ForegroundColor Yellow

function Get-SteamPath {
    $steamPath = $null
    
    Write-Host "  Searching for Steam installation..." -ForegroundColor Gray
    
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

$steamPath = Get-SteamPath

if (-not $steamPath) {
    Write-Host "  [ERROR] Steam installation not found in registry." -ForegroundColor Red
    Write-Host "  Please ensure Steam is installed on your system." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host
    exit
}

Write-Host "  [SUCCESS] Steam found!" -ForegroundColor Green
Write-Host "  Location: $steamPath" -ForegroundColor White
Write-Host ""

# Step 1: Check for non-.lua files in stplug-in folder
Write-Host "Step 1: Checking stplug-in folder..." -ForegroundColor Yellow
$stpluginPath = Join-Path $steamPath "config\stplug-in"

if (-not (Test-Path $stpluginPath)) {
    Write-Host "  [ERROR] Luas folder does not exist! Add some games bozo" -ForegroundColor Red
    Write-Host "  Expected path: $stpluginPath" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Press Enter to exit..."
    Read-Host
    exit
}

Write-Host "  [SUCCESS] stplug-in folder found" -ForegroundColor Green
Write-Host "  Location: $stpluginPath" -ForegroundColor White
Write-Host ""

# Collect all bad files
$badFiles = @()

# Step 1: Find non-.lua files
Write-Host "Step 1: Checking for non-.lua files..." -ForegroundColor Yellow
$allFiles = Get-ChildItem -Path $stpluginPath -File -ErrorAction SilentlyContinue

foreach ($file in $allFiles) {
    if ($file.Extension -ne ".lua") {
        Write-Host "  [BAD] Non-Lua file found: $($file.Name)" -ForegroundColor Red
        $badFiles += @{
            File = $file
            BadLines = @()  # Non-Lua files don't have bad lines
        }
    }
}

if ($badFiles.Count -eq 0) {
    Write-Host "  [INFO] No non-.lua files found" -ForegroundColor Cyan
}
Write-Host ""

# Function to validate a line
function Test-ValidLuaLine {
    param([string]$Line)
    
    $trimmedLine = $Line.Trim()
    
    # Check if line is fully blank
    if ([string]::IsNullOrWhiteSpace($trimmedLine)) {
        return $true
    }
    
    # Check if line starts with - (comment or valid line)
    if ($trimmedLine.StartsWith('-')) {
        return $true
    }
    
    # Check if line starts with addappid (case-insensitive) - needs special validation
    if ($trimmedLine -match '^(?i)addappid') {
        # Must have opening parenthesis after addappid (not directly followed by number/letter)
        if (-not $trimmedLine -match '^(?i)addappid\s*\(') {
            # Missing opening paren or has space/characters between addappid and paren
            return $false
        }
        
        # Extract content before any comment
        $beforeComment = $trimmedLine
        if ($trimmedLine.Contains('--')) {
            $beforeComment = $trimmedLine.Substring(0, $trimmedLine.IndexOf('--'))
        }
        
        # Find opening parenthesis
        $openParen = $beforeComment.IndexOf('(')
        if ($openParen -lt 0) {
            return $false
        }
        
        # Find the matching closing parenthesis by counting nested parens
        $parenCount = 0
        $closeParenInComment = -1
        for ($i = $openParen; $i -lt $beforeComment.Length; $i++) {
            if ($beforeComment[$i] -eq '(') {
                $parenCount++
            } elseif ($beforeComment[$i] -eq ')') {
                $parenCount--
                if ($parenCount -eq 0) {
                    $closeParenInComment = $i
                    break
                }
            }
        }
        
        if ($closeParenInComment -lt 0) {
            # No matching closing paren found
            return $false
        }
        
        # Check if there's content after the matching closing parenthesis (before comment)
        # After closing paren, there should only be whitespace or nothing
        if ($closeParenInComment + 1 -lt $beforeComment.Length) {
            $afterCloseParen = $beforeComment.Substring($closeParenInComment + 1).Trim()
            if ($afterCloseParen -ne '' -and -not $afterCloseParen.StartsWith('--')) {
                # There's content after closing paren that's not a comment - invalid
                return $false
            }
        }
        
        # Extract paren content safely
        $parenLength = $closeParenInComment - $openParen - 1
        if ($parenLength -gt 0) {
            $parenContent = $beforeComment.Substring($openParen + 1, $parenLength)
            
            # Check for unquoted hash-like strings (40+ hex characters)
            # Remove all quoted strings first
            $withoutQuotes = $parenContent -replace '"[^"]*"', ''
            # Check if there are unquoted hash-like strings remaining
            if ($withoutQuotes -match '[a-f0-9]{40,}') {
                # Found unquoted hash-like string - invalid
                return $false
            }
        }
        
        return $true
    }
    
    # Check if line starts with setManifestid (case-insensitive) - needs special validation
    if ($trimmedLine -match '^(?i)setManifestid') {
        # Must have opening parenthesis after setManifestid (not directly followed by number/letter)
        if (-not $trimmedLine -match '^(?i)setManifestid\s*\(') {
            # Missing opening paren or has space/characters between setManifestid and paren
            return $false
        }
        
        # Extract content before any comment
        $beforeComment = $trimmedLine
        if ($trimmedLine.Contains('--')) {
            $beforeComment = $trimmedLine.Substring(0, $trimmedLine.IndexOf('--'))
        }
        
        # Find opening parenthesis
        $openParen = $beforeComment.IndexOf('(')
        if ($openParen -lt 0) {
            return $false
        }
        
        # Find the matching closing parenthesis by counting nested parens
        $parenCount = 0
        $closeParenInComment = -1
        for ($i = $openParen; $i -lt $beforeComment.Length; $i++) {
            if ($beforeComment[$i] -eq '(') {
                $parenCount++
            } elseif ($beforeComment[$i] -eq ')') {
                $parenCount--
                if ($parenCount -eq 0) {
                    $closeParenInComment = $i
                    break
                }
            }
        }
        
        if ($closeParenInComment -lt 0) {
            # No matching closing paren found
            return $false
        }
        
        # Check if there's content after the matching closing parenthesis (before comment)
        # After closing paren, there should only be whitespace or nothing
        if ($closeParenInComment + 1 -lt $beforeComment.Length) {
            $afterCloseParen = $beforeComment.Substring($closeParenInComment + 1).Trim()
            if ($afterCloseParen -ne '' -and -not $afterCloseParen.StartsWith('--')) {
                # There's content after closing paren that's not a comment - invalid
                return $false
            }
        }
        
        # Extract paren content safely
        $parenLength = $closeParenInComment - $openParen - 1
        if ($parenLength -gt 0) {
            $parenContent = $beforeComment.Substring($openParen + 1, $parenLength)
            
            # Check for unquoted hash-like strings (40+ hex characters)
            # Remove all quoted strings first
            $withoutQuotes = $parenContent -replace '"[^"]*"', ''
            # Check if there are unquoted hash-like strings remaining
            if ($withoutQuotes -match '[a-f0-9]{40,}') {
                # Found unquoted hash-like string - invalid
                return $false
            }
        }
        
        return $true
    }
    
    # Check if line starts with addtoken (case-insensitive)
    if ($trimmedLine -match '^(?i)addtoken') {
        return $true
    }
    
    # If we get here, the line is invalid
    return $false
}

# Step 2: Check every line of every .lua file
Write-Host "Step 2: Checking Lua files for invalid content..." -ForegroundColor Yellow

$luaFiles = Get-ChildItem -Path $stpluginPath -Filter "*.lua" -ErrorAction SilentlyContinue
$luaFileCount = ($luaFiles | Measure-Object).Count

if ($luaFileCount -eq 0) {
    Write-Host "  [INFO] No .lua files found to check" -ForegroundColor Cyan
} else {
    Write-Host "  Found $luaFileCount .lua file(s) to check..." -ForegroundColor Gray
    
    $fileIndex = 0
    foreach ($luaFile in $luaFiles) {
        $fileIndex++
        $hasBadLines = $false
        $badLines = @()  # Array of hashtables with LineNumber and Content
        
        try {
            $lines = Get-Content -Path $luaFile.FullName -ErrorAction Stop
            $lineNumber = 0
            
            foreach ($line in $lines) {
                $lineNumber++
                
                # Check if line is valid using the validation function
                if (-not (Test-ValidLuaLine -Line $line)) {
                    $hasBadLines = $true
                    $badLines += @{
                        LineNumber = $lineNumber
                        Content = $line.Trim()
                    }
                }
            }
            
            if ($hasBadLines) {
                Write-Host "  [BAD] Invalid content in: $($luaFile.Name)" -ForegroundColor Red
                Write-Host "    Bad lines: $(($badLines | ForEach-Object { $_.LineNumber }) -join ', ')" -ForegroundColor Yellow
                # Store file info with bad lines
                $badFiles += @{
                    File = $luaFile
                    BadLines = $badLines
                }
            } else {
                Write-Host "  [OK] $($luaFile.Name)" -ForegroundColor Green
            }
        } catch {
            Write-Host "  [ERROR] Failed to read file: $($luaFile.Name) - $_" -ForegroundColor Red
            $badFiles += @{
                File = $luaFile
                BadLines = @()
            }
        }
        
        # Show progress
        if ($fileIndex % 10 -eq 0 -or $fileIndex -eq $luaFileCount) {
            Write-Host "    Progress: $fileIndex / $luaFileCount files checked..." -ForegroundColor Gray
        }
    }
}

Write-Host ""

# Summary
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

if ($badFiles.Count -eq 0) {
    Write-Host "  [SUCCESS] No bad files found! All files are clean." -ForegroundColor Green
} else {
    Write-Host "  [WARNING] Found $($badFiles.Count) bad file(s):" -ForegroundColor Yellow
    Write-Host ""
    foreach ($badFileInfo in $badFiles) {
        $badFile = $badFileInfo.File
        $badLines = $badFileInfo.BadLines
        
        Write-Host "    - $($badFile.Name)" -ForegroundColor Red
        if ($badLines.Count -gt 0) {
            foreach ($badLine in $badLines) {
                Write-Host "      Line $($badLine.LineNumber): $($badLine.Content)" -ForegroundColor Yellow
            }
        }
        Write-Host ""
    }
}

Write-Host ""
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "Press Enter to exit..." -ForegroundColor Cyan
Write-Host "===============================================================" -ForegroundColor Cyan
Read-Host

