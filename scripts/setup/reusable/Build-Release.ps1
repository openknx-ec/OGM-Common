# Including Dot-source helper 
$includeMyStuff = $(Join-Path $(Split-Path ($MyInvocation.MyCommand.Path)) "Helper\Build-Helper-Functions.ps1")
Write-Host "Include: $($includeMyStuff)"
. $includeMyStuff

$builds   = $args[1]  # Array of build definitions
$opknxhws = $args[2]  # Array of hardware support definitions

# Execute generic pre-build steps
foreach ($opknxhw in $opknxhws) {
  Write-Host "Adding OpenKNXHardware.ini sections to: $($opknxhw.Target_Ini) which support: '$($opknxhw.OAM_Support_ToMatch)'" -ForegroundColor Green
  $OpenKNX_Device_Ini = "lib\OGM-Common\include\OpenKNXHardware.ini"
  Copy-Sections -sourceIni $OpenKNX_Device_Ini -targetIni $opknxhw.Target_Ini -parameter $opknxhw.OAM_Support_ToMatch
  if (!$?) { exit 1 }
}

# Build firmware for each defined build
foreach ($build in $builds) {
    lib/OGM-Common/scripts/setup/reusable/Build-Step.ps1 $build.Release $build.Firmware $build.Type $build.Extra
    if (!$?) { exit 1 }
}

# Execute generic post-build steps
lib/OGM-Common/scripts/setup/reusable/Build-Release-Postprocess.ps1 $args[0]
if (!$?) { exit 1 }