# Update-StoreApps
Gets the latest version of installed apps from Microsoft as well as their dependencies. This is most useful in scenarios where the Windows Store is disabled, but apps still need to be updated. This script is intended to be run as Admin or System.

Arguments:

[string]SoftwareFamily (optional): The Package Family Name of the package to update. Leaving this options blank will update all packages

[string]LogLocation: Location of the log file detailing actions taken during the script.

[string]DownloadPath: Path to a staging location to store downloaded apps.

[bool]Install: $True installs/stages the packages and deletes them when finished. $False only downloads them.

[switch]Verbose: Adds some additional logging.

Inspiration and code snippets taken from the following projects. Thank you!


https://github.com/LSPosed/MagiskOnWSALocal

https://github.com/StoreDev/StoreLib

https://github.com/Andrew-J-Larson/OS-Scripts/blob/main/Windows/Wrapper-Functions/Download-AppxPackage-Function.ps1

# Future improvements

The wuidRequestXML can probably be condensed and/or moved to another file. I've left it essentially as it came from the source repo. Condensing it likely involves some additional Windows Update API work to get the installed non-leaf updates on the fly. Since this works, I'll leave it alone for now. It's part of the main script as this was written to be run as a script in SCCM. If you separate the files, it would need to be a package (which is also fine).
