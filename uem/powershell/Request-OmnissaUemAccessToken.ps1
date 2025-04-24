  <#
    .SYNOPSIS
    Requests an Omnissa Workspace ONE UEM access token using an OAuth 2.0 client id and client secret pair.

    .DESCRIPTION
    Requests an Omnissa Workspace ONE UEM access token using an OAuth 2.0 client id and client secret pair.

    .PARAMETER ClientId
    Specifies the OAuth 2.0 Client ID.

    .PARAMETER ClientSecret
    Specifies the OAuth 2.0 Client Secret.

    .PARAMETER Region
    Specifies the Omnissa Workspace ONE UEM Token Service region.

    .EXAMPLE
    Request-OmnissaUemAccessToken -Region Frankfurt

    .OUTPUTS
    SecureString.

    .LINK
    https://docs.omnissa.com/bundle/WorkspaceONE-UEM-Console-BasicsVSaaS/page/UsingUEMFunctionalityWithRESTAPI.html#datacenter_and_token_urls_for_oauth_20_support

    .LINK
    https://developer.omnissa.com/workspace-one-uem-apis
#>

function Request-OmnissaUemAccessToken {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ClientId,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$ClientSecret,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Ohio', 'Virginia', 'Frankfurt', 'Tokyo')]
    [String]$Region
  )
  
  begin {
    $regionHash = @{
      'Ohio' = 'https://uat.uemauth.vmwservices.com/connect/token'
      'Virginia' = 'https://na.uemauth.vmwservices.com/connect/token'
      'Frankfurt' = 'https://emea.uemauth.vmwservices.com/connect/token'
      'Tokyo' = 'https://apac.uemauth.vmwservices.com/connect/token'
    }

    $uri = $regionHash.Get_item($Region)

    $body = @{
        'grant_type' = 'client_credentials'
        'client_id' = $ClientId
        'client_secret' = $ClientSecret
    }
  }

  process {
    try {
        (Invoke-RestMethod -Uri $uri -Method POST -Body $body).access_token | ConvertTo-SecureString -AsPlainText -Force
    }
    catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
  }

  end { }
}