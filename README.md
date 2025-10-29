# Update-StoreApps
Gets the latest version of installed apps from Microsoft as well as their dependencies. This is most useful in scenarios where the Windows Store is disabled, but apps still need to be updated.

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
