function Set-UnifiedAccessGatewayHorizonConnectionServer {
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

  begin {}

  process {
    $baseUri = ('https://{0}:{1}' -f $Server, $Port)

    $proxyDestinationUrlThumbprints = 'sha256=newThumbprint'

    $base64 = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f $credential.GetNetworkCredential().UserName, $credential.GetNetworkCredential().Password)))

    $headers = @{
      'Content-Type' = 'application/json;charset=UTF-8'
      'Authorization' = ('Basic {0}' -f $base64)
    }

    $splat = @{}

    if ($PSBoundParameters.ContainsKey('SkipCertificateCheck')) {
        $splat.Add('SkipCertificateCheck', $true)
    }

    $splat.Add('Headers', $headers)

    $horizon = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/config/edgeservice' -f $baseUri) @splat)

    $psObject = $horizon.edgeServiceSettingsList | ConvertTo-Json -Depth 5 | ConvertFrom-Json -Depth 5

    $psObject.proxyDestinationUrlThumbprints = $HorizonConnectionServerThumbprint
    $psObject.proxyDestinationUrl = $HorizonConnectionServerUrl

    $body = $psObject | ConvertTo-Json -Depth 5

    if ($PSCmdlet.ShouldProcess($HorizonConnectionServerThumbprint, $HorizonConnectionServerUri)) {
      $horizon = (Invoke-RestMethod -Method GET -Uri ('{0}/rest/v1/config/edgeservice' -f $baseUri) @splat)
   
      $response = (Invoke-RestMethod -Method PUT -Uri ('{0}/rest/v1/config/edgeservice/view' -f $baseUri) -Body $body @splat)
    }

    if ($PSBoundParameters.ContainsKey('PassThru')) {
      $response
    }
  }

  end {}
}