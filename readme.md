# Foreman Windows WIM Scripts

These scripts help to build and maintain WIM images to complete a Windows Server install with Foreman and are designed to be used with the [ForemanWindows](https://github.com/LiamLeane/ForemanWindows) provisioning scripts.

The only wim which is absolutely required to be built is boot.wim, the ForemanWindows templates will work with a RTM install.wim for each OS too, ideally you should be injecting drivers and latest updates to keep your new machines current (and prevent a significant post-install update) though.

## What it does

Each image (Windows edition) in each WIM is mounted and then has various files injected in to it using the dism cmdlets. Finally the WIMs are dismounted & saved and finally copied elsewhere.

The image build process for creating the boot.wim is;
* Inject PE drivers. These surface the disks and NIC's required for provisioning.
* Install PE features. This includes PowerShell support.
* Inject start script.

The image build process for install.wim files is;
* Inject Windows updates.
* Inject drivers.
* (Optionally) activate Windows features

## Getting setup

These scripts are designed to be run on a Windows 2016 Server environment with [ADK 10](https://msdn.microsoft.com/en-us/windows/hardware/dn913721.aspx) installed (choco install windows-adk) with both Deployment Tools and PE selected during install. For downloading updates also download [WSUS Offline](http://download.wsusoffline.net/) and extract it somewhere on the server (choco install wsus-offline-update).

If you are using a 2016 server for your [ForemanWindows](https://github.com/LiamLeane/ForemanWindows) repo you can use the same server.

### Adding variables

Clone this repository to your server and edit the following files;

Globals.ps1:
* $wsusRoot - The path to the root of WSUS (where UpdateGenerator.exe lives). If you used choco to install it then this is "C:\ProgramData\chocolatey\lib\wsus-offline-update\tools\wsusoffline"
* $destinationPath - The path to put the output wim's, this is probably the "Windows" folder you created as part of your [ForemanWindows](https://github.com/LiamLeane/ForemanWindows) repo.
 
bootInject\Foreman\StartInstall.ps1:
* $foremanHost - The FQDN (or IP) of your Foreman host (yes this is cludgy, there is no sensible way to pass a boot param through to PE)
 
### Adding drivers

Drop OS specific drivers in to ForemanWimScripts\Drivers\\*version*, the search is recursive so subfolders are ok.

If you get a bluescreen after install you probably have a driver for the wrong version of Windows in here. Yes, you have to go through those hundreds of driver folders and pull out the version specific to the right version of Windows.

Copy everything in your 10.0 driver folder to your boot folder.

TIP: VMWare drivers can be found by installing VM Tools and then looking in C:\Program Files\VMware\VMware Tools\Drivers

### Extracting files from Windows source media

Grab your iso's. For each mount it and extract sources/install.wim to ForemanWimScripts\SourceWims\\*version*.
When you get to 2016 we also want to pull out the driver store for PE;
* Open the install.wim using 7zip
* Browse down to 1\Windows\System32\DriverStore\FileRepository\
* Extract everything here to ForemanWimScripts\Drivers\boot\

### Getting boot.wim

Copy C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Windows Preinstallation Environment\amd64\en-us\winpe.wim to ForemanWimScripts\SourceWims\boot and rename it boot.wim

## Running it

To do everything just run Build-All.ps1. First run will take a great deal of time as it will be downloading & validating ~8gb of updates from Microsoft. You can also configure this to run as scheduled task / Jenkins job to update your Windows images with your patching schedule.

Optionally you can use the Build-<version>.ps1 script to run for a specific version of Windows.