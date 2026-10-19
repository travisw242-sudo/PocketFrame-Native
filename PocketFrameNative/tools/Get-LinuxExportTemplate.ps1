param([string]$Destination = (Join-Path $PSScriptRoot '..\..\work\native-export-runtime'))
$ErrorActionPreference='Stop'
# Fetch only the Linux ARM64 release entry, rather than keeping a 1.2 GB archive
# containing export templates for every platform. HTTPS source is official Godot.
$url='https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
$client=[System.Net.Http.HttpClient]::new()
$client.Timeout=[TimeSpan]::FromMinutes(5)
function Read-RemoteRange([long]$First,[long]$Last) {
    $request=[System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get,$url)
    $request.Headers.Range=[System.Net.Http.Headers.RangeHeaderValue]::new($First,$Last)
    $response=$client.SendAsync($request,[System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
    try {
        if ([int]$response.StatusCode -ne 206) { throw "Server did not honor byte ranges; refusing full archive download ($($response.StatusCode))." }
        $bytes=$response.Content.ReadAsByteArrayAsync().GetAwaiter().GetResult()
        if ($bytes.LongLength -ne $Last-$First+1) { throw 'Incomplete range response' }
        Write-Output -NoEnumerate $bytes
    } finally { $response.Dispose(); $request.Dispose() }
}
$info=Invoke-RestMethod 'https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable'
$asset=$info.assets | Where-Object name -eq 'Godot_v4.7.2-stable_export_templates.tpz'
if (!$asset) { throw 'Official export archive not found' }
$tail=Read-RemoteRange ($asset.size-65557) ($asset.size-1)
$end=-1
for ($i=$tail.Length-22;$i -ge 0;$i--) { if ([BitConverter]::ToUInt32($tail,$i) -eq 0x06054b50) { $end=$i;break } }
if ($end -lt 0) { throw 'ZIP end directory missing' }
$directorySize=[BitConverter]::ToUInt32($tail,$end+12)
$directoryOffset=[BitConverter]::ToUInt32($tail,$end+16)
$directory=Read-RemoteRange $directoryOffset ($directoryOffset+$directorySize-1)
$match=$null
for ($i=0;$i -lt $directory.Length;) {
    if ([BitConverter]::ToUInt32($directory,$i) -ne 0x02014b50) { throw 'Invalid ZIP directory' }
    $nameSize=[BitConverter]::ToUInt16($directory,$i+28)
    $extraSize=[BitConverter]::ToUInt16($directory,$i+30)
    $commentSize=[BitConverter]::ToUInt16($directory,$i+32)
    $name=[Text.Encoding]::UTF8.GetString($directory,$i+46,$nameSize)
    if ($name -eq 'templates/linux_release.arm64') {
        $match=@{ Offset=[BitConverter]::ToUInt32($directory,$i+42); Compressed=[BitConverter]::ToUInt32($directory,$i+20); Length=[BitConverter]::ToUInt32($directory,$i+24); Method=[BitConverter]::ToUInt16($directory,$i+10) }
        break
    }
    $i+=46+$nameSize+$extraSize+$commentSize
}
if (!$match -or $match.Method -ne 8) { throw 'Linux ARM64 release entry not found or unsupported compression' }
$header=Read-RemoteRange $match.Offset ($match.Offset+29)
if ([BitConverter]::ToUInt32($header,0) -ne 0x04034b50) { throw 'Invalid local ZIP entry' }
$dataOffset=$match.Offset+30+[BitConverter]::ToUInt16($header,26)+[BitConverter]::ToUInt16($header,28)
$compressed=Read-RemoteRange $dataOffset ($dataOffset+$match.Compressed-1)
$resolved=[IO.Path]::GetFullPath($Destination)
[IO.Directory]::CreateDirectory($resolved) | Out-Null
$target=Join-Path $resolved 'linux_release.arm64'
if (Test-Path -LiteralPath $target) { throw "Template already exists: $target" }
$memory=[IO.MemoryStream]::new($compressed,$false)
$inflate=[IO.Compression.DeflateStream]::new($memory,[IO.Compression.CompressionMode]::Decompress)
$output=[IO.File]::Create($target)
try { $inflate.CopyTo($output) } finally { $output.Dispose();$inflate.Dispose();$memory.Dispose();$client.Dispose() }
if ((Get-Item -LiteralPath $target).Length -ne $match.Length) { throw 'Extracted template size mismatch' }
Get-FileHash -LiteralPath $target -Algorithm SHA256
