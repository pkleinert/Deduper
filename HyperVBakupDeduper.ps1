param (
    [Parameter(Mandatory=$true)][string]$DedupLast
)

$DedupBase=(Get-Content .\dedup_last_full.txt -TotalCount 1)

echo "Deduplication base: $DedupBase"
echo "Deduplication last: $DedupLast"

echo "Deduplicating VHDX disks:"
$DiskPaths=(Get-ChildItem -Recurse -Path "$BackupFolder\$DedupLast" -File -Filter "*.vhdx" -Name)

foreach($DiskPath in $diskPaths) {
  $FileBase="$DedupBase\$DiskPath"
  $FileLast="$DedupLast\$DiskPath"
  $FileDedup=([IO.Path]::GetDirectoryName($FileLast) + '\' + [IO.Path]::GetFileNameWithoutExtension($FileLast) + ".ded")

  if (Test-Path "$BackupFolder\$DedupBase\$DiskPath" ) {
    echo "$FileBase # $FileLast -> $FileDedup"
    .\Deduper.exe -d "$FileBase" "$FileLast" "$FileDedup"
  } else {
    echo ":( $FileBase"
  }
}

