 <#
    .SYNOPSIS
    Retrieves active Omnissa Horizon sessions from given IP addresses and/or hostnames.
  
    .DESCRIPTION
    Retrieves active Omnissa Horizon sessions from given IP addresses and/or hostnames.

    .EXAMPLE
    Trace-OmnissaHorizonSession -IPAddress 172.16.13.37 -Server 'connectionserver.fqdn' -Credential $credential

    .EXAMPLE
    Trace-OmnissaHorizonSession -Server 'connectionserver.fqdn' -Credential $credential  

    .NOTES
    Tested on:
      * Omnissa Horizon 2406
      * Omnissa Horizon 2503
    TODO: 
      * Pagination
      * CPA support

    .OUTPUTS
    PSCustomObject.

    .LINK
    https://developer.omnissa.com/horizon-apis
#>

function Trace-OmnissaHorizonSession {
  [CmdletBinding(DefaultParameterSetName = 'DefaultSet')]
  param(  
    [Parameter(Mandatory = $true, ParameterSetName = 'IPAddressSet')]
    [ValidateNotNullOrEmpty()]
    [System.Net.IPAddress[]]$IPAddress,

    [Parameter(Mandatory = $true, ParameterSetName = 'HostNameSet')]
    [ValidateNotNullOrEmpty()]
    [String[]]$HostName,

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

      $loginResponse = Invoke-RestMethod -Method POST -Uri ('{0}/login' -f $uri) -Headers $headers -Body $loginBody

      if ($null -eq $loginResponse) {
          Write-Error ("Error encountered logging into Omnissa Horizon Connection Server '{0}': {1}" -f $server, $_) -ErrorAction Stop
      }
      
      $headers.Add('Authorization',('Bearer {0}' -f $loginResponse.access_token))
      $headers.Add('Accept','application/json')

      $sessionUri = if ($PSBoundParameters.ContainsKey('Global')) {
        ('{0}/inventory/v1/global-sessions' -f $uri)
      }
      else {
        ('{0}/inventory/v2/sessions' -f $uri)
      }

      $machineUri = ('{0}/inventory/v5/machines' -f $uri)
      $desktopPoolUri = ('{0}/inventory/v8/desktop-pools' -f $uri)

      $sessions = Invoke-RestMethod -Uri $sessionUri -Headers $headers
    }
    catch {
      throw $_
    }
  }

  process {
    switch ($PSCmdlet.ParameterSetName) {
      'HostNameSet' {
        $sessions = $sessions | Where-Object { $_.client_data.name -in $HostName }
      }      
      'IPAddressSet' {
        $sessions = $sessions | Where-Object { $_.client_data.address -in $IPAddress }
      }
    }

    if ($null -ne $sessions) {
      $hash = [Ordered]@{}

      foreach ($_session in $sessions) {
        $machine = Invoke-RestMethod -Uri ('{0}\{1}' -f $machineUri, $_session.machine_id) -Headers $headers
        $desktopPool = Invoke-RestMethod -Uri ('{0}\{1}' -f $desktopPoolUri, $_session.desktop_pool_id) -Headers $headers

        $_session
        $hash.Add('HostName', $_session.client_data.name)
        $hash.Add('IPAddress', $_session.client_data.address)
        $hash.Add('DesktopPool', $desktopPool.name)
        $hash.Add('Machine', $machine.dns_name)
        $hash.Add('State', $_session.session_state)
        $hash.Add('SessionStarted', ([DateTimeOffset]::FromUnixTimeSeconds($_session.start_time.ToString().SubString(0,$_session.start_time.ToString().Length-3))))

        try {
          $hash.Add('User', ([System.Security.Principal.SecurityIdentifier]::new($_session.user_id).Translate([System.Security.Principal.NTAccount])))
        }
        catch {
          $hash.Add('User', $_session.user_id)
        }
      }

      New-Object -TypeName PSCustomObject -Property $hash
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