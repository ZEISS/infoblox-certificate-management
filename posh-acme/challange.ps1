[CmdletBinding()]
param (
    #[Parameter(Mandatory=$true)]
    [string]$dnsName = "test.cloud.zeiss.com",
    #[Parameter(Mandatory=$true)]
    [string]$esbSubscriptionKey = "",
    #[Parameter(Mandatory=$true)]
    [string]$infobloxUser = "",
    #[Parameter(Mandatory=$true)]
    [securestring]$infobloxPassword = ""
)
$acmeContact = "user@zeiss.com"
$acmeDirectory = "LE_STAGE"

$env:POSHACME_PLUGINS = './posh-acme/plugin'
Install-Module Posh-ACME -Force
Import-Module Posh-ACME -Force


Set-PAServer -DirectoryUrl $AcmeDirectory

$account = Get-PAAccount

if($null -eq $account){
    $account = New-PAAccount -Contact $acmeContact -AcceptTOS
} elseif($account.contact -ne "mailto:$acmeContact"){
    Set-PAAccount -ID $account.id -Contact $acmeContact
}

$base64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${infobloxUser}:${infobloxPassword}"))

# Request certificate 
$paPluginArgs = @{
    EsbSubscriptionKey = $esbSubscriptionKey
    BasicAuthBase64 = "Basic $base64"
}

$certInfo = New-PACertificate -Domain $dnsName -Plugin EsbPlugin -PluginArgs $paPluginArgs -DnsAlias "" -Force -Verbose