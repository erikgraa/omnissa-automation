 <#
  .DESCRIPTION
  Grants entitlement on an Omnissa Horizon Desktop Pool.

  .EXAMPLE
  Grant-OmnissaHorizonEntitlement -Server 'connectionserver.fqdn' -Credential $credential

  .MISCELLANEOUS
  Tested on Omnissa Horizon 2406.

  .OUTPUTS
  None.

  .LINK
  https://developer.omnissa.com/horizon-apis
#>

function Grant-OmnissaHorizonEntitlement {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String[]]$Sid,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$DesktopPool,

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
      if (-not($Server.Split('/')[-1] -eq 'rest')) {
        $uri = $Server + '/rest'
      }
      else {
        $uri = $Server
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

      $desktopPools = Invoke-RestMethod -Method GET -Uri ('{0}/inventory/v1/desktop-pools' -f $uri) -Headers $header
      $pool_id = $desktopPools | Where-Object { $_.display_name -eq $DesktopPool } | Select-Object -ExpandProperty id
    }
    catch {
      throw $_
    }
  }

  process {
    foreach ($_sid in $Sid) {
      $entitlementBody = @{
        'ad_user_or_group_ids' = @($sid)
        'id' = $pool_id
      }

      $entitlementBodyJson = ConvertTo-Json -InputObject @($entitlementBody)

      $entitlementResponse = Invoke-RestMethod -Method POST -Uri ('{0}/entitlements/v1/desktop-pools' -f $uri) -Headers $header -Body $entitlementBodyJson
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