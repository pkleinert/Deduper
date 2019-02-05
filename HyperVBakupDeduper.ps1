param (
    [Parameter(Mandatory=$true)][string]$DedupLast,
    [Parameter(Mandatory=$true)][string]$BackupFolder,
    [string]$BaseFolder=$BackupFolder,
    [string]$DeduperExe=".\Deduper.exe",
    [string]$DedupBase=$(Get-Content ($BaseFolder+'\dedup_last_full.txt') -TotalCount 1)
)

echo "Base root:    $BaseFolder"
echo "Base folder:  $DedupBase"
echo "Executable:   $DeduperExe"
echo "Child root:   $BackupFolder"
echo "Child folder: $DedupLast"

echo "Deduplicating VHDX disks:"
$DiskPaths=(Get-ChildItem -Recurse -Path "$BackupFolder\$DedupLast" -File -Filter "*.vhdx" -Name)

foreach($DiskPath in $diskPaths) {
  echo ("{0:yyyy-MM-dd hh:mm:ss}" -f (get-date))
  $FileBase="$BaseFolder\$DedupBase\$DiskPath"
  $FileLast="$DedupLast\$DiskPath"
  $FileDedup=([IO.Path]::GetDirectoryName($FileLast) + '\' + [IO.Path]::GetFileName($FileLast) + ".dex")

  if (Test-Path $FileBase ) {
    echo ";) $FileBase # $FileLast -> $FileDedup"
    &($DeduperExe) -sd (Resolve-Path($FileBase)) (Resolve-Path($FileLast)) (Resolve-Path($FileDedup))
  } else {
    echo ":( $FileBase"
  }
}
