@REM set BloatDir=C:\Options\Intune\BloatwareRemoval
@REM mkdir %BloatDir%
@REM xcopy *.ps1 %BloatDir% /S /Y /C
@REM xcopy nuget %BloatDir%\nuget /S /Y /C /I
Powershell -Ex Bypass -File "%~dp0\BloatwareRemoval.ps1"