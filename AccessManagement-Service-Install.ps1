#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Installs the Tridion Access Management Service as a Windows Service.
.DESCRIPTION
.EXAMPLE1
   .\AccessManagement-Service-Install.ps1 -TCMInstallerPath D:\_Install\TridionSites95 -InstallationDir "D:\TXS2020-DEMO\Access Management" -CertThumbprint "4af0b42497e5988df2235b65ede11742e503fecd"

.EXAMPLE2   
   .\AccessManagement-Service-Install.ps1 -TCMInstallerPath D:\_Install\TridionSites95 -InstallationDir "D:\TXS2020-DEMO\Access Management" -CertThumbprint "4af0b42497e5988df2235b65ede11742e503fecd" -SkipDBCreation
   
.NOTES
 Author: Velmurugan Arjunan
#>

[CmdletBinding()]
param(
[Parameter(Mandatory=$true,HelpMessage="SDL Tridion Sites Installer Path.")]
[string]$TCMInstallerPath,
[Parameter(Mandatory=$true,HelpMessage="Directory where the service will be installed.")]
[string]$InstallationDir = (Join-Path $env:ProgramFiles 'SDL\Tridion\Add-on Service'),
[Parameter(Mandatory=$true,HelpMessage="Certificate Thumprint to Export.")]
[string]$CertThumbprint,
[Parameter(HelpMessage="Skip creating the access management database")]
[switch]$SkipDBCreation
)

[string]$InstallScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$currentFolder = Get-Location
$scriptPath = Split-Path -parent $PSCommandPath

# Removes service from windows services and removes service folder
function cleanupService {
    param (
        [string]$servicePath = $( throw "Service path should be specified" )
    )

    if (Test-Path $servicePath) {
        $uninstallScript = $servicePath + "\uninstallService.ps1"
        if (Test-Path $uninstallScript) {
            Write-Host "Removing existing service..." -ForegroundColor Green
            . $uninstallScript
            Write-Host "Removing existing service finished" -ForegroundColor Green
        }
        Write-Host "Removing service folder..." -ForegroundColor Green
        Remove-Item -Path $servicePath -Recurse -Force -ErrorAction SilentlyContinue
        if (Test-Path $servicePath) {
            $Host.UI.WriteErrorLine("ERROR: Not able to remove folder '" + $servicePath + "'")
        } else {
            Write-Host "Service folder removed" -ForegroundColor Green
        }
    } else {
        Write-Host "No existing service found"
    }
}

# Copies service from source to destination target folder
function copyService {
    param (
        [string]$fromPath,
        [string]$toPath
    )
    
    Write-Host "Copying from service folder '$fromPath'" -ForegroundColor Green
    if (-not(Test-Path $fromPath -PathType Container)) {
        $Host.UI.WriteErrorLine("ERROR: Folder '" + $fromPath + "' doesn't exist")
        Exit
    }
    
    Write-Host "Copying service to target folder '$toPath'" -ForegroundColor Green
    if (-not(Test-Path -Path $toPath -PathType Container)) {
        New-Item -Path $toPath -ItemType directory | Out-Null
    }
    Copy-Item -Recurse -Force -Path "$fromPath\*" -Destination $toPath
    Write-Host "Copying finished" -ForegroundColor Green
}

# Installs role as windows service.
function installWindowsService {
    param (
        [string]$servicePath
    )
    $installServiceScript = $servicePath + "\installService.ps1"
    if (Test-Path $installServiceScript -PathType Leaf) {
        $parameters = ""
        Write-Host "Starting windows service installation..." -ForegroundColor Green

        & $installServiceScript $parameters
        Write-Host "Installation of windows service finished." -ForegroundColor Green
    }
}

function IsDatabaseAvailable([string]$DBName)
{
    $result = Invoke-Sqlcmd ("SELECT [name] from sys.databases WHERE [name] = '$DBNAME'") -ServerInstance $setupOptions.DB_HOST -Username $setupOptions.SA_ACCOUNT_NAME -Password $setupOptions.SA_PASSWORD
    return $result.ItemArray.Count -ge 1
    c:
}

function InstallAccessManagementDatabase([string]$sqlScripts)
{
    $amdbscript = $sqlScripts + "\Install Access Management database.ps1"
    $amdbparameters = " -DatabaseServer '" + $setupOptions.AM_DB_HOST + "'",
                      " -DatabaseName '" + $setupOptions.AM_DB_NAME + "'",
                      " -AdministratorUserName " + $setupOptions.SA_ACCOUNT_NAME,
                      " -AdministratorUserPassword " + $setupOptions.SA_PASSWORD,
					  " --DatabaseUsers @(@{UserName='" + $setupOptions.AM_DB_USER_NAME +"';UserPassword='" + $setupOptions.AM_DB_PASSWORD + "'})",
                      " -NonInteractive"

    cd $sqlScripts

    Invoke-Expression "& `"$amdbscript`" $amdbparameters"
}

function checkInstallCompleted()
{
    if (! (Get-Command Test-NetConnection -ErrorAction SilentlyContinue)) {
        Write-Debug "This operating system cannot check for running services"
        Return
    }

	$port = $setupOptions.PORT_ACESSMANAEMENT_SERVICE
	Write-host "Installing SDL Tridion Sites Access Management $port ......." -ForegroundColor Yellow
	
    # Time limit in milliseconds
    $timeLimit = 900000
    $stopwatch = New-Object System.Diagnostics.Stopwatch
    $stopwatch.Start();
    # check port is listening
    $status = Test-NetConnection -Port $port -ComputerName localhost
    while(-not ($status.TcpTestSucceeded)) {
        Start-Sleep -Seconds 5
        $status = Test-NetConnection -Port $port -ComputerName localhost

        if ($stopwatch.ElapsedMilliseconds -gt $timeLimit) {
            $Host.UI.WriteErrorLine("ERROR: Unable to find the SDL Topology Manager during timeframe of 15m")
            $Host.UI.WriteErrorLine("Please check logs and configuration files.")
            $stopwatch.Stop()
            Return
        }
    }
    $stopwatch.Stop()
    Write-host "SDL Tridion Access Management successfully installed and listening on port $port" -ForegroundColor Green
}

try { # main try/catch block
Set-ExecutionPolicy -Scope CurrentUser Unrestricted

$InstallTimestamp = get-date -Format "yyyyMMdd_HHmmss"
filter filterOutput {"$(Get-Date -Format 'yyyyMMdd HH:mm:ss'): $_"}

Start-Transcript -Path ("$InstallScriptPath" + "\$InstallTimestamp.log") -Force -IncludeInvocationHeader

$ErrorActionPreference = "Stop"
Write-Host "Initialize ..."

# Global Variables
$setupOptions = @{}

# Load configuration options
if(Test-Path ($PSScriptRoot + "\Install-Options.ps1"))
{    Invoke-Expression ($PSScriptRoot + "\Install-Options.ps1")}
else
{
    Write-Error "Could not find Install-Options.ps1 - manually check?"
    exit
}

$installPhase = "Validation"
Write-Host "Validate folder paths..."

if (-not (Test-Path -Path $TCMInstallerPath)) {
    Throw "The SDL Tridion Sites Installer folder '$TCMInstallerPath' does not exist!"
}

$SqlScripts = $TCMInstallerPath + "\Database\mssql"
$AccessManagementScript = $TCMInstallerPath + "\Access Management"

Write-Output "Copying files to '$InstallationDir' ..."
if (!(Test-Path($InstallationDir))) {
	mkdir $InstallationDir | Out-Null
}


if(!$SkipDBCreation)
{
	Write-Host "######## STARTING Access Management Service Database" -ForegroundColor Yellow
	if(IsDatabaseAvailable($setupOptions.AM_DB_NAME))
	{
		Write-Host "Access Management Service Database" $setupOptions.AM_DB_NAME "is already configured, moving on" -ForegroundColor Green
	}
	else
	{
		InstallAccessManagementDatabase $SqlScripts
	}
}

cleanupService $InstallationDir
copyService $AccessManagementScript $InstallationDir

$serviceInstallPath = $InstallationDir
cd $serviceInstallPath

#Export PFX certificate file
New-Item -Path “.\bin\Certificates” -ItemType Directory | Out-Null
$certficateFilePath = $serviceInstallPath + "\bin\Certificates\TridionAccessManagement.pfx"
Export-PfxCertificate -Cert (Get-Item -Path Cert:\LocalMachine\My\$CertThumbprint) -FilePath $certficateFilePath -ChainOption BuildChain -NoProperties -Password (ConvertTo-SecureString -String $setupOptions.MASTER_PASSWORD -Force -AsPlainText)
Write-Host "PFX Certificate Exported in '$certficateFilePath'" -ForegroundColor Green

$filepath = "bin\appsettings.json"

Write-Output "Updating $filepath.."

if (!(Test-Path($filepath))) {
	Write-Error "File $filepath was not found."
	exit 1
}

$appsettings = Get-Content $filepath | ConvertFrom-Json

$appsettings.URLs = "http://*:"+$setupOptions.PORT_ACESSMANAEMENT_SERVICE
$appsettings.Database.ConnectionString = "Server=" + $setupOptions.AM_DB_HOST + ";Database=" + $setupOptions.AM_DB_NAME + ";User Id=" + $setupOptions.AM_DB_USER_NAME + ";Password="+ $setupOptions.AM_DB_PASSWORD

$appsettings.Certificates.Signing.Path = "Certificates/TridionAccessManagement.pfx"
$appsettings.Certificates.Signing.Password = $setupOptions.MASTER_PASSWORD

$appsettings | ConvertTo-Json -Depth 10 | Out-File $filepath

Write-Output "$filepath has been updated successfully."

installWindowsService $serviceInstallPath
checkInstallCompleted

$idpprovierfilepath = $PSScriptRoot + "\" + $setupOptions.IDP_PROVIDER_JSON
Write-Host "Loading Idp provider config '$idpprovierfilepath'" -ForegroundColor Green
$body = Get-Content $idpprovierfilepath
$header = @{
		"Accept"="application/json"
		"Content-Type"="application/json"
		#"Authorization"="Bearer XXXX"
		} 

		$setupOptions.ServiceAccountsById = $setupOptions.ACCESS_MANAGEMENT_URL + "/access-management/api/v1/ServiceAccounts/2"
		$response = Invoke-RestMethod -Uri $setupOptions.ServiceAccountsById -Method "GET" -Headers $header			
		$setupOptions.ADDON_SERVICE_OPENID_CLIENTID = $response.clientId
		Write-Host "Add-On Service ClientId:" + $response.clientId -ForegroundColor Green

		Sleep 2

		$setupOptions.generateClientSecret = $setupOptions.ACCESS_MANAGEMENT_URL + "/access-management/api/v1/ServiceAccounts/2/generateClientSecret"
		$response2 = Invoke-RestMethod -Uri $setupOptions.generateClientSecret -Method "POST" -Headers $header
		$setupOptions.ADDON_SERVICE_OPENID_CLIENTSECRET = $response2.clientSecret
		Write-Host "Add-On Service Client Secret:" + $response2.clientSecret -ForegroundColor Green
		Write-Host "Important: Please notedown this clientId and clientSecret for later to enable Access Management in CME and DXD service." -ForegroundColor Yellow
		
		$classicUIRedirectUrlBody=@"
{"clientId": "Classic_Tridion_Sites_UI","name": "Tridion Sites Classic (UI only)","redirectUrls": ["http://localhost/webui/signin-oidc"]}
"@
	
		Write "-----------------------------------"
		$classicUIRedirectUrlsettings = $classicUIRedirectUrlBody | ConvertFrom-Json
		$classicUIRedirectUrlsettings.redirectUrls[0] = $setupOptions.CM_WEB_URL + "/webui/signin-oidc"
		$classicUIRedirectUrlsettings = $classicUIRedirectUrlsettings |  ConvertTo-Json -Compress
	
		$setupOptions.ClassicUIApplication = $setupOptions.ACCESS_MANAGEMENT_URL + "/access-management/api/v1/Applications/3"
		Invoke-RestMethod -Uri $setupOptions.ClassicUIApplication -Method "PUT" -Body $classicUIRedirectUrlsettings -Headers $header
		
		Write-Host "Classic UI RedirectUrls Updated." -ForegroundColor Green
		
		Sleep 2

		$experienceSpaceUIRedirectUrlBody=@"
{"clientId": "Tridion_Sites_UI","name": "Tridion Sites Experience Space","redirectUrls": ["http://localhost/ui/signin-oidc"]}
"@
		$experienceSpaceUIRedirectUrlsettings = $experienceSpaceUIRedirectUrlBody | ConvertFrom-Json
		$experienceSpaceUIRedirectUrlsettings.redirectUrls[0] = $setupOptions.CM_WEB_URL + "/ui/signin-oidc"
		$experienceSpaceUIRedirectUrlsettings = $experienceSpaceUIRedirectUrlsettings |  ConvertTo-Json -Compress

		Write $experienceSpaceUIRedirectUrlsettings

		$setupOptions.ExperienceSpaceUIApplication = $setupOptions.ACCESS_MANAGEMENT_URL + "/access-management/api/v1/Applications/2"
		Invoke-RestMethod -Uri $setupOptions.ExperienceSpaceUIApplication -Method "PUT" -Body $experienceSpaceUIRedirectUrlsettings -Headers $header
		
		Write-Host "Experience Space RedirectUrls Updated." -ForegroundColor Green
		
		Sleep 5
		
		$setupOptions.IdentityProviders = $setupOptions.ACCESS_MANAGEMENT_URL + "/access-management/api/v1/IdentityProviders"
		$IdentityProviderResponse = Invoke-RestMethod -Uri $setupOptions.IdentityProviders -Method "POST" -Body $body -Headers $header
		
		Write-Host $IdentityProviderResponse
		
		Write-Host "Identity Provider created." -ForegroundColor Green
		
		Write-Host "Installation finished successfully."

} catch {

Write-host "Installation aborted during $installPhase!"
Write-Host "last error: "
$error[0]

} finally {
    Stop-Transcript  -ErrorAction SilentlyContinue
    Set-Location $currentFolder
}