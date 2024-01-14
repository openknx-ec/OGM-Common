# This script performs the build process for OpenKNX firmware.
# It uses various predefined builds and hardware support definitions.
# First, it executes generic pre-build steps by copying sections from the OpenKNXHardware.ini file into the target ini files.
# Then, for each defined build, it calls the Build-Step.ps1 file to create the firmware.
# Finally, it executes generic post-build steps by calling the Build-Release-Postprocess.ps1 file.

param (
  # Array of build definitions
  [Parameter(Mandatory=$true)]
  [array]$builds,
  
  # Array of hardware support definitions
  [Parameter(Mandatory=$false)]
  [array]$opknxhws,
  
  # Project directory
  [Parameter(Mandatory=$true)]
  [string]$projectDir,

  # Project directory
  [Parameter(Mandatory=$false)]
  [string]$CustomArgument
)


# Show OpenKNX logo
function OpenKNX_ShowLogo($AddCustomText = $null) {
  Write-Host ""
  Write-Host "Open " -NoNewline
  #Write-Host "■" -ForegroundColor Green
  Write-Host "$( [char]::ConvertFromUtf32(0x25A0) )" -ForegroundColor Green
  $unicodeString = "$( [char]::ConvertFromUtf32(0x252C) )$( [char]::ConvertFromUtf32(0x2500) )$( [char]::ConvertFromUtf32(0x2500) )$( [char]::ConvertFromUtf32(0x2500) )$( [char]::ConvertFromUtf32(0x2500) )$( [char]::ConvertFromUtf32(0x2534) ) "

  if ($AddCustomText) { 
    #Write-Host "┬────┴  $AddCustomText" -ForegroundColor Green
    Write-Host "$($unicodeString) $($AddCustomText)"  -ForegroundColor Green
  }
  else {
    #Write-Host "┬────┴" -ForegroundColor Green
    Write-Host "$($unicodeString)"  -ForegroundColor Green
  }

  #Write-Host "■" -NoNewline -ForegroundColor Green
  Write-Host "$( [char]::ConvertFromUtf32(0x25A0) )" -NoNewline -ForegroundColor Green
  Write-Host " KNX"
  Write-Host ""
}
OpenKNX_ShowLogo "Build-Release - $($CustomArgument)"

# Include helper functions
$includeMyStuff = $(Join-Path $(Split-Path ($MyInvocation.MyCommand.Path)) "Helper\Build-Helper-Functions.ps1")
Write-Host "Include: $($includeMyStuff)"
.$includeMyStuff

# includes hardware support definitions which are used to copy sections from the 
# OpenKNXHardware.ini file into the given target ini file.
$OpenKNX_Hardware_Ini= "OpenKNXHardware.ini"
$OpenKNX_Include= "lib\OGM-Common\include\"
$OpenKNX_Device_Ini= Join-Path $projectDir $(Join-Path $OpenKNX_Include $OpenKNX_Hardware_Ini)
foreach ($opknxhw in $opknxhws) {
  # Adding OpenKNXHardware.ini sections to the target ini files that support the specified OAM_Support_ToMatch.
  Write-Host "Adding OpenKNXHardware.ini sections to: $($opknxhw.Target_Ini) which support: '$($opknxhw.OAM_Support_ToMatch)'" -ForegroundColor Green
  Copy-Sections -sourceIni $OpenKNX_Device_Ini -targetIni $opknxhw.Target_Ini -parameter $opknxhw.OAM_Support_ToMatch
  if (!$?) { exit 1 }
}

# Calling Build-Release-Preprocess.ps1 for generic pre-build steps. opknxhws is optional and 
# Calling Build-Release-Postprocess.ps1 for generic post-build steps.
./lib/OGM-Common/scripts/setup/reusable/Build-Release-Preprocess.ps1 $args[0]
if (!$?) { exit 1 }


# Build firmware for each defined build
foreach ($build in $builds) {
    # Calling Build-Step.ps1 to create the firmware for each defined build.
    Write-Host "Building Rel:'$($build.Release)' Fw:'$($build.Firmware)' Type:'$($build.Type)' Extra:'$($build.Extra)' Dir:'$($projectDir)'"
    lib/OGM-Common/scripts/setup/reusable/Build-Step.ps1 -pioEnv $build.Release -firmwareName $build.Firmware -binaryFormat $build.Type -productName $build.Extra -ProjectDir $projectDir 
    #lib/OGM-Common/scripts/setup/reusable/Build-Step.ps1 $build.Release $build.Firmware $build.Type $build.Extra
    if (!$?) { exit 1 }
}

# Calling Build-Release-Postprocess.ps1 for generic post-build steps.
lib/OGM-Common/scripts/setup/reusable/Build-Release-Postprocess.ps1 $args[0]
if (!$?) { exit 1 }

OpenKNX_ShowLogo "Build-Release - $($args[0]) - Done"