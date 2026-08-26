param(
    [string]$ModsPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) "My Games\Sid Meier's Civilization 5\MODS")
)

$ErrorActionPreference = 'Stop'

$replacement = Join-Path $PSScriptRoot '..\Source Patches\Super Civs - Marvel Pack v4\Lua\JGR_Lua.lua'
$replacement = [IO.Path]::GetFullPath($replacement)

if (-not (Test-Path -LiteralPath $replacement -PathType Leaf)) {
    throw "Patched JGR_Lua.lua was not found at: $replacement"
}

if (-not (Test-Path -LiteralPath $ModsPath -PathType Container)) {
    throw "Civilization V MODS directory was not found at: $ModsPath"
}

$targetNames = @(
    'Super Civs - Marvel Pack - Local Optimized (v 4)',
    'Super Civs - Marvel Pack (v 4)'
)

$targets = Get-ChildItem -LiteralPath $ModsPath -Directory |
    Where-Object { $targetNames -contains $_.Name }

if (-not $targets) {
    throw 'Super Civs - Marvel Pack v4 is not installed.'
}

$patchedCount = 0
foreach ($target in $targets) {
    $luaPath = Join-Path $target.FullName 'Lua\JGR_Lua.lua'
    $modInfoPath = Join-Path $target.FullName 'Super Civs - Marvel Pack (v 4).modinfo'

    if (-not (Test-Path -LiteralPath $luaPath -PathType Leaf)) {
        Write-Warning "Skipping $($target.Name): Lua\JGR_Lua.lua is missing."
        continue
    }

    $currentText = Get-Content -LiteralPath $luaPath -Raw
    $alreadySafe = $currentText.Contains('for iOtherPlayer = 0, GameDefines.MAX_MAJOR_CIVS - 1 do') -and
        $currentText.Contains('GetInfluenceLevel(iOtherPlayer)')
    if ($alreadySafe) {
        Write-Host "$($target.Name) is already protected from the Jean Grey player-index crash."
        continue
    }

    $knownUnsafe = $currentText.Contains('for i, otherPlayer in pairs(Players) do') -and
        $currentText.Contains('GetInfluenceLevel(otherPlayer:GetID())')
    if (-not $knownUnsafe) {
        Write-Warning "Skipping $($target.Name): JGR_Lua.lua is not the known v4 source."
        continue
    }

    $luaBackup = "$luaPath.bak-before-solusgo-jean-grey-fix"
    if (-not (Test-Path -LiteralPath $luaBackup)) {
        Copy-Item -LiteralPath $luaPath -Destination $luaBackup
    }
    Copy-Item -LiteralPath $replacement -Destination $luaPath -Force

    if (Test-Path -LiteralPath $modInfoPath -PathType Leaf) {
        $modInfoBackup = "$modInfoPath.bak-before-solusgo-jean-grey-fix"
        if (-not (Test-Path -LiteralPath $modInfoBackup)) {
            Copy-Item -LiteralPath $modInfoPath -Destination $modInfoBackup
        }

        $md5 = (Get-FileHash -LiteralPath $luaPath -Algorithm MD5).Hash
        $modInfo = Get-Content -LiteralPath $modInfoPath -Raw
        $pattern = '(<File md5=")[A-Fa-f0-9]+(" import="0">Lua/JGR_Lua\.lua</File>)'
        $modInfo = [regex]::Replace($modInfo, $pattern, {
            param($match)
            $match.Groups[1].Value + $md5 + $match.Groups[2].Value
        })
        Set-Content -LiteralPath $modInfoPath -Value $modInfo -Encoding UTF8
    }

    $patchedCount++
    Write-Host "Patched $($target.Name)."
}

if ($patchedCount -eq 0) {
    Write-Host 'No files needed changing.'
} else {
    Write-Host "Applied the Jean Grey fix to $patchedCount Marvel pack installation(s)."
}
