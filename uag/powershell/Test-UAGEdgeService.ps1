  <#
    .DESCRIPTION
    Tests Horizon Edge Services Settings on an UAG.

    .PARAMETER Server
    Specifies the UAG server.

    .PARAMETER Port
    Specifies the UAG port.

    .PARAMETER Credential
    Specifies the credential with which to log onto the UAG.

    .EXAMPLE
    Test-UAGEdgeService -ComputerName 'vdi.fqdn'

    .EXAMPLE
    Test-UAGEdgeService -ComputerName 'vdi.fqdn' -InformationLevel Detailed    

    .OUTPUTS
    Bool.
    PSCustomObject.

    .LINK
    https://uag.fqdn:9443/swagger-ui/index.html
#>

function Test-UAGEdgeService {
  [CmdletBinding()]
  [OutputType([Bool], [PSCustomObject])]
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
    [Switch]$SkipCertificateCheck,

    [Parameter(Mandatory=$false)]
    [ValidateSet('Detailed', 'Quiet')]
    [String]$Informationlevel = 'Quiet'
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

      $status = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/monitor/stats' -f $baseUri) @splat)

      $edgeServiceStatus = $status.accessPointStatusAndStats.viewEdgeServiceStats.edgeServiceStatus

      if ($Informationlevel -eq 'Quiet') {
        if ($edgeServiceStatus.status -ne 'RUNNING') {
          Write-Output $false
        }
        else {
          Write-Output $true
        }
      }
      elseif ($Informationlevel -eq 'Detailed') {
        Write-Output $edgeServiceStatus 
      }
    }
    catch {
      throw $_
    }
  }

  end {}
}