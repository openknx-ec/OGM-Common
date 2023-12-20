function ParseIniFile ($filePath) {
  $iniContent = Get-Content $filePath
  $parsedData = @{}
  $currentSection = ""
  $currentKey = ""
  $currentValue = ""

  foreach ($line in $iniContent) {
      if ($line -match '^\s*\[\s*(.*?)\s*\]\s*$') {
          if ($currentKey) {
              $parsedData[$currentSection][$currentKey] = $currentValue.Trim()
              $currentKey = ""
              $currentValue = ""
          }
          $currentSection = $Matches[1]
          $parsedData[$currentSection] = @{}
      } elseif ($line -match '^\s*(.*?)\s*=\s*(.*?)\s*$') {
          if ($currentKey) {
              $parsedData[$currentSection][$currentKey] = $currentValue.Trim()
          }
          $currentKey = $Matches[1]
          $currentValue = $Matches[2]
      } else {
          $currentValue += " " + $line.Trim()
      }
  }

  if ($currentKey) {
      $parsedData[$currentSection][$currentKey] = $currentValue.Trim()
  }

  return $parsedData
}
# Function to write data to an INI file
function Write-IniFileParams ($sectionKey, $section, $filePath, $Overwrite = $false) {
  # Read the existing content of the INI file
  $existingContent = Get-Content $filePath -Raw
  $sectionHeader = "[$sectionKey]"

  # Check if the section already exists in the file
  $sectionRegex = [regex]::Escape($sectionHeader)
  if ($existingContent -match "(?s)$sectionRegex.*?(\r?\n\[\w+|\z)") {
      # If the section exists, replace its content
      if($Overwrite) {
        Write-Host "Section '$($sectionKey) 'already exists, overwriting" -ForegroundColor Yellow
        $existingContent = $existingContent -replace "(?s)\r?\n$sectionRegex.*?(\r?\n\[\w+|\z)", ""
      } else {
        Write-Host "Section already exists, skipping" -ForegroundColor Yellow
        return
      }
  } else {
      Write-Host "Section does not exists. Adding the new section." -ForegroundColor Yellow
      # If the section does not exist, append it to the end of the file
      # Create the section header
      $iniContent = "`r`n$($sectionHeader) ; Automatic generated section"

      # Add key-value pairs to the section
      foreach ($key in $section.Keys) {
          $value = $($section[$key])
          $iniContent += "`r`n$key = $value"
          #Write-Host "Section: $($section)"
          #Write-Host "Key: $($key) and Value: $($value)"
      }

      # Append the modified content to the end of the existing content
      $resultContent = $existingContent + $iniContent

      # Write the result back to the file
      $resultContent | Out-File $filePath
      }
}
# Function to copy sections based on key-value comparison
function Copy-Sections($sourceIni, $targetIni, $parameter) {
  $sourceData = ParseIniFile $sourceIni
  $targetData = ParseIniFile $targetIni

  foreach ($sectionKey in $sourceData.Keys) {
    $section = $sourceData[$sectionKey]
    $supportedTargetOam = $section["target_oam"]

   
    if ($supportedTargetOam) {
      $supportedTargetOamList = $supportedTargetOam -split ',\s*'
      if ($supportedTargetOamList -contains $parameter) {
        # Exclude supported_target_oam from the copied section
        $section.Remove("target_oam")
        $targetData[$sectionKey] = $section
        Write-Host "Processing device env: $($sectionKey) which does support: '$($parameter)'" -ForegroundColor Green
        Write-Host "Found matching device env: $($sectionKey)" -ForegroundColor Yellow
        Write-IniFileParams $sectionKey $section $targetIni
      } 
    } else {
      Write-Host "Processing device env: $($sectionKey) does not support target oam: '$($parameter)'" -ForegroundColor Gray
    }
  }

  Write-Host "  Done!."
}

## Example usage
# $OpenKNX_Device_Ini = "lib\OGM-Common\include\OpenKNXHardware.ini"
# $Target_Ini = "platformio.custom.ini"
# $OAM_Support_ToMatch = "oam_logicmodule"

# Copy-Sections -sourceIni $OpenKNX_Device_Ini -targetIni $Target_Ini -parameter $OAM_Support_ToMatch