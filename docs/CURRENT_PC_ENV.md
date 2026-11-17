compiled custom UE 5.6 (https://github.com/NvRTX/UnrealEngine/tree/NvRTX_Caustics-5.6):

```plaintext
D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6
```

art-stream-uep Plugin Dev Folder:

```plaintext
D:\PRECIOSA\PixelStreaming_Project_1\_dmx_\art-stream-uep
```

current project folder:

```plaintext
D:\PRECIOSA\PixelStreaming_Project_1\_ue_\Scene_A1
```

PS C:\Users\ndk88> $E = "D:\BESPOKE_ATRIUM\UENvRTXCaustics5.6"

PS C:\Users\ndk88> $P = "D:\PRECIOSA\PixelStreaming*Project_1_ue*\Scene_A1"

PS C:\Users\ndk88> "== OS"; (Get-CimInstance Win32_OperatingSystem) | ForEach-Object { "$($_.Caption) build $($_.BuildNumber)" }

== OS

Майкрософт Windows 11 Домашняя для одного языка build 26300

PS C:\Users\ndk88> "== CPU/RAM"; (Get-CimInstance Win32_Processor).Name; "{0:N0} GB" -f ((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB)

== CPU/RAM

12th Gen Intel(R) Core(TM) i7-12700H

64 GB

PS C:\Users\ndk88> "== GPU"; Get-CimInstance Win32_VideoController | ForEach-Object { "$($_.Name) driver $($_.DriverVersion)" }

== GPU

NVIDIA GeForce RTX 3080 Ti Laptop GPU driver 32.0.16.1742

DisplayLink USB Device driver 9.3.3324.0

DisplayLink USB Device driver 9.3.3324.0

PS C:\Users\ndk88> "== Disks"; Get-PhysicalDisk | Format-Table FriendlyName,MediaType,BusType,@{n='GB';e={[int]($_.Size/1GB)}} -AutoSize | Out-String

== Disks

FriendlyName MediaType BusType GB

---

Micron_2450_MTFDKBA1T0TFK SSD NVMe 954

Samsung SSD 970 EVO Plus 1TB SSD NVMe 932

PS C:\Users\ndk88> "== Disk of D:"; Get-Partition -DriveLetter D | Get-Disk | ForEach-Object { $\_.FriendlyName }

== Disk of D:

Samsung SSD 970 EVO Plus 1TB

PS C:\Users\ndk88> "== LongPaths"; (Get-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem).LongPathsEnabled

== LongPaths

1

PS C:\Users\ndk88> "== Engine Build.version"; Get-Content "$E\Engine\Build\Build.version"

== Engine Build.version

{

"MajorVersion": 5,

"MinorVersion": 6,

"PatchVersion": 1,

"Changelist": 0,

"CompatibleChangelist": 43139311,

"IsLicenseeVersion": 0,

"IsPromotedBuild": 0,

"BranchName": "UE5"

}

PS C:\Users\ndk88> "== Engine git"; git -C $E rev-parse HEAD; git -C $E branch --show-current

== Engine git

fatal: not a git repository (or any of the parent directories): .git

fatal: not a git repository (or any of the parent directories): .git

PS C:\Users\ndk88> "== InstalledBuild marker"; Test-Path "$E\Engine\Build\InstalledBuild.txt"

== InstalledBuild marker

False

PS C:\Users\ndk88> "== Engine binaries"; "UnrealEditor: $(Test-Path "$E\Engine\Binaries\Win64\UnrealEditor.exe")"; "UnrealInsights: $(Test-Path "$E\Engine\Binaries\Win64\UnrealInsights.exe")"; "RunUAT: $(Test-Path "$E\Engine\Build\BatchFiles\RunUAT.bat")"

== Engine binaries

UnrealEditor: True

UnrealInsights: False

RunUAT: True

PS C:\Users\ndk88> "== Registered engine builds"; Get-ItemProperty "HKCU:\Software\Epic Games\Unreal Engine\Builds" -ErrorAction SilentlyContinue | Format-List | Out-String

== Registered engine builds

{CB5F2325-467F-DCDB-830C-16B1F05EDBE4} : D:/BESPOKE_ATRIUM/UENvRTXCaustics5.6

PSPath : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine\Builds

PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_CURRENT_USER\Software\Epic Games\Unreal Engine

PSChildName : Builds

PSDrive : HKCU

PSProvider : Microsoft.PowerShell.Core\Registry

PS C:\Users\ndk88> "== Scene*A1"; "Source folder: $(Test-Path "$P\Source")"; Get-ChildItem $P -Filter \*.uproject | ForEach-Object { Get-Content $*.FullName }

== Scene_A1

Source folder: False

{

"FileVersion": 3,

"EngineAssociation": "{CB5F2325-467F-DCDB-830C-16B1F05EDBE4}",

"Category": "",

"Description": "",

"Plugins": [

{

"Name": "DatasmithImporter",

"Enabled": true

},

{

"Name": "InterchangeEditor",

"Enabled": true,

"SupportedTargetPlatforms": [

"Win64",

"Linux",

"Mac"

]

},

{

"Name": "DatasmithCADImporter",

"Enabled": true,

"SupportedTargetPlatforms": [

"Win64",

"Linux"

]

},

{

"Name": "DatasmithC4DImporter",

"Enabled": true,

"SupportedTargetPlatforms": [

"Win64",

"Mac"

]

},

{

"Name": "AxFImporter",

"Enabled": true,

"SupportedTargetPlatforms": [

"Win64"

]

},

{

"Name": "DataPrepEditor",

"Enabled": true

},

{

"Name": "VariantManager",

"Enabled": true

},

{

"Name": "SunPosition",

"Enabled": true

},

{

"Name": "HDRIBackdrop",

"Enabled": true

},

{

"Name": "PythonScriptPlugin",

"Enabled": true

},

{

"Name": "SequencerScripting",

"Enabled": false

},

{

"Name": "ModelingToolsEditorMode",

"Enabled": true

},

{

"Name": "MovieRenderPipeline",

"Enabled": true

},

{

"Name": "MoviePipelineMaskRenderPass",

"Enabled": true

},

{

"Name": "JsonBlueprintUtilities",

"Enabled": true

},

{

"Name": "PixelStreaming2",

"Enabled": true

},

{

"Name": "DLSS",

"Enabled": true,

"MarketplaceURL": "[https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss](https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss)"

},

{

"Name": "StreamlineReflex",

"Enabled": true,

"MarketplaceURL": "[https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss](https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss)"

},

{

"Name": "DMXEngine",

"Enabled": true

},

{

"Name": "DMXProtocol",

"Enabled": true

},

{

"Name": "DMXFixtures",

"Enabled": true

},

{

"Name": "DMXControlConsole",

"Enabled": true

},

{

"Name": "NRD",

"Enabled": true

},

{

"Name": "StreamlineDLSSG",

"Enabled": true,

"MarketplaceURL": "[https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss](https://www.unrealengine.com/marketplace/en-US/product/nvidia-dlss)"

},

{

"Name": "BlueprintFileUtils",

"Enabled": true

},

{

"Name": "Bridge",

"Enabled": false

},

{

"Name": "Fab",

"Enabled": false

},

{

"Name": "MetaHumanSDK",

"Enabled": false

}

],

"TargetPlatforms": [

"Windows"

]

}

PS C:\Users\ndk88> "== Visual Studio"; & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" -all -products \* -format text -property displayName,installationVersion,installationPath

== Visual Studio

Visual Studio Locator version 3.1.7+f39851e70f [query version 3.12.2140.44225]

Copyright (C) Microsoft Corporation. All rights reserved.

PS C:\Users\ndk88> "== MSVC toolsets"; Get-ChildItem "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\VC\Tools\MSVC" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

== MSVC toolsets

C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Tools\MSVC

PS C:\Users\ndk88> "== Windows SDKs"; Get-ChildItem "${env:ProgramFiles(x86)}\Windows Kits\10\Include" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name

== Windows SDKs

10.0.19041.0

10.0.22000.0

10.0.22621.0

10.0.26100.0

PS C:\Users\ndk88> "== .NET SDKs"; dotnet --list-sdks

== .NET SDKs

9.0.314 [C:\Program Files\dotnet\sdk]

PS C:\Users\ndk88> "== Python / Git"; python --version; git --version

== Python / Git

Python 3.13.5

git version 2.50.1.windows.1
