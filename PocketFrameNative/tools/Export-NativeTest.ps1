param([string]$Destination,[string]$GodotExecutable,[string]$LicenseDirectory)
$ErrorActionPreference='Stop'
$project=Split-Path $PSScriptRoot -Parent
$workspace=Split-Path $project -Parent
$engine=Join-Path $workspace 'PocketFrame\Godot\Godot_v4.7.2-stable_win64_console.exe'
if ($GodotExecutable) { $engine=[IO.Path]::GetFullPath($GodotExecutable) }
if (!$Destination) { $Destination=Join-Path $workspace ('outputs\native-tests\'+(Get-Date -Format 'yyyyMMdd-HHmmss')) }
$Destination=[IO.Path]::GetFullPath($Destination)
if (Test-Path -LiteralPath $Destination) { throw 'Choose a new empty output folder; existing builds are not overwritten.' }
$libraries=@(
    (Join-Path $project 'bin\libPocketFrameRuntime.so'),
    (Join-Path $project 'runtime\vulkan\azahar_libretro.so'))
foreach($library in $libraries) {
    $stream=[IO.File]::OpenRead($library)
    try {
        $header=[byte[]]::new(20)
        if ($stream.Read($header,0,20) -ne 20) { throw "Truncated library: $library" }
        if ($header[0] -ne 0x7f -or [Text.Encoding]::ASCII.GetString($header,1,3) -ne 'ELF' -or $header[4] -ne 2 -or $header[5] -ne 1 -or [BitConverter]::ToUInt16($header,18) -ne 183) {
            throw "Not a Linux ARM64 ELF library: $library"
        }
    } finally { $stream.Dispose() }
}
New-Item -ItemType Directory -Path $Destination | Out-Null
& $engine --headless --xr-mode off --path $project --export-release 'Steam Frame ARM64' (Join-Path $Destination 'PocketFrameNative.arm64')
if ($LASTEXITCODE -ne 0) { throw "Godot export failed: $LASTEXITCODE" }
& $engine --headless --xr-mode off --main-pack (Join-Path $Destination 'PocketFrameNative.pck') -- --audit-export
if ($LASTEXITCODE -ne 0) { throw 'Exported resource pack failed its load/privacy audit.' }
$runtime=Join-Path $Destination 'runtime\vulkan'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
Copy-Item -LiteralPath $libraries[1] -Destination $runtime
New-Item -ItemType Directory -Path (Join-Path $Destination 'games') | Out-Null
$notices=Join-Path $workspace 'outputs\releases\PocketFrame-0.2-preview\licenses'
if ($LicenseDirectory) { $notices=[IO.Path]::GetFullPath($LicenseDirectory) }
if (!(Test-Path -LiteralPath $notices)) { throw 'Licence notices unavailable; do not distribute this test build.' }
Copy-Item -LiteralPath $notices -Destination (Join-Path $Destination 'licenses') -Recurse
Copy-Item -LiteralPath (Join-Path $project 'docs\NATIVE_TEST.md') -Destination $Destination
Get-ChildItem -LiteralPath $Destination -File -Recurse | Get-FileHash -Algorithm SHA256
Write-Output 'Local headset-test build only. Public sharing requires matching complete source and dependency review.'
