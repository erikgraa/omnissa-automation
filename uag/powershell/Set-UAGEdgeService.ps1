﻿  <#
    .DESCRIPTION
    Sets Horizon Connection Server URL and thumbprint for the Horizon edge service on an UAG.

    .PARAMETER Server
    Specifies the UAG server.

    .PARAMETER Port
    Specifies the UAG port.

    .PARAMETER Credential
    Specifies the credential with which to log onto the UAG.

    .PARAMETER HorizonConnectionServerUrl
    Horizon Connection Server URL.

    .PARAMETER $HorizonConnectionServerThumbprint
    Horizon Connection Server SHA256 thumbprint.

    .EXAMPLE
    Set-UAGEdgeService -ComputerName 'vdi.fqdn' -HorizonConnectionServerUrl 'https://cs.fqdn' -HorizonConnectionServerThumbprint 'sha256-thumbprint'

    .OUTPUTS
    Void.
    PSCustomObject.

    .LINK
    https://uag.fqdn:9443/swagger-ui/index.html
#>

function Set-UAGEdgeService {
  [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact = 'Medium')]
  [OutputType([Void], [PSCustomObject])]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Server,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [UInt16]$Port = 9443,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$HorizonConnectionServerUrl,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$HorizonConnectionServerThumbprint,

    [Parameter(Mandatory=$false)]
    [Switch]$SkipCertificateCheck,

    [Parameter(Mandatory=$false)]
    [Switch]$PassThru
  )

  begin {
$code= @"
        using System.Net;
        using System.Security.Cryptography.X509Certificates;
        public class TrustAllCertsPolicy : ICertificatePolicy {
            public bool CheckValidationResult(ServicePoint srvPoint, X509Certificate certificate, WebRequest request, int certificateProblem) {
                return true;
            }
        }
"@    

    if (-not($HorizonConnectionServerUrl -match 'https://')) {
      $HorizonConnectionServerUrl = ('https://{0}' -f $HorizonConnectionServerUrl)
    }

      $baseUri = ('https://{0}:{1}' -f $Server, $Port)

      $base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().Password)))

      $headers = @{
        'Content-Type' = 'application/json;charset=UTF-8'
        'Authorization' = ('Basic {0}' -f $base64)
      }

      $splat = @{}

      if ($PSBoundParameters.ContainsKey('SkipCertificateCheck')) {
          if ((Get-Command -Name Invoke-RestMethod).Parameters.ContainsKey('SkipCertificateCheck')) {
            $splat.Add('SkipCertificateCheck', $true)
          }
          else {
            Add-Type -TypeDefinition $code -Language CSharp
            [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
          }
      }

      $splat.Add('Headers', $headers)    
  }

  process {
    try {
      $edgeService = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/config/edgeservice' -f $baseUri) @splat)

      $psObject = $edgeService.edgeServiceSettingsList | ConvertTo-Json | ConvertFrom-Json 

      $psObject.proxyDestinationUrlThumbprints = $HorizonConnectionServerThumbprint
      $psObject.proxyDestinationUrl = $HorizonConnectionServerUrl

      $body = $psObject | ConvertTo-Json

      if ($PSCmdlet.ShouldProcess($HorizonConnectionServerThumbprint, $HorizonConnectionServerUri)) {
        $horizon = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/config/edgeservice' -f $baseUri) @splat)
    
        $response = (Invoke-RestMethod -Method PUT -Uri ('{0}/rest/v1/config/edgeservice/view' -f $baseUri) -Body $body @splat)
      }

      if ($PSBoundParameters.ContainsKey('PassThru')) {
        Write-Output $response
      }
    }
    catch {
      throw $_
    }
  }

  end {}
}