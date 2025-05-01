 <#
  .DESCRIPTION
  Connects to a Horizon Connection Server API.

  .EXAMPLE
  Connect-OmnissaHorizon -Server 'connectionserver.fqdn' -Credential $credential

  .NOTES
  Tested on Omnissa Horizon 2406.

  .OUTPUTS
  None.

  .LINK
  https://developer.omnissa.com/horizon-apis
#>

function Connect-OmnissaHorizon {
    [CmdletBinding()]
    param(   
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
 
        $headers = @{ 'Content-Type' = 'application/json' }
  
        $loginBody = @{
          'username' = $credential.GetNetworkCredential().UserName
          'password' = $credential.GetNetworkCredential().Password
          'domain' = $credential.GetNetworkCredential().Domain
        } | ConvertTo-Json
      }
      catch {
        throw $_
      }
    }
  
    process {
        $loginResponse = Invoke-RestMethod -Method POST -Uri ('{0}/login' -f $uri) -Headers $headers -Body $loginBody
  
        if ($null -eq $loginResponse) {
            Write-Error ("Error encountered logging into Omnissa Horizon Connection Server '{0}': {1}" -f $server, $_) -ErrorAction Stop
        }

        $global:OmnissaHorizonConnection = @{
            'Server' = $Server
            'AccessToken' = $loginResponse.access_token
            'RefreshToken' = $loginResponse.refresh_token
        }
    }
  
    end { }
  }