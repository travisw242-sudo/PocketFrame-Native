param(
    [Parameter(Mandatory=$true)][string]$Address,
    [switch]$ImportOldTestGames
)
$ErrorActionPreference='Stop'
if ($Address -notmatch '^[A-Za-z0-9][A-Za-z0-9.:-]*$') { throw 'Use the paired headset IP address or hostname, not a URL.' }
$identity=Join-Path $env:LOCALAPPDATA 'steamos-devkit\steamos-devkit\devkit_rsa'
if (!(Test-Path -LiteralPath $identity)) { throw 'Pair this PC through Valve SteamOS Devkit Client first.' }
$ssh=Join-Path $env:WINDIR 'System32\OpenSSH\ssh.exe'
$scp=Join-Path $env:WINDIR 'System32\OpenSSH\scp.exe'
$options=@('-o','BatchMode=yes','-o','IdentitiesOnly=yes','-o','StrictHostKeyChecking=yes','-o','ConnectTimeout=8','-i',$identity)
$remote='pocketframe-preview-upload-'+[Guid]::NewGuid().ToString('N')
& $ssh @options "steamos@$Address" "mkdir -m 700 /home/steamos/$remote"
if ($LASTEXITCODE -ne 0) { throw 'Connection failed. Wake headset and check pairing/address.' }
& $scp @options -r "$PSScriptRoot/." "steamos@${Address}:/home/steamos/$remote/"
if ($LASTEXITCODE -ne 0) { throw 'Upload failed; active app and games are unchanged.' }
$command="python3 /home/steamos/$remote/install.py --register"
if ($ImportOldTestGames) { $command+=' --import-games /home/steamos/devkit-game/PocketFrameNativeAlpha_20261016/games' }
& $ssh @options "steamos@$Address" $command
if ($LASTEXITCODE -ne 0) { throw 'Installer stopped. Read the message above; original games/saves are preserved.' }
Write-Output 'Ready: Library > Non-Steam > Devkit Game: PocketFrame'
Write-Output "Uploaded installer retained at /home/steamos/$remote for verification or rollback."
