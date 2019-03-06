# HyperVBackupDeduper.ps1 - Deduplicates files and optionally copies the deduplicated ones to a different folder
#
# Par1 - Backup Folder: "F:\Hyper-V-Bak\HYPERV3\20190303-0006"
# Par2 - (opt) Base Folder: "G:\Hyper-V-Bak\HYPERV3\20190301-0005"
# Par3 - (opt) Diff Backup Folder: "G:\Hyper-V-Bak-Diff\HYPERV3\20190303-0006" (optional)
# Par4 - (opt) Path to the Dedup.exe; default: ".\Deduper.exe"

Param (
  [Parameter(Mandatory=$true)][String]$BackupFolder,
  [String]$BaseFolder = '', # if empty: just create hashes for a new base backup creation
  [String]$DiffBackupFolder = '',
  [string]$DeduperExe=".\Deduper.exe"
)

function DoDedup {
  Param ($filter)
  $DiskPaths=(Get-ChildItem -Recurse -Path "$BackupFolder" -File -Filter $filter -Name)
  foreach($DiskPath in $diskPaths) {
    echo ("{0:yyyy-MM-dd hh:mm:ss}" -f (get-date))
    $FileLast="$BackupFolder\$DiskPath"

    if (([string]::IsNullOrEmpty($BaseFolder))) {
      # Just create hashes; don't deduplicate
      echo ":] $FileLast"
      &($DeduperExe) -sh "$FileLast"
    } else {
      # Deduplicate
      $FileBase="$BaseFolder\$DiskPath"
      $FileDedup=$FileLast + ".dex"
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
}

echo "Deduplication base: $BaseFolder"
echo "Backup to dedup:    $BackupFolder"
echo "Dedup destination:  $DiffBackupFolder"

echo "Deduplicating VHDX disks:"
DoDedup("*.vhdx")
echo "Deduplicating VHD disks:"
DoDedup("*.vhd")
echo "Deduplicating AVHDX disks:"
DoDedup("*.avhdx")

# Copy deduplicated backups to a new folder (skip VHD, VHDX, AVHDX files)
if (-not ([string]::IsNullOrEmpty($DiffBackupFolder)))
{
  echo "Copying deduplicated backups to folder: $DiffBackupFolder"
  New-Item -Force "$DiffBackupFolder" -type directory | Out-Null
  $exclude = @("*.vhd","*.vhdx","*.avhdx")
  Get-ChildItem $BackupFolder -Recurse -Exclude $exclude | Copy-Item -Destination {Join-Path $DiffBackupFolder $_.FullName.Substring($BackupFolder.length)}
  echo "Done"
} else {
  echo "NOT copying deduplicated backups to folder: No destination folder specified"
}
