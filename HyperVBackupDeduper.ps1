# Dedup.ps1
# Par1 - Base Folder: "g:\Hyper-V-Bak\HYPERV3\20190301-0005"
# Par2 - Backup Folder: "f:\Hyper-V-Bak\HYPERV3\20190303-0006"
# Par3 - Diff Backup Folder: "g:\Hyper-V-Bak-Diff\HYPERV3\20190303-0006" (optional)

Param (
  [Parameter(Mandatory=$true)][String]$BaseFolder,
  [Parameter(Mandatory=$true)][String]$BackupFolder,
  [String]$DiffBackupFolder = '',
  [string]$DeduperExe=".\Deduper.exe",
)

function DoDedup {
  Param ($filter)
  $DiskPaths=(Get-ChildItem -Recurse -Path "$BackupFolder" -File -Filter $filter -Name)
  foreach($DiskPath in $diskPaths) {
    echo ("{0:yyyy-MM-dd hh:mm:ss}" -f (get-date))
    $FileBase="$BaseFolder\$DiskPath"
    $FileLast="$BackupFolder\$DiskPath"
    $FileDedup=([IO.Path]::GetDirectoryName($FileLast) + '\' + [IO.Path]::GetFileNameWithoutExtension($FileLast) + ".dex")

    if (Test-Path $FileBase) {
      if (Test-Path $FileDedup) {
        # Skip - Deduplicated file exists already
        echo ":D $FileBase # $FileLast -> $FileDedup"
      } else {
        # Deduplicate
        echo ":) $FileBase # $FileLast -> $FileDedup"
        &($DeduperExe) -sd "$FileBase" "$FileLast" "$FileDedup"
      }
    } else {
      # Skip - There is no corresponding deduplication base
      echo ":( $FileBase"
    }
  }
}

echo "Deduplication base: $BaseFolder"
echo "Backup to dedup:    $BackupFolder"
echo "Dedup destination:  $DiffBackupFolder"

echo "Deduplicating VHD disks:"
DoDedup("*.vhd")
echo "Deduplicating VHDX disks:"
DoDedup("*.vhdx")

# Copy deduplicated backups to a new folder (skip *.VHD* files)
if (-not ([string]::IsNullOrEmpty($DiffBackupFolder)))
{
  echo "Copying deduplicated backups to folder: $DiffBackupFolder"
  $exclude = @("*.vhd","*.vhdx")
  Get-ChildItem $BackupFolder -Recurse -Exclude $exclude | Copy-Item -Destination {Join-Path $DiffBackupFolder $_.FullName.Substring($source.length - 1)}
  echo "Done"
} else {
  echo "NOT copying deduplicated backups to folder: No destination folder specified"
}
