function Get-UAGEdgeService {
  [CmdletBinding()]
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

    [Parameter(Mandatory=$false)]
    [Switch]$SkipCertificateCheck
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
  }

  process {
    try {
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

      $edgeService = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/config/edgeservice' -f $baseUri) @splat)

      Write-Output $edgeService
    }
    catch {
      throw $_
    }
  }

  end {}
}