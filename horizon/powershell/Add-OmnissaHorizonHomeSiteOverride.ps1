 <#
    .SYNOPSIS
    Adds a home site override for a user or group on an Omnissa Horizon Global Entitlement.

    .DESCRIPTION
    Adds a home site override for a user or group on an Omnissa Horizon Global Entitlement.

    .EXAMPLE
    Add-OmnissaHorizonHomeSiteOverride -Server 'connectionserver.fqdn' -Credential $credential

    .NOTES
    Tested on:
      * Omnissa Horizon 2503
      * Omnissa Horizon 2603

    .OUTPUTS
    None.

    .LINK
    https://developer.omnissa.com/horizon-apis
#>
function Add-OmnissaHorizonHomeSiteOverride {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Sid,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$GlobalEntitlement,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Site,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential
  )

  begin {
    try {
      if (-not($Server -match 'https://')) {
        $uri = 'https://' + $Server
      }
      else {
        $uri = $Server
      }

      if (-not($Server.Split('/')[-1] -eq 'rest')) {
        $uri = $uri + '/rest'
      }

      $header = @{ 'Content-Type' = 'application/json' }

      $loginBody = @{
        'username' = $credential.GetNetworkCredential().UserName
        'password' = $credential.GetNetworkCredential().Password
        'domain' = $credential.GetNetworkCredential().Domain
      } | ConvertTo-Json


      $loginResponse = Invoke-RestMethod -Method POST -Uri ('{0}/login' -f $uri) -Headers $header -Body $loginBody

      if ($null -eq $loginResponse) {
          Write-Error ("Error encountered logging into Omnissa Horizon Connection Server '{0}': {1}" -f $server, $_) -ErrorAction Stop
      }
      
      $header.Add('Authorization',('Bearer {0}' -f $loginResponse.access_token))
      $header.Add('Accept','application/json')

      $globalDesktopEntitlements = Invoke-RestMethod -Method GET -Uri ('{0}/inventory/v1/global-desktop-entitlements' -f $uri) -Headers $header

      $globalDesktopEntitlement = $globalDesktopEntitlements | Where-Object { $_.display_name -eq $GlobalEntitlement }

      if ($null -eq $globalDesktopEntitlement) { 
        throw "Not a valid global entitlement"
      }

      if ($globalDesktopEntitlement.use_home_site -eq $false) {
        throw "Global entitlement must have 'Use home site' enabled"
      }

      $pool_id = $globalDesktopEntitlement | Select-Object -ExpandProperty id

      $sites = Invoke-RestMethod -Method GET -Uri ('{0}/federation/v2/sites' -f $uri) -Headers $header
      $site_id = $sites | Where-Object { $_.name -eq $Site } | Select-Object -ExpandProperty id

      if ($null -eq $site_id) {
        throw "Not a valid site"
      }
    }
    catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }

  process {
    foreach ($_sid in $Sid) {
      $body = @{
        'ad_user_or_group_id' = $_sid
        'global_desktop_entitlement_id' = $pool_id
        'site_id' = $site_id
      }

      $bodyJson = ConvertTo-Json -InputObject @($body)

      $response = Invoke-RestMethod -Method POST -Uri ('{0}/federation/v2/home-sites' -f $uri) -Headers $header -Body $bodyJson

      if ($response.status_code -notmatch '2\d{2,2}') {
        Write-Error $response.errors.error_message -ErrorAction Stop
      }
    }
  }

  end {
    if ($null -ne $loginResponse) {
      $logoutBody = @{
        'refresh_token' = $loginResponse.refresh_token
      } | ConvertTo-Json

      $logoutResponse = Invoke-RestMethod -Method POST -Uri ('{0}/logout' -f $uri) -ContentType 'application/json' -Body $logoutBody    
    }
  }
}