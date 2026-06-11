# User Profile Cleanup Script (UPCS)
# Script Language: PowerShell (can be run as a .ps1 file)
# Script Goals: Freeing up hard drive space on PCs that are utilized by multiple named Users.
# Script Actions (1): Deletes profiles from C:\Users that have not been logged on for more than 30 days.
# Script Actions (2): Deletes 'orphaned' Registry Keys of deleted profiles from HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList...
# ...to ensure Users can log back on at a later time without issues)

# (1) Excludes the profiles necessary for OS
$excludedProfiles = @("Administrator", "Default", "Public")

# 30 day selection of User Profile folders for current deployment date
$thresholdDate = (Get-Date).AddDays(-30)

# Acquires the list of User Profile folders in C:\Users that are not in the $excludedProfiles array and have not been logged on for more than 30 days.
$userFolders = Get-ChildItem "C:\Users" -Directory | Where-Object {

    -not ($excludedProfiles -contains $_.Name) -and
    $_.LastWriteTime -lt $thresholdDate
}

# Script will show which folders are being deleted in PowerShell window.
# Script will also acquire the $profilelistkey of the related user in the Registry Editor and clear it out.

foreach ($folder in $userFolders) {
    $profilePath = $folder.FullName
    Write-Host "Deleting folder: $profilePath"
    Remove-Item -Path $profilePath -Recurse -Force

    $profileListKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"
    $profileKeys = Get-ChildItem $profileListKey

    foreach ($key in $profileKeys) {
        $regProfilePath = (Get-ItemProperty $key.PSPath).ProfileImagePath
        if ($regProfilePath -eq $profilePath) {
            Write-Host "Removing registry key: $($key.Name)"
            Remove-Item -Path $key.PSPath -Force
        }
    }
}

# As another failsafe, this does a second check comparing the $profilelistkey to the names of folders in C:\Users...
# ...and marks 'orphaned' Registry Keys ($profilelists that have no matching C:\Users value) for deletion.

$existingFolders = Get-ChildItem "C:\Users" -Directory | Select-Object -ExpandProperty FullName
$profileKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

foreach ($key in $profileKeys) {
    $regProfilePath = (Get-ItemProperty $key.PSPath).ProfileImagePath
    if ($regProfilePath -and -not (Test-Path $regProfilePath)) {
        Write-Host "Removing orphaned registry key: $($key.Name)"
        Remove-Item -Path $key.PSPath -Force
    }
}

# End of Script