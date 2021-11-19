set BloatDir=C:\Options\Intune\BloatwareRemoval
mkdir %BloatDir%
xcopy *.ps1 %BloatDir% /S /Y /C
xcopy nuget %BloatDir%\nuget /S /Y /C /I
Powershell -Ex Bypass -File "%BloatDir%\TEST - HPUninstaller.ps1"