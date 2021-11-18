# Created 11/15/2021 by Steve Oliver
# Removal of HP Software we don't want

# edit - 11/16/21
# add Mail and Calendar (microsoft.windowscommunicationsapps)
# fix issue with nuget installation
# added detection method if failure occurs

Set-Location ${PSScriptRoot}
$time = get-date -Format "yyyy-MM-dd-HH-mm"
$LogPath = "$env:WinDir\Logs\Intune\BloatwareUninstaller"
Start-Transcript -Path "$LogPath\Transcript_$time.log"

Write-Host "`n`nAdding Nuget if not installed"
$nuget = "$env:ProgramFiles\PackageManagement\ProviderAssemblies\nuget"
If (!(Test-Path "$nuget")) {
    Copy .\nuget $nuget -Recurse
}
Write-Host "Nuget detected?"
Write-Host (Test-Path $nuget)

Write-Host "`n`nGathering installed non-store applications"
try {
    $ProgList = Get-CIMInstance -class Win32_Product
} catch {
    $ProgList = Get-WMIobject -class Win32_Product
}

Write-Host "Gathering installed Store applications"
$StoreAppList = Get-AppxProvisionedPackage -Online

$UnwantedList = @(
    "HP Sure Sense Installer",
    "HP Client Security Manager",
    "HP Security Update Service",
    "HP Sure Click"
)

$UnwantedStoreApps = @(
    "AD2F1837.HPSupportAssistant", # prompts to save preferences and opens Edge.  Not sure what will happen when this applies during setup.
    "AD2F1837.HPEasyClean",
    "AD2F1837.HPWorkWell",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.SkypeApp",
    "Microsoft.Office.OneNote",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "Microsoft.MicrosoftOfficeHub",
    "microsoft.windowscommunicationsapps",
    "Tile.TileWindowsApplication"
)

$InstalledList = @()
Write-Host "`n`nNon-Store Applications uninstall section:"
Foreach ($app in $UnwantedList) {
    If ($app -in $ProgList.Name) {
        Write-Host "`"$app`" was found to be installed.  Attempting to uninstall."
        $InstalledList = $InstalledList + $app
        Uninstall-Package -Name $app -Force -ErrorAction SilentlyContinue > $LogPath\NonStoreApp_$app-Uninstall.log
    } else {
        Write-Host "`"$app`" is not currently installed.  Moving on."
    }
}

Write-Host "`n`nStore Apps section:"
$InstalledStoreApps = @()
Foreach ($StoreApp in $UnwantedStoreApps) {
    # Remove Store app for all users
    # this first command seemed to fail, probably because it had not yet been installed for anyone yet.  Maybe the 2nd command is all that's needed?
    # Get-AppxPackage -AllUsers | Where {$_.Name -match $StoreApp} | Remove-AppxPackage -AllUsers
    # Remove Store app for all future users
    If ($StoreApp -in $StoreAppList.DisplayName) {
        Write-Host "$StoreApp was found to be installed.  Attempting to uninstall."
        $InstalledStoreApps = $InstalledStoreApps + $StoreApp
        Get-AppxProvisionedPackage -Online | ? {$_.DisplayName -match $StoreApp} | Remove-AppxProvisionedPackage -Online -LogPath $LogPath\StoreApp_$StoreApp_$time.log > $null
    } else {
        Write-Host "$StoreApp is not installed.  Moving on."
    }
    # Get-AppxProvisionedPackage -Online | Where {$_.DisplayName -match $StoreApp} | Remove-AppxProvisionedPackage -Online -AllUsers
}

Write-Host "`n`nRefreshing installed applications list"
try {
    $NewProgList = Get-CIMInstance -class Win32_Product
} catch {
    $NewProgList = Get-WMIobject -class Win32_Product
}

Write-Host "Refreshing Store apps list"
$NewStoreAppList = Get-AppxProvisionedPackage -Online

Write-Host "`n`nVerification Section:"
Write-Host "Non-Store app verification:"
If ($InstalledList -gt 0) {
    Foreach ($app in $InstalledList) {
        If ($app -in $NewProgList.Name) {
            Write-Host "`"$app`" was found to still be installed"
            $failure = 1
        } else {
            Write-Host "`"$app`" was successfully removed"
        }
    }
} else {
    Write-Host "No non-store apps were installed that need to be verified."
}

Write-Host "`nStore App verification:"
If ($InstalledStoreApps -gt 0) {
    Foreach ($StoreApp in $InstalledStoreApps) {
        If ($StoreApp -in $NewStoreAppList.DisplayName) {
            Write-Host "`"$StoreApp`" was found to still be installed."
            $failure = 1
        } else {
            Write-Host "`"$StoreApp`" was successfully removed"
        }
    }
} else {
    Write-Host "No store apps were installed that need to be verified."
}

If ($Failure -eq 1) {
    Write-Host "Failure to uninstall one or more apps detected.  Creating Failure detection file."
    New-Item -ItemType File -Path "$LogPath\Failure.log" -Force > $null
    Stop-Transcript
    Write-Output $False
    Exit 1
}

Stop-Transcript
Write-Output $True
Exit 0




<#
$Uninstall = get-itemproperty HKLM:Software\Microsoft\Windows\CurrentVersion\Uninstall\*
$Uninstall32 = get-itemproperty HKLM:Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*

# if UninstallString matches this, it's an MSI
$guidmatchstring = "(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}"

foreach ($item in $Uninstall) {
    If ($($item.DisplayName) -in $UnwantedList) {
        # if it has $Uninstall.QuietUninstallString, they seem to have /SILENT in them and all are EXEs
        If ($item.UninstallString -match $guidmatchstring) {
            $UninstallPath = $item.UninstallString -replace "/I","/X"
            $UninstallPath = $UninstallPath + " /qn /norestart"
        }
    }
}
#>
<#
Stuff for the future

 function parseUninstallString( [string]$proguninstallstring, [string]$uninstallstringmatchstring ) {
    # parseUninstallString takes the uninstallstring, and the uninstallstringmatchstring then
    # then returns the path and the arguments seperately in a form that Start-Process can use
        # Reset $uninstallarguments and $matches each loop iteration
        $uninstallpath = $proguninstallstring
        $uninstallarguments = $null
        $matches = $null

        $uninstallpath = $uninstallpath -replace "^cmd \/c", ""
        $uninstallpath = $uninstallpath -replace "^RunDll32.*LaunchSetup\ ", ""
        $uninstallpath = $uninstallpath.TrimStart(" ").TrimEnd(" ")
        $uninstallpath -match $uninstallstringmatchstring | Out-Null

        if ( $matches ) { # only matches if arguments exist
            $uninstallpath = $matches[1]
            $uninstallarguments = $matches[2]
        }

        #remove spaces, single and double quotes from the process path and aurgument list at the begining and end of each
        $uninstallpath = $uninstallpath.TrimStart("`"`' " ).TrimEnd("`"`' " )
        if ( $uninstallarguments -ne $null ) {
            $uninstallarguments = $uninstallarguments.TrimStart("`"`' " ).TrimEnd("`"`' " )
        }

        $uninstallpath = "`""+$uninstallpath+"`""
        $returned = @($uninstallpath,$uninstallarguments)
        return $returned

    } # end function parseUninstallString( $proguninstallstring, $uninstallstringmatchstring)





    function doOptionsWin10RecommendedDownloadsOff( ) {
        Write-Host "" | Out-Default
        Write-Verbose -Verbose "Setting Registry Keys to turn off `"recommended`" downloads (ads) of applications that would have automaticaly downloaded."
        # Prevent "recommended" downloads of apps automatically by the OS
        Write-Host "Setting HKLM\Software\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures to 1 (REG_DWORD)" | Out-Default
        & reg add "HKLM\Software\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /d 1 /t REG_DWORD /f 2>&1 | Out-Default
        Write-Host "Setting HKCU\Software\Policies\Microsoft\Windows\CloudContent\DisableWindowsConsumerFeatures to 1 (REG_DWORD)" | Out-Default
        & reg add "HKCU\Software\Policies\Microsoft\Windows\CloudContent" /v DisableWindowsConsumerFeatures /d 1 /t REG_DWORD /f 2>&1 | Out-Default
        Write-Host "Setting HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\ContentDeliveryAllowed to 0 (REG_DWORD)" | Out-Default
        & reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v ContentDeliveryAllowed /d 0 /t REG_DWORD /f  2>&1 | Out-Default
        Write-Host "Setting HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SilentInstalledAppsEnabled to 0 (REG_DWORD)" | Out-Default
        & reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SilentInstalledAppsEnabled /d 0 /t REG_DWORD /f  2>&1 | Out-Default
        Write-Host "Setting HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\SystemPaneSuggestionsEnabled to 0 (REG_DWORD)" | Out-Default
        & reg add "HKCU\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager\" /v SystemPaneSuggestionsEnabled /d 0 /t REG_DWORD /f  2>&1 | Out-Default
    }



    function doOptionsWin10StartMenuAds( ) {
        Write-Host "" | Out-Default
        Write-Verbose -Verbose "Exporting Start Menu tiles layout."

        try {
            Export-StartLayout "$($Script:dest)\exported-startlayout.xml"
        } catch {
            Write-Warning "Export-StartLayout did not complete. Try updating Windows and rebooting first, then re-running this with this option enabled again."
        }


        Write-Host "" | Out-Default
        Write-Verbose -Verbose "Removing Advertisements (Windows ContentDeliveryManager) Ads from exported Layout for new users."
        $startlayout = Get-Content "$($Script:dest)\exported-startlayout.xml" -Raw
        $noCDMadsstartlayout = $($startlayout -Replace ".*<start:SecondaryTile\ AppUserModelID=`"Microsoft\.Windows\.ContentDeliveryManager.*\ />.*\n.*?")            
        Write-Host "" | Out-Default
        Write-Verbose -Verbose "Setting default Start Menu tiles layout for new users only (doesn't apply to any current user or existing account)."
        Set-Content -Path "$($Script:dest)\exported-startlayout-noCDMads.xml" -Value $noCDMadsstartlayout
        Import-StartLayout -LayoutPath "$($Script:dest)\exported-startlayout-noCDMads.xml" -MountPath "$($env:SystemDrive)\"

        Remove-Item "$($Script:dest)\exported-startlayout.xml" -Force -ErrorAction SilentlyContinue
        Remove-Item "$($Script:dest)\exported-startlayout-noCDMads.xml" -Force -ErrorAction SilentlyContinue
    }
#>