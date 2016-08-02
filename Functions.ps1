function GetWimArguments([string]$windowsVersion)
{
    $args = @()
    $args += '-wimFile "' + (Join-Path (Join-Path $sourceWimsPath $windowsVersion) "install.wim") + '"'
    $args += '-destination "' + (Join-Path $destinationPath $windowsVersion) + '"'
    $args += '-updatesPath "' + [string]::Format($wsusUpdates, $windowsVersion.Replace('.', '')) + '"'
    $args += '-driversPath "' + (Join-Path $driversPath $windowsVersion) + '"'
    
    return (" " + [String]::Join(" ", $args))
}

function GetBootWimArguments()
{
    $windowsVersion = "boot"
    $args = @()
    $args += '-wimFile "' + (Join-Path (Join-Path $sourceWimsPath $windowsVersion) "boot.wim") + '"'
    $args += '-destination "' + (Join-Path $destinationPath $windowsVersion) + '"'
    $args += '-driversPath "' + (Join-Path $driversPath $windowsVersion) + '"'
    $args += '-isBoot 1'
    
    return (" " + [String]::Join(" ", $args))
}

function CheckUpdates([string]$windowsVersion)
{
    $process = Start-Process -FilePath (Join-Path $wsusRoot "cmd\DownloadUpdates.cmd") -ArgumentList @([string]::Format("w{0}-x64 glb", $windowsVersion.Replace('.', '')), "/verify") -Wait -PassThru;
    $exitCode = $process.ExitCode
    if ($exitCode -ne 0)
    {
        throw "Error downloading updates for Windows ${windowsVersion}, exit code was ${exitCode}"
    }
}

function MountWim
{
    $sourcesInstall = (Join-Path $sourcesPath install.wim)
    foreach ($index in (Get-WindowsImage -ImagePath $sourcesInstall | % {$_.ImageIndex}))
    {
        $temp = [System.IO.Path]::GetRandomFileName()
        Write-Host "MountWim: Mounting ${sourcesInstall} index ${index} to ${temp}"
        $tempmountPath = (Join-Path $mountPath $temp)
        New-Item $tempmountPath -ItemType directory
        Mount-WindowsImage -ImagePath $sourcesInstall -Path $tempmountPath -Index $index -LogPath $dismlogPath
    }
}

function InjectAdkPackages
{
    $adk = @([Environment]::GetFolderPath('ProgramFilesX86'),
             [Environment]::GetFolderPath('ProgramFiles')) |
           % { join-path $_ "Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64" } |
           ? { test-path  $_ } |
           select-object -First 1
    $packages = join-path $adk "WinPE_OCs"
    
    foreach($cab in $adkCabs)
    {
        $cabPath = Join-Path $packages ($cab + ".cab")
        
        foreach($path in (GetMountPaths))
        {       
            Write-Host "InjectAdkPackages: Injecting ADK package ${cabPath} to ${path}"
            Add-WindowsPackage -Path $path -PackagePath $cabPath -LogPath $dismlogPath
        }
    }
}

function InjectBootFiles
{
    foreach($path in (GetMountPaths))
    {       
        Write-Host "InjectBootFiles: Injecting boot files to ${path}"
        Get-ChildItem "${bootInjectPath}" | % { 
            Copy-Item $_.FullName -destination "${path}\$_" -Recurse -Force 
        }
    }
}

function CopySourceWim
{
    #Clean sources directory first
    Write-Host "CopySourceWim: Cleaning old sources"
    Get-ChildItem $sourcesPath | Remove-Item -Force
    Write-Host "CopySourceWim: Copying source wim"
    Copy-Item $wimFile (Join-Path $sourcesPath ([System.IO.Path]::GetFileName($wimFile)))
}

function AddDrivers
{
    foreach($path in (GetMountPaths))
    {       
        Write-Host "AddDrivers: Adding drivers from ${driversPath} to ${path}"
        Add-WindowsDriver -Path $path -Driver $driversPath -LogPath $dismlogPath -Recurse -ForceUnsigned
    }
}

function ApplyUpdates
{
    foreach($path in (GetMountPaths))
    {       
        Write-Host "ApplyUpdates: Adding updates from ${updatesPath} to ${path}"
        Add-WindowsPackage -Path $path -PackagePath $updatesPath -LogPath $dismlogPath
    }
}

function ActivateWindowsFeatures
{
    foreach($path in (GetMountPaths))
    {       
        Enable-WindowsOptionalFeature -Path $path -FeatureName $features -LogPath $dismlogPath
    }
}

function CleanupMounts($discard)
{
    foreach($path in (GetMountPaths))
    {
        if ($discard)
        {
            Write-Host "CleanupMounts: Discarding WIM mount at $path"
            Dismount-WindowsImage -Path $path -Discard -ErrorAction SilentlyContinue -LogPath $dismlogPath
        }
        else
        {
            Write-Host "CleanupMounts: Saving WIM mount at $path"
            Dismount-WindowsImage -Path $path -Save -ErrorAction SilentlyContinue -LogPath $dismlogPath
        }
        
        Remove-Item $path -Force -Recurse
    }
}

function GetMountPaths
{
    return (Get-ChildItem $mountPath | ?{ $_.PSIsContainer } | % {$_.FullName})
}

function CopySources
{    
    $sourceWim = (Join-Path $sourcesPath ([System.IO.Path]::GetFileName($wimFile)))
    $destinationWim = (Join-Path $destination ([System.IO.Path]::GetFileName($wimFile)))
    Write-Host "CopySources: Copying ${sourceWim} to ${destinationWim}"
    Copy-Item $sourceWim $destinationWim
}
