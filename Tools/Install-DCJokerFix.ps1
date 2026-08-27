param(
    [string]$ModsPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "My Games\Sid Meier's Civilization 5\MODS")
)

$ErrorActionPreference = 'Stop'

$replacement = Join-Path $PSScriptRoot '..\Source Patches\Super Civs - DC Pack v4\Lua\JOK_Lua.lua'
$replacement = [IO.Path]::GetFullPath($replacement)

if (-not (Test-Path -LiteralPath $replacement -PathType Leaf)) {
    throw "Patched JOK_Lua.lua was not found at: $replacement"
}

if (-not (Test-Path -LiteralPath $ModsPath -PathType Container)) {
    throw "Civilization V MODS directory was not found at: $ModsPath"
}

$targetNames = @(
    'Super Civs - DC Pack - Local Optimized (v 4)',
    'Super Civs - DC Pack (v 4)'
)

$targets = Get-ChildItem -LiteralPath $ModsPath -Directory |
    Where-Object { $targetNames -contains $_.Name }

if (-not $targets) {
    throw 'Super Civs - DC Pack v4 is not installed.'
}

function Update-JokerManifestHash {
    param(
        [Parameter(Mandatory = $true)][string]$LuaPath,
        [Parameter(Mandatory = $true)][string]$ModInfoPath
    )

    if (-not (Test-Path -LiteralPath $ModInfoPath -PathType Leaf)) {
        Write-Warning "Manifest is missing: $ModInfoPath"
        return
    }

    $modInfoBackup = "$ModInfoPath.bak-before-solusgo-joker-fix"
    if (-not (Test-Path -LiteralPath $modInfoBackup)) {
        Copy-Item -LiteralPath $ModInfoPath -Destination $modInfoBackup
    }

    $md5 = (Get-FileHash -LiteralPath $LuaPath -Algorithm MD5).Hash
    $modInfo = Get-Content -LiteralPath $ModInfoPath -Raw
    $pattern = '(<File md5=")[A-Fa-f0-9]+(" import="0">Lua/JOK_Lua\.lua</File>)'
    $updated = [regex]::Replace($modInfo, $pattern, {
        param($match)
        $match.Groups[1].Value + $md5 + $match.Groups[2].Value
    })

    if ($updated -eq $modInfo) {
        if (-not $modInfo.Contains($md5)) {
            Write-Warning "Could not locate the Joker Lua hash entry in: $ModInfoPath"
        }
        return
    }

    Set-Content -LiteralPath $ModInfoPath -Value $updated -Encoding UTF8
}

$patchedCount = 0
$safeCount = 0
foreach ($target in $targets) {
    $luaPath = Join-Path $target.FullName 'Lua\JOK_Lua.lua'
    $modInfoPath = Join-Path $target.FullName 'Super Civs - DC Pack (v 4).modinfo'

    if (-not (Test-Path -LiteralPath $luaPath -PathType Leaf)) {
        Write-Warning "Skipping $($target.Name): Lua\JOK_Lua.lua is missing."
        continue
    }

    $currentText = Get-Content -LiteralPath $luaPath -Raw
    $alreadySafe = $currentText.Contains('SOLUSGO_JOK_GOLDEN_AGE_CONVERTED_') -and
        $currentText.Contains('JOKTrimRunawayClowns')
    if ($alreadySafe) {
        Update-JokerManifestHash -LuaPath $luaPath -ModInfoPath $modInfoPath
        $safeCount++
        Write-Host "$($target.Name) is already protected from runaway temporary Clowns."
        continue
    }

    $knownUnsafe = $currentText.Contains('if pPlayer:IsGoldenAge() then') -and
        $currentText.Contains('pPlayer:SetAnarchyNumTurns(turns)') -and
        $currentText.Contains('pPlayer:InitUnit(iJOKUnitClown')
    if (-not $knownUnsafe) {
        Write-Warning "Skipping $($target.Name): JOK_Lua.lua is not the known v4 source."
        continue
    }

    $luaBackup = "$luaPath.bak-before-solusgo-joker-fix"
    if (-not (Test-Path -LiteralPath $luaBackup)) {
        Copy-Item -LiteralPath $luaPath -Destination $luaBackup
    }
    Copy-Item -LiteralPath $replacement -Destination $luaPath -Force
    Update-JokerManifestHash -LuaPath $luaPath -ModInfoPath $modInfoPath

    $patchedCount++
    Write-Host "Patched $($target.Name)."
}

if ($patchedCount -eq 0) {
    Write-Host "No files needed changing. $safeCount installation(s) already safe."
} else {
    Write-Host "Applied the Joker fix to $patchedCount DC pack installation(s); $safeCount already safe."
}
