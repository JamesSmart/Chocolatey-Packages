# Parse input argument string into a hashtable
# Format: Features:WebTools,Win8SDK ProductKey:AB-D1
function Parse-Parameters ($s)
{
    $MATCH_PATTERN = '([a-zA-Z]+):([a-zA-Z0-9-_,]+)'
    $NAME_INDEX = 1
    $VALUE_INDEX = 2

    $parameters = @{ }
    $results = $s | Select-String $MATCH_PATTERN -AllMatches
    foreach ($match in $results.matches)
    {
        $parameters.Add($match.Groups[$NAME_INDEX].Value.Trim(), $match.Groups[$VALUE_INDEX].Value.Trim())
    }

    return $parameters
}

# Turns on features in the customizations file
function Update-Admin-File($parameters, $adminFile)
{
    $s = $parameters['Features']
    if (!$s) { return }

    $features = $s.Split(',')
    [xml]$xml = Get-Content $adminFile

    foreach ($feature in $features)
    {
        $node = $xml.DocumentElement.SelectableItemCustomizations.ChildNodes | ? {$_.Id -eq "$feature"}
        if ($node -ne $null)
        {
            $node.Selected = "yes"
        }
    }
    $xml.Save($adminFile)
}

function Generate-Install-Arguments-String($parameters, $adminFile)
{
    $s = "/Passive /NoRestart /Log $env:temp\vs.log"

    $f = $parameters['Features']
    if ($f)
    {
        $s = $s + " /AdminFile $adminFile"
    }

    $pk = $parameters['ProductKey']
    if ($pk)
    {
        $s = $s + " /ProductKey $pk"
    }

    return $s
}

function Install-VS {
<#
.SYNOPSIS
Installs Visual Studio

.DESCRIPTION
Installs Visual Studio with ability to specify additional features and supply product key.

.PARAMETER PackageName
The name of the VisualStudio package - this is arbitrary.
It's recommended you call it the same as your nuget package id.

.PARAMETER Url
This is the url to download the VS web installer.

.EXAMPLE
Install-VS 'VisualStudioCommunity2015' 'http://download.microsoft.com/download/zzz/vs_community.exe'

.OUTPUTS
None

.NOTES
This helper reduces the number of lines one would have to write to download and install Visual Studio.
This method has no error handling built into it.

.LINK
Install-ChocolateyPackage
#>
param(
  [string] $packageName,
  [string] $url
)
    Write-Debug "Running 'Install-VS' for $packageName with url:`'$url`'";

    $installerType = 'exe'
    $validExitCodes = @(
        0, # success
        3010, # success, restart required
        2147781575, # pending restart required
        -2147185721 # pending restart required
    )

    $packageParameters = Parse-Parameters $env:chocolateyPackageParameters

    $adminFile = (Join-Path $PSScriptRoot 'AdminDeployment.xml')
    Update-Admin-File $packageParameters $adminFile

    $silentArgs = Generate-Install-Arguments-String $packageParameters $adminFile

    Write-Output "Install-ChocolateyPackage $packageName $installerType $silentArgs $url -validExitCodes $validExitCodes"
    Install-ChocolateyPackage $packageName $installerType $silentArgs $url -validExitCodes $validExitCodes
}

function Uninstall-VS {
<#
.SYNOPSIS
Uninstalls Visual Studio

.DESCRIPTION
Uninstalls Visual Studio.

.PARAMETER PackageName
The name of the VisualStudio package.

.PARAMETER ApplicationName
The VisualStudio app name - i.e. 'Microsoft Visual Studio Community 2015'.

.PARAMETER UninstallerName
This name of the installer executable - i.e. 'vs_community.exe'.

.EXAMPLE
Uninstall-VS 'VisualStudioCommunity2015' 'Microsoft Visual Studio Community 2015' 'vs_community.exe'

.OUTPUTS
None

.NOTES
This helper reduces the number of lines one would have to write to uninstall Visual Studio.
This method has no error handling built into it.

.LINK
Uninstall-ChocolateyPackage
#>
param(
  [string] $packageName,
  [string] $applicationName,
  [string] $uninstallerName
)
    Write-Debug "Running 'Uninstall-VS' for $packageName with url:`'$url`'";

    $installerType = 'exe'
    $silentArgs = '/Uninstall /force /Passive /NoRestart'

    $app = Get-WmiObject -Class Win32_Product | Where-Object { $_.Name -like "$applicationName*"} | Sort-Object { $_.Name } | Select-Object -First 1
    if ($app -ne $null)
    {
        $uninstaller = Get-Childitem "$env:ProgramData\Package Cache\" -Recurse -Filter $uninstallerName | ? { $_.VersionInfo.ProductVersion.StartsWith($app.Version)}
        if ($uninstaller -ne $null)
        {
            Uninstall-ChocolateyPackage $packageName $installerType $silentArgs $uninstaller.FullName
        }
    }
}

Export-ModuleMember Install-VS, Uninstall-VS