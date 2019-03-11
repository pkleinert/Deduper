# ExportVMs.ps1 - Exports all virtual machines, deduplicates them and optionally copies the deduplicated ones to a different folder
#
# Par1 - New Backup Folder: "F:\Hyper-V-Bak\HYPERV3"
# Par2 - (optional) Count of history backups to keep; older will be deleted: -1 (backup history not touched) or 5 (the newly created one and 5 older backups will be kept)
# Par3 - (optional) Base Folder: if specified, "G:\Hyper-V-Bak\HYPERV3"
# Par4 - (optional) Diff Backup Folder or "make_new_base": "make_new_base" or "G:\Hyper-V-Bak-Diff\HYPERV3"
# Par5 - (optional) Count of history backup bases to keep; older will be deleted: -1 (base backup history not touched) or 1 (the newly created one and 1 older base backups will be kept)

#[Parameter(Mandatory=$true)]
Param (
#   [Parameter(Mandatory=$true)]
    [Parameter(Mandatory=$true)][String]$BackupFolder, # = "F:\Hyper-V-Bak\HYPERV3",
    [Int]$HistoryKeep, # = -1,
    [String]$DedupBase, # = "G:\Hyper-V-Bak\HYPERV3",
    [String]$DiffBackupFolder, # = "make_new_base", #"G:\Hyper-V-Bak-Diff\HYPERV3",
    [Int]$BaseHistoryKeep = 2
)

# Preset variables
$Date=Get-Date -format "yyyyMMdd"
$Time=Get-Date -format "HHmm"
$HistoryFile="$BackupFolder\history.txt"

# Lower process priority
(get-process | ?{$_.ID -eq $pid}).priorityclass = "BelowNormal"

# Create backup (sub)folders
New-Item -Force "$BackupFolder" -Type directory | Out-Null
$BackupFolder="$BackupFolder\$Date-$Time"
New-Item -Force "$BackupFolder" -Type directory | Out-Null

# Log Start
$LogFile="$BackupFolder\log.txt"
Write-Output "ExportVMs started at: $(Get-Date -format "HH:mm:ss")" | Tee-Object -FilePath "$LogFile"

# Backup history
if ($HistoryKeep -lt 0) {
    Write-Output "Not touching previous backups..." | Tee-Object -Append -FilePath "$LogFile"
} else {
    # Check backup count
    $HistoryCnt = (Get-Content "$HistoryFile" | Measure-Object –Line).Lines
    if ($HistoryCnt -gt $HistoryKeep) {
    	# delete the oldest backup
    	$ToDelete=(Get-Content "$HistoryFile" -First 1)
    	Write-Output "Backup history: Deleting oldest backup: $ToDelete..." | Tee-Object -Append -FilePath "$LogFile"
    	Remove-Item -Recurse -Force "$ToDelete" | Out-File -Append "$LogFile"
    	Write-Output " done" | Tee-Object -Append -FilePath "$LogFile"

    	# Keep only $HistoryKeep backups
    	$ToKeep=(Get-Content "$HistoryFile" -Last $HistoryKeep)
    	Write-Output $ToKeep > $HistoryFile
    } else {
    	Write-Output "Backup history: NOT enough backups in the history yet" | Tee-Object -Append -FilePath "$LogFile"
    }
}

Import-Module Hyper-V
$VMs = Get-VM

Write-Output "Starting backup at $(Get-Date -format "HH:mm:ss")" | Tee-Object -Append -FilePath "$LogFile"
foreach($VM in $VMs)
{
    #Exporting virtual machine to a local drive
    $Begin=Get-Date
    Write-Output ("VM: "+($VM.VMName)) | Tee-Object -Append -FilePath "$LogFile"
    Export-VM $VM -Path "$BackupFolder"
    Write-Output "   m $($(Get-Date) - $Begin)" | Tee-Object -Append -FilePath "$LogFile"
}

#Write-Output "Compressing at $(Get-Date -format "HH:mm:ss")" | Tee-Object -Append -FilePath "$LogFile"
#cd "$BackupFolder"
#foreach($VM in $VMs)
#{
#	# Compress a virtual machine
#	$Begin=Get-Date
#	Write-Output ("VM: "+($VM.VMName)) | Tee-Object -Append -FilePath "$LogFile"
#	#&"c:\Program Files\WinRAR\WinRAR.exe" -m1 -mt8 m (($VM.VMName)+".rar") $VM.VMName
#	&"c:\Program Files\WinRAR\RAR.exe" -m1 -mt8 m (($VM.VMName)+".rar") $VM.VMName | Tee-Object -Append -FilePath "$LogFile"
#	Write-Output "   c $($(Get-Date) - $Begin)" | Tee-Object -Append -FilePath "$LogFile"
#}

# When all successful => Add to history
if ($HistoryKeep -lt 0) {
    Write-Output "Not modifying backup history..." | Tee-Object -Append -FilePath "$LogFile"
} else {
    Write-Output "Adding `"$BackupFolder`" to backup history..." | Tee-Object -Append -FilePath "$LogFile"
    Write-Output "$BackupFolder" >> $HistoryFile
}

# (optional) Deduplication postprocessing
if (-not ([string]::IsNullOrEmpty($DiffBackupFolder))) {
    $BaseHistoryFile="$DedupBase`\base_history.txt"
    Write-Output "Deduplicating at $(Get-Date -format "HH:mm:ss")" | Tee-Object -Append -FilePath "$LogFile"

    if ($DiffBackupFolder -ieq "make_new_base") {
        # Make a new base folder
        $BaseFolder="$DedupBase" + '\' + "$Date-$Time"
        Write-Output "Hashing new base folder: $BaseFolder" | Tee-Object -Append -FilePath "$LogFile"
        .\HyperVBackupDeduper.ps1 "$BackupFolder" | Tee-Object -Append -FilePath "$LogFile"
        Write-Output "Creating new base folder: $BaseFolder" | Tee-Object -Append -FilePath "$LogFile"
        Copy-Item -Recurse "$BackupFolder" -Destination "$BaseFolder"

        # Base backup history
        if ($BaseHistoryKeep -lt 0) {
            Write-Output "Not touching previous base backups..." | Tee-Object -Append -FilePath "$LogFile"
        } else {
            # Check base backup count
            $HistoryCnt = (Get-Content "$BaseHistoryFile" | Measure-Object –Line).Lines
            if ($HistoryCnt -gt $BaseHistoryKeep) {
    	        # delete the oldest backup
    	        $ToDelete=(Get-Content "$BaseHistoryFile" -First 1)
    	        Write-Output "Base backup history: Deleting oldest backup: $ToDelete..." | Tee-Object -Append -FilePath "$LogFile"
    	        Remove-Item -Recurse -Force "$DedupBase`\$ToDelete" | Out-File -Append "$LogFile"
    	        Write-Output "Base backup history: done" | Tee-Object -Append -FilePath "$LogFile"

    	        # Keep only $HistoryKeep backups
    	        $ToKeep=(Get-Content "$BaseHistoryFile" -Last $BaseHistoryKeep)
    	        Write-Output $ToKeep > $BaseHistoryFile
            } else {
    	        Write-Output "Base backup history: NOT enough backups in the history yet ($HistoryCnt <= $BaseHistoryKeep)" | Tee-Object -Append -FilePath "$LogFile"
            }
            # Write this new base to the base history file
            Write-Output $Date-$Time >> $BaseHistoryFile
        }

    } else {
        # Deduplicate
        Write-Output "Deduplicating and copying deduplicated backups to folder: $DiffBackupFolder" | Tee-Object -Append -FilePath "$LogFile"
        $BaseFolder=$DedupBase + '\' + (Get-Content "$BaseHistoryFile" -Last 1)
        Write-Output ".\HyperVBackupDeduper.ps1 `"$BaseFolder`" `"$BackupFolder`" `"$DiffBackupFolder\$Date-$Time`"" | Tee-Object -Append -FilePath "$LogFile"
        .\HyperVBackupDeduper.ps1 "$BackupFolder" "$BaseFolder" "$DiffBackupFolder\$Date-$Time" | Tee-Object -Append -FilePath "$LogFile"
    }
}

Write-Output "Finished at $(Get-Date -format "HH:mm:ss")" | Tee-Object -Append -FilePath "$LogFile"
