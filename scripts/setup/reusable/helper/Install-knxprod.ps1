
$Verbose=$false

function CheckOS {
  # check on which os we are running
  # After check, the Os-Informations are availibe in the PS-Env.
  if ($PSVersionTable.PSVersion.Major -lt 6.0) {
    switch ($([System.Environment]::OSVersion.Platform)) {
      'Win32NT' {
        New-Variable -Option Constant -Name IsWindows -Value $True -ErrorAction SilentlyContinue
        New-Variable -Option Constant -Name IsLinux -Value $false -ErrorAction SilentlyContinue
        New-Variable -Option Constant -Name IsMacOs -Value $false -ErrorAction SilentlyContinue
      }
    }
  }
  $script:IsLinuxEnv = (Get-Variable -Name "IsLinux" -ErrorAction Ignore) -and $IsLinux
  $script:IsMacOSEnv = (Get-Variable -Name "IsMacOS" -ErrorAction Ignore) -and $IsMacOS
  $script:IsWinEnv = !$IsLinuxEnv -and !$IsMacOSEnv

  $CurrentOS = switch($true) {
    $IsLinuxEnv { "Linux" }
    $IsMacOSEnv { "MacOS" }
    $IsWinEnv { "Windows" }
    default { "Unknown" }
  }
  if($IsWinEnv) { 
    $CurrentOS = $CurrentOS + " " + $(if ([System.Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' })
  }

    $PSVersion = "$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor).$($PSVersionTable.PSVersion.Patch)"
  if($true) { Write-Host -ForegroundColor Green "- We are on '$CurrentOS' Build Environment with PowerShell $PSVersion"  ([Char]0x221A) }
  return $CurrentOS
}

function CheckExecutable {
  param (
      [Parameter(Mandatory=$true)]
      [string]$FilePath
  )

  # Check if the file exists
  if (!(Test-Path -Path $FilePath)) {
    Write-Host "ERROR: The file '$FilePath' does not exist." -ForegroundColor Red
    exit 1
  }
  #Get the platform
  $Platform = (CheckOS)

  # Check if the file is executable
  switch ($Platform) {
      # Linux and macOS - Check if the first character of the file permissions is 'x'
      "Linux"       { return ((Invoke-Expression -Command "ls -l $FilePath")[0] -eq 'x') }
      "MacOS"       { return ((Invoke-Expression -Command "ls -l $FilePath")[3] -eq 'x') }
      
      # Windows - Check if the file has FullControl permissions
      "Windows x86" { return ((Get-Acl -Path $FilePath).AccessToString -match 'FullControl') }
      "Windows x64" { return ((Get-Acl -Path $FilePath).AccessToString -match 'FullControl') }
      default       { throw "Invalid platform specified: $Platform" }
  }
}

function Install-Binary {
  param (
      [string]$BinarySourceFile,          # Binary file to install including the source path. e.g. "C:\Path\To\OpenKNXproducer.exe"
      [string]$InstallPath = $null, # Path to the installation directory, e.g. /usr/local/bin. Default: $env:USERPROFILE\bin on Windows and /usr/local/bin on Linux and macOS
      [string]$BinaryName = $null   # Name of the binary file. e.g. "OpenKNXproducer". Default: The name of the binary file without the extension
  )
  
  # Check if the binary file exists
  if (!(Test-Path -Path $BinarySourceFile)) {
    Write-Host "ERROR: The binary file '$BinarySourceFile' does not exist." -ForegroundColor Red
    Write-Host "Please specify the path to the binary file including the file name and extension." -ForegroundColor Red
    exit 1
  } else {
    if($Verbose) { Write-Host "Binary file: $BinarySourceFile" -ForegroundColor Yellow }
  }

  if ( $null -eq $BinaryName -or $BinaryName -eq "" ) {
    if ($IsLinuxEnv -or $IsMacOSEnv) {
      # Linux and macOS - Target binary name is the same as the source binary name
      $BinaryName = (Split-Path $BinarySourceFile -Leaf).Replace('.exe', '')
      if($Verbose) { Write-Host "Binary name for MacOS/Linux: $BinaryName" -ForegroundColor Yellow }
    } else {
      # Windows - Target binary name is the same as the source binary name including the extension
      $BinaryName = (Get-Item $BinarySourceFile).Name
      if($Verbose) { Write-Host "Binary name for Windows: $BinaryName" -ForegroundColor Yellow }
    }
    
    if ( $null -eq $BinaryName -or $BinaryName -eq "") {
      #ERROR: The argument 'BinaryName' cannot be null or empty.
      Write-Host "BinaryName: $BinaryName and BinarySourceFile: $BinarySourceFile" -ForegroundColor Red
      Write-Host "ERROR: The argument 'BinaryName' cannot be null or empty." -ForegroundColor Red
      exit 1
    }
  }
  if($Verbose) { Write-Host "Binary name: $BinaryName" -ForegroundColor Yellow }

  # Set the installation path based on the platform if it is not specified
  if ($InstallPath -eq $null) {
    if ($IsLinuxEnv) {
      # Linux - Default to /usr/local/bin
      $InstallPath = "/usr/local/bin" 
    } elseif ($IsMacOSEnv) {
      # macOS - Default to /usr/local/bin
      $InstallPath = "/usr/local/bin" 
    } else { 
      # Windows - Default to the user's bin folder in the user profile directory (e.g. C:\Users\username\bin)
      $InstallPath = "$env:USERPROFILE\bin" 
    }
  }
  if($Verbose) { Write-Host "Install path: $InstallPath" -ForegroundColor Yellow }

  ## Copy the binary to the installation path
  # check here if the InstallPath exists. If not, create it.
  if (!(Test-Path -Path $InstallPath)) {
    New-Item -ItemType Directory -Force -Path $InstallPath
    #Check if the directory was created
    if (!(Test-Path -Path $InstallPath)) {
      Write-Host "ERROR: The directory '$InstallPath' could not be created." -ForegroundColor Red
      exit 1
    }
  }
  if($Verbose) { Write-Host "Install path: $InstallPath" -ForegroundColor Yellow }

  #Now copy the binary
  $TargetPathAndFile = Join-Path $InstallPath $BinaryName
  if($Verbose) { Write-Host "Target path and file: $TargetPathAndFile" -ForegroundColor Yellow }
  Copy-Item -Path $BinarySourceFile -Destination $TargetPathAndFile -Force
  #Check if the binary was copied
  if (!(Test-Path -Path $InstallPath\$BinaryName)) {
    Write-Host "ERROR: The binary '$BinaryName' could not be copied to '$InstallPath'." -ForegroundColor Red
    exit 1
  } else {
    Write-Host "The binary '$BinaryName' was successfully copied to '$InstallPath'." -ForegroundColor Green
  }

  # Set executable permissions (chmod +x) for macOS and Linux
  $destinationBinaryPath = Join-Path $InstallPath $BinaryName
  if($Verbose) { Write-Host "Destination binary path: $destinationBinaryPath" -ForegroundColor Yellow }

  # Check if the binary permissions are already set
  if ($IsLinuxEnv -or $IsMacOSEnv) {
    if($false -eq (CheckExecutable -FilePath $destinationBinaryPath)) { 

      # Set executable permissions (chmod +x) for macOS and Linux
      if($Verbose) { Write-Host "Setting executable permissions for '$destinationBinaryPath'." -ForegroundColor Yellow }
      Start-Process chmod -ArgumentList "+x", $destinationBinaryPath -NoNewWindow -Wait

      # Check if the binary permissions were set
      if($false -eq (CheckExecutable -FilePath $destinationBinaryPath)) {
        Write-Host "ERROR: The executable permissions for '$destinationBinaryPath' could not be set." -ForegroundColor Red ($([Char]0x2717))
        exit 1
      } else {
        Write-Host "The executable permissions for '$destinationBinaryPath' were successfully set." -ForegroundColor Green ($([Char]0x221A))
      }
    } else {
      if($Verbose) { Write-Host "Executable permissions for '$destinationBinaryPath' are already set." -ForegroundColor Yellow }
    }
  }
  Write-Host "Successfully installed: $destinationBinaryPath" -ForegroundColor Green ($([Char]0x221A))
}

function Get-LatestOpenKNXProducer {
  param (
        [string]$TargetFolder = $PSScriptRoot,  # Default to the script's directory
        [string]$Platform = (CheckOS)
  )

  if($Verbose) { Write-Host "Platform: $($Platform)" -ForegroundColor Yellow }
  # Define the GitHub repository and API URL
  $repoOwner = "OpenKNX"
  $repoName = "OpenKNXproducer"
  
  # Define the common part of the binary file path and name
  $binaryPath = "tools" # relative to the extracted folder
  $binaryNameSuffix = "OpenKNXproducer" # suffix of the binary file name

  $apiUrl = "https://api.github.com/repos/$repoOwner/$repoName/releases/latest"

  # Fetch the release information from GitHub
  $releaseInfo = Invoke-RestMethod -Uri $apiUrl
  
  # Get the tag name and Date of the latest release
  $latestTag = $releaseInfo.tag_name
  $PublishDate = $releaseInfo.published_at
  if($Verbose) { Write-Host "Latest release Tag: $($latestTag) ($PublishDate)" -ForegroundColor Yellow }

  # Find the asset based on the keyword
  $matchingAssets = $releaseInfo.assets | Where-Object { $_.name -like "*$repoName*" }
  if($Verbose) { Write-Host "Matching assets: $($matchingAssets)" -ForegroundColor Yellow }

  $downloadUrl = $null
  if ($matchingAssets) {
      foreach ($asset in $matchingAssets) {
          $downloadUrl = $asset.browser_download_url
          if($Verbose) { 
            Write-Host "Asset: $($asset)" -ForegroundColor Yellow 
            Write-Host "Download URL: $($downloadUrl)" -ForegroundColor Yellow
          }
      }
  }
  else {
      Write-Host "ERROR: No matching assets found for keyword '$repoName'." -ForegroundColor Red
  }

  # Construct the URL for the ZIP file of the latest release
  #$zipUrlSrc = "https://github.com/$repoOwner/$repoName/archive/$latestTag.zip"
  $zipUrl = if ($downloadUrl) { $downloadUrl } else { 
   # If no matching assets were found, exit the script with an error.
   Write-Host "No matching assets found for platform '$Platform' and keyword '$repoName'." -ForegroundColor Red
   exit 1
  }
  if($Verbose) { Write-Host "Download URL: $zipUrl" -ForegroundColor Yellow } 
  # Specify the temp directory based on the platform
  $tempDir = if ($Platform -eq "Windows x86" -or $Platform -eq "Windows x64") { $env:TEMP } else { $env:TMPDIR }
  if($Verbose) { Write-Host "Temp directory: $tempDir" -ForegroundColor Yellow }

  # Specify the download path
  $downloadPath = Join-Path $tempDir "$repoName-$latestTag.zip"
  if($Verbose) { Write-Host "Download path: $downloadPath" -ForegroundColor Yellow }

  # Specify the extraction path
  $extractPath = Join-Path $tempDir "$($repoName)-$($latestTag)"
  if($Verbose) { Write-Host "Extract path: $extractPath" -ForegroundColor Yellow }

  if($Verbose) { Write-Host "Target folder (Optional): $TargetFolder" -ForegroundColor Yellow }
  
  # Download the ZIP file
  # Check if the ZIP file was downloaded
  if (Test-Path -Path $downloadPath) {
    Write-Host "The ZIP file '$downloadPath' already exists." -ForegroundColor Yellow
  } else {
    Write-Host "Downloading the ZIP file '$downloadPath'." -ForegroundColor Yellow
    Invoke-WebRequest -Uri $zipUrl -OutFile $downloadPath
  }
  #Check if the ZIP file was downloaded
  if (!(Test-Path -Path $downloadPath)) {
    Write-Host "ERROR: The ZIP file '$downloadPath' could not be downloaded." -ForegroundColor Red
    exit 1
  } else {
    if($Verbose) {
      Write-Host "The ZIP file '$downloadPath' was successfully downloaded." -ForegroundColor Green
    }
  }

  # Extract the contents of the ZIP file
  Expand-Archive -Path $downloadPath -DestinationPath $extractPath -Force
  #check if the ZIP file was extracted
  if (!(Test-Path -Path $extractPath)) {
    Write-Host "ERROR: The ZIP file '$downloadPath' could not be extracted." -ForegroundColor Red
    exit 1
  } else {
    if($Verbose) {
      Write-Host "The ZIP file '$downloadPath' was successfully extracted." -ForegroundColor Green
    }
  }

  # Define the binary file based on the specified platform
  $binarySourceFile = switch ($Platform) {
      "Linux"       { "$binaryNameSuffix-linux64.exe" }
      "MacOS"       { "$binaryNameSuffix-osx64.exe" }
      "Windows x86" { "$binaryNameSuffix-x86.exe" }
      "Windows x64" { "$binaryNameSuffix-x64.exe" }
      default       { throw "Invalid platform specified: $Platform" }
  }
  if($Verbose) { Write-Host "Binary file: $binarySourceFile" -ForegroundColor Yellow }
 
  # Specify the source path of the binary
  $sourceBinaryPath = Join-Path $extractPath (Join-Path $binaryPath $binarySourceFile)
  if($Verbose) { Write-Host "Source binary path: $sourceBinaryPath" -ForegroundColor Yellow }
  

  # Specify the target path for the binary
  $targetBinaryPath = Join-Path $TargetFolder $binarySourceFile
  if($Verbose) { Write-Host "Target binary path: $targetBinaryPath" -ForegroundColor Yellow }

  # Set executable permissions (chmod +x) for macOS and Linux
  Install-Binary -BinarySourceFile $sourceBinaryPath -InstallPath $TargetFolder
  
  # Clean up: Remove the downloaded ZIP file and extracted folder
  #Remove-Item -Path $downloadPath -Recurse -Force

  # Display a message
  Write-Host "Downloaded and extracted $repoName latest release (Tag: $latestTag) to $TargetFolder"
}

# Example usage:
# Get-LatestOpenKNXProducer -TargetFolder "C:\Path\To\Target" -Platform "x64"
Get-LatestOpenKNXProducer
#CheckOS