function Add-OmnissaHorizonPermission {
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$SID,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Role,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$AccessGroup,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.Management.Automation.PSCredential]
    [System.Management.Automation.Credential()]$Credential
  )

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

  $header.Add('Authorization',('Bearer {0}' -f $loginResponse.access_token))
  $header.Add('Accept','application/json')

  $roles = Invoke-RestMethod -Method GET -Uri ('{0}/config/v1/roles' -f $uri) -Headers $header
  $role_id = $roles | Where-Object { $_.Name -eq $Role } | Select-Object -ExpandProperty id

  # Federation Cloud Pod ID - optional
  #$cpa = Invoke-RestMethod -Method GET -Uri ('{0}/federation/v1/cpa' -f $uri) -Headers $header
  #$federation_access_group_id = $cpa.connection_server_statuses.id

  $local_access_groups = Invoke-RestMethod -Method GET -Uri ('{0}/config/v1/local-access-groups' -f $uri) -Headers $header
  $local_access_group_id = $local_access_groups | Where-Object { $_.name -eq $AccessGroup } | Select-Object -ExpandProperty id

  $permissionBody = @{
    'ad_user_or_group_id' = $sid
    'local_access_group_id' = $local_access_group_id
    'role_id' = $role_id
  }

  if ($null -ne $federation_access_group_id) {
    $permissionBody.Add('federation_access_group_id', $federation_access_group_id)
  }

  $permissionBodyJson = ConvertTo-Json -InputObject @($permissionBody)

  $permissionResponse = Invoke-RestMethod -Method POST -Uri ('{0}/config/v2/permissions' -f $uri) -Headers $header -Body $permissionBodyJson
}