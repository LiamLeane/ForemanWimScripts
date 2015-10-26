function GetSourcesPath($workingPath)
{
	return ((Join-Path $workingpath $sourcesFolderName) + "\")
}

function GetLogPath($workingPath)
{
	return (Join-Path $workingPath $dismlog)
}

function GetWorkingWimPath($workingPath, $wimPath)
{
	return (Join-Path (GetSourcesPath $workingPath) ([System.IO.Path]::GetFileName($wimPath)))
}

function GetInjectPath($workingPath)
{
	return ((Join-Path $workingPath $bootInjectFolderName) + "\")
}

function MountWim($wimPath)
{
	foreach ($index in (Get-WindowsImage -ImagePath $wimPath | % {$_.ImageIndex}))
	{
		$mountPath = (Join-Path (Join-Path $workingPath $mountFolderName) ([System.IO.Path]::GetRandomFileName()))
		New-Item $mountPath -ItemType directory
		Mount-WindowsImage -ImagePath $wimPath -Path $mountPath -Index $index -LogPath (GetLogPath $workingPath)
	}
}

function InjectAdkPackages($workingPath, $adkCabs)
{
	$adk = @([Environment]::GetFolderPath('ProgramFilesX86'),
             [Environment]::GetFolderPath('ProgramFiles')) |
           % { join-path $_ "Windows Kits\8.1\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64" } |
           ? { test-path  $_ } |
           select-object -First 1
	$packages = join-path $adk "WinPE_OCs"
	
	foreach($cab in $adkCabs)
	{
		$cabPath = Join-Path $packages ($cab + ".cab")
		
		foreach($path in (GetMountPaths $workingPath))
		{		
			Add-WindowsPackage -Path $path -PackagePath $cabPath -LogPath (GetLogPath $workingPath)
		}
	}
}

function BuildInstallWim($workingPath, $wimPath, $updatesPath, $features, $driversPath)
{
	CleanupMounts $workingPath $true
	CopySourceWim  $wimPath $workingPath
	MountWim (GetWorkingWimPath $workingPath $wimPath)
    if (![string]::IsNullOrEmpty($updatesPath))
    {
	    ApplyUpdates $workingPath $updatesPath
    }
    if (($features -ne $null) -and ($features.Count -gt 0))
    {
	    ActivateWindowsFeatures $workingPath $features
    }
    if (![string]::IsNullOrEmpty($driversPath))
    {
	    AddDrivers $workingPath $driversPath
    }	
	CleanupMounts $workingPath $false
}

function BuildBootWim($workingPath, $wimPath, $driversPath, $adkCabs)
{
	CleanupMounts $workingPath $true
	CopySourceWim  $wimPath $workingPath
	MountWim (GetWorkingWimPath $workingPath $wimPath)
	InjectAdkPackages $workingPath $adkCabs
	InjectBootFiles $workingPath	
    if (![string]::IsNullOrEmpty($driversPath))
    {
	    AddDrivers $workingPath $driversPath
    }
	CleanupMounts $workingPath $false
}

function InjectBootFiles($workingPath)
{
	foreach($path in (GetMountPaths $workingPath))
	{		
		Copy-Item ((GetInjectPath $workingPath) + "*") $path -Force -Recurse
	}
}

function CopySourceWim($wimPath, $workingPath)
{
	#Clean sources directory first
	Remove-Item ((GetSourcesPath $workingPath) + "*")
	Copy-Item $wimPath (GetSourcesPath $workingPath)
}

function AddDrivers($workingPath, $driversPath)
{
	foreach($path in (GetMountPaths $workingPath))
	{		
		Add-WindowsDriver -Path $path -Driver $driversPath -LogPath (GetLogPath $workingPath) -Recurse -ForceUnsigned
	}
}

function ApplyUpdates($workingPath, $updatesPath)
{
	foreach($path in (GetMountPaths $workingPath))
	{		
		Add-WindowsPackage -Path $path -PackagePath $updatesPath -LogPath (GetLogPath $workingPath)
	}
}

function ActivateWindowsFeatures($workingPath, $features)
{
	foreach($path in (GetMountPaths $workingPath))
	{		
		Enable-WindowsOptionalFeature -Path $path -FeatureName $features -LogPath (GetLogPath $workingPath)
	}
}

function CleanupMounts($workingPath, $discard)
{
	foreach($path in (GetMountPaths $workingPath))
	{
		if ($discard)
		{
			Dismount-WindowsImage -Path $path -Discard -ErrorAction SilentlyContinue -LogPath (GetLogPath $workingPath)
		}
		else
		{
			Dismount-WindowsImage -Path $path -Save -ErrorAction SilentlyContinue -LogPath (GetLogPath $workingPath)
		}
		
		Remove-Item $path -Force
	}
}

function GetMountPaths($workingPath)
{
	return (Get-ChildItem (Join-Path $workingPath $mountFolderName) | ?{ $_.PSIsContainer } | % {$_.FullName})
}

function CopySources($workingPath, $destination)
{
	Copy-Item ((GetSourcesPath $workingPath) + "*") $destination -Force -Recurse
}