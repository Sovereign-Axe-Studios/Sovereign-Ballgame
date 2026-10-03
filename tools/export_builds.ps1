<#
.SYNOPSIS
Exports the game into builds/<version>/<Platform>/<Mode>/, with the version
read from project.godot's application/config/version.

.DESCRIPTION
Godot's export presets can't put the version in their export_path, so the
presets keep builds/unversioned/... for one-off exports from the editor, and
this script swaps that prefix for the version. Bump the version in
project.godot (Project Settings > Application > Config > Version) and the next
run lands in a fresh folder; re-running the same version overwrites it.

Debug presets export with Godot's debug template, Limited and Release with the
release template.

.PARAMETER Platforms
Which preset platforms to export, matched against the start of each preset
name ("Windows - Release" is platform Windows). Defaults to the two that
export on this machine without signing setup.

.PARAMETER Modes
Which build modes to export. Defaults to all three.

.PARAMETER Godot
The Godot console executable. Defaults to $env:GODOT, then the copy beside
the Projects folder.

.EXAMPLE
tools\export_builds.ps1
tools\export_builds.ps1 -Platforms Windows -Modes Release
tools\export_builds.ps1 -Platforms Windows,Web,Android
#>
param(
	[string[]]$Platforms = @("Windows", "Web"),
	[string[]]$Modes = @("Debug", "Limited", "Release"),
	[string]$Godot = $(if ($env:GODOT) { $env:GODOT } else {
		Join-Path $PSScriptRoot "..\..\..\Godot_v4.7.1-stable_win64_console.exe"
	})
)

$ErrorActionPreference = "Stop"
$project = Resolve-Path (Join-Path $PSScriptRoot "..\game")

if (-not (Test-Path $Godot)) {
	throw "Godot not found at '$Godot'. Pass -Godot or set `$env:GODOT."
}

$versionLine = Select-String -Path (Join-Path $project "project.godot") -Pattern '^config/version="(.+)"' |
	Select-Object -First 1
if ($null -eq $versionLine) {
	throw "No application/config/version in project.godot."
}
$version = $versionLine.Matches[0].Groups[1].Value

# Preset name -> export_path, in file order. Each [preset.N] block has its
# name= line before its export_path= line.
$presets = @()
$name = $null
foreach ($line in Get-Content (Join-Path $project "export_presets.cfg")) {
	if ($line -match '^name="(.+)"$') { $name = $Matches[1] }
	elseif ($line -match '^export_path="(.*)"$' -and $null -ne $name) {
		$presets += [pscustomobject]@{ Name = $name; Path = $Matches[1] }
		$name = $null
	}
}

$selected = $presets | Where-Object {
	$parts = $_.Name -split " - ", 2
	$parts.Count -eq 2 -and $Platforms -contains $parts[0] -and $Modes -contains $parts[1]
}
if (-not $selected) {
	throw "No presets match platforms '$($Platforms -join ", ")' and modes '$($Modes -join ", ")'."
}

Write-Host "Exporting version $version" -ForegroundColor Cyan
$failed = @()
foreach ($preset in $selected) {
	if ($preset.Path -notlike "builds/unversioned/*") {
		Write-Warning "$($preset.Name): export_path '$($preset.Path)' isn't under builds/unversioned/, skipping."
		$failed += $preset.Name
		continue
	}
	$out = $preset.Path -replace '^builds/unversioned/', "builds/$version/"
	New-Item -ItemType Directory -Force -Path (Join-Path $project (Split-Path $out)) | Out-Null
	$flag = if ($preset.Name -like "* - Debug") { "--export-debug" } else { "--export-release" }

	Write-Host "  $($preset.Name) -> $out"
	# Godot logs every packed file to stdout; keep only the lines worth seeing.
	# Windows PowerShell wraps each stderr line of a native exe in an error
	# record, which "Stop" would turn into a crash on Godot's first notice (e.g.
	# "Unable to open Android 'build-tools' directory" with no SDK set up), so
	# relax it for this call; $LASTEXITCODE is what says whether it failed.
	$ErrorActionPreference = "Continue"
	& $Godot --headless --path $project $flag $preset.Name $out 2>&1 |
		ForEach-Object { "$_" } |
		Where-Object {
			$_ -match '^(\x1b\[[0-9;]*m)*\s*(ERROR|WARNING):' -and
			$_ -notmatch "ObjectDB instances|resources still in use"
		} |
		ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
	$exitCode = $LASTEXITCODE
	$ErrorActionPreference = "Stop"
	if ($exitCode -ne 0) { $failed += $preset.Name }
}

if ($failed) {
	Write-Host "Failed: $($failed -join ", ")" -ForegroundColor Red
	exit 1
}
Write-Host "Done: game\builds\$version\" -ForegroundColor Green
