param (
    [Parameter(Mandatory = $true)]
    [string]$diskInit

)

"Diskinit set to $diskinit"
"Setting Locale"
# Set Locale
& $env:SystemRoot\System32\control.exe "intl.cpl,,/f:`"UKRegion.xml`""

"Setting Timezone"
# Set Timezone
& tzutil /s "GMT Standard Time"

"Setting Language"
# Set languages/culture
Set-Culture en-GB

# Add/format any raw data disks
if ($diskInit -eq 'True') {
    "Initialising disks"
    $CandidateRawDisks = Get-Disk |  Where {$_.PartitionStyle -eq 'raw'} | Sort -Property Number
    Foreach ($RawDisk in $CandidateRawDisks) {
        $LUN = (Get-WmiObject Win32_DiskDrive | Where index -eq $RawDisk.Number | Select SCSILogicalUnit -ExpandProperty SCSILogicalUnit)
        $Disk = Initialize-Disk -PartitionStyle MBR -Number $RawDisk.Number
        $Partition = New-Partition -DiskNumber $RawDisk.Number -UseMaximumSize -AssignDriveLetter
        $Volume = Format-Volume -Partition $Partition -FileSystem NTFS -NewFileSystemLabel "DATA-$LUN" -Confirm:$false
        "$Volume"
    }
}

$InstallSCCM = "\\cent-3-001.uopnet.plymouth.ac.uk\Client\ccmsetup.bat"

Invoke-Expression $InstallSCCM