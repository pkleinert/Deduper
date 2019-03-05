$ExportPath="F:\Hyper-V-Bak"
$DedupBase='G:\Hyper-V-Bak\' + $env:computername + '\'
$DiffBackupFolder='G:\Hyper-V-Bak-Diff\' + $env:computername + '\'

Write-Output "Starting Hyper-V backup job" | Out-File -Force "$LogFile"

Write-Output "Output Folder: $ExportPath" | Out-File -Append "$LogFile"

cd "$ExportPath"

(get-process | ?{$_.ID -eq $pid}).priorityclass = "BelowNormal"

$HistoryKeep=[int]5
$Date=Get-Date -format "yyyyMMdd"
$Time=Get-Date -format "HHmm"

New-Item -Force "$ExportPath" -type directory | Out-Null
$ExportPath="$ExportPath\$env:computername"
New-Item -Force "$ExportPath" -Type directory | Out-Null

$HistoryFile="$ExportPath\history.txt"

$ExportPath="$ExportPath\$Date-$Time"
New-Item -Force "$ExportPath" -Type directory | Out-Null

$LogFile="$ExportPath\log.txt"

# Check backup count...
$HistoryCnt = (Get-Content "$HistoryFile" | Measure-Object –Line).Lines
if ($HistoryCnt -gt $HistoryKeep) {
	# delete the oldest backup
	$ToDelete=(Get-Content "$HistoryFile" -First 1)
	Write-Output "Backup history: Deleting oldest backup: $ToDelete..." | Out-File -Append "$LogFile"
	Remove-Item -Recurse -Force "$ToDelete" | Out-File -Append "$LogFile"
	Write-Output " done" | Out-File -Append "$LogFile"

	# Keep only $HistoryKeep backups
	$ToKeep=(Get-Content "$HistoryFile" -Last $HistoryKeep)
	Write-Output $ToKeep > $HistoryFile
} else {
	Write-Output "Backup history: NOT enough backups in the history yet" | Out-File -Append "$LogFile"
}

Import-Module Hyper-V
$VMs = Get-VM

Write-Output "Starting at $(Get-Date -format "HH:mm:ss")"
Write-Output "Starting at $(Get-Date -format "HH:mm:ss")" | Out-File -Append "$LogFile"
foreach($VM in $VMs)
{
	#Exporting virtual machine to a local drive
	$Begin=Get-Date
	Write-Output ("VM: "+($VM.VMName)) | Out-File -Append "$LogFile"
	Export-VM $VM -Path "$ExportPath"
	Write-Output "   m $($(Get-Date) - $Begin)" | Out-File -Append "$LogFile"
}

#Write-Output "Compressing at $(Get-Date -format "HH:mm:ss")"
#Write-Output "Compressing at $(Get-Date -format "HH:mm:ss")" | Out-File -Append "$LogFile"
#cd "$ExportPath"
#foreach($VM in $VMs)
#{
#	# Compress a virtual machine
#	$Begin=Get-Date
#	Write-Output ("VM: "+($VM.VMName)) | Out-File -Append "$LogFile"
#	#&"c:\Program Files\WinRAR\WinRAR.exe" -m1 -mt8 m (($VM.VMName)+".rar") $VM.VMName
#	&"c:\Program Files\WinRAR\RAR.exe" -m1 -mt8 m (($VM.VMName)+".rar") $VM.VMName | Out-File -Append "$LogFile"
#	Write-Output "   c $($(Get-Date) - $Begin)" | Out-File -Append "$LogFile"
#}

Write-Output "Finished at $(Get-Date -format "HH:mm:ss")"
Write-Output "Finished at $(Get-Date -format "HH:mm:ss")" | Out-File -Append "$LogFile"

# When all successful => Add to history
Write-Output "$ExportPath" >> $HistoryFile


# Deduplicate
$BaseFolder=$DedupBase + (Get-Content ($BaseFolder + '\dedup_last_full.txt') -TotalCount 1)
Write-Output "Dedup.ps1 $BaseFolder $ExportPath $DiffBackupFolder" | Out-File -Append "$LogFile"
HyperVBackupDeduper.ps1 "$BaseFolder" "$ExportPath" "$DiffBackupFolder"

Write-Output "Deduplicated at $(Get-Date -format "HH:mm:ss")"
Write-Output "Deduplicated at $(Get-Date -format "HH:mm:ss")" | Out-File -Append "$LogFile"
