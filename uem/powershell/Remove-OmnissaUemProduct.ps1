<#
    .SYNOPSIS
    Removes Omnissa Workspace ONE UEM product(s).

    .DESCRIPTION
    Removes Omnissa Workspace ONE UEM product(s). If neither name(s) nor id(s) are specified, every product will be returned for deletion.

    .PARAMETER Name
    Specifies one or more product name(s) to delete (search filter).

    .PARAMETER Id
    Specifies one or more id(s) of products to delete.

    .PARAMETER Server
    Specifies the Omnissa Workspace ONE UEM REST API URL.

   .PARAMETER AccessToken
    Specifies the Omnissa Workspace ONE UEM REST API Access Token.

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Remove-OmnissaUemProduct -Server $server -AccessToken $accessToken

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Remove-OmnissaUemProduct -Server $server -AccessToken $accessToken -Name 'Product 1','Product 2'    

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Remove-OmnissaUemProduct -Server $server -AccessToken $accessToken -Id '1337','1338'

    .OUTPUTS
    SecureString.

    .LINK
    https://developer.omnissa.com/workspace-one-uem-apis
#>
 
function Remove-OmnissaUemProduct {
 [CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess = $true, DefaultParameterSetName = 'AllSet')]
  param(
    [Parameter(Mandatory = $true, ParameterSetName = 'NameSet')]
    [ValidateNotNullOrEmpty()]
    [String[]]$Name,

    [Parameter(Mandatory = $true, ParameterSetName = 'IdSet')]
    [ValidateNotNullOrEmpty()]
    [String[]]$Id,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [String]$Server,

    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [SecureString]$AccessToken
  )
  
  begin {
    if (-not($Server.ToString().Split('/')[-1] -eq 'API')) {
      $uri = $Server + '/API'
    }
    else {
      $uri = $Server
    }

    if (-not($Server -match 'https://')) {
      $Server = 'https://' + $Server
    }

    if ($Server[-1] -eq '/') {
      $uri = $Server.Substring(0,$Server.Length-1)
    }

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AccessToken)
    $token = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)

    $headers = @{
      'Accept' = 'application/json;version=1'
      'Authorization' = ('Bearer {0}' -f $token)
    }

    $splat = @{}

    $splat.Add('Headers', $Headers)
    $splat.Add('Method', 'Delete')

    $getSplat = @{}
    $getSplat.Add('Server', $Server)
    $getSplat.Add('AccessToken', $AccessToken)

    $removeUri = ('{0}/mdm/products' -f $uri)

    if ($PSCmdlet.ParameterSetName -eq 'AllSet') {
      if ($PSBoundParameters.ContainsKey('PageSize')) {
          $splat.Add('PageSize', $PageSize)
      }
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'NameSet') {
      $getSplat.Add('Name', $Name)
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'IdSet') {
      $getSplat.Add('Id', $Id)
    }

    $products = Get-OmnissaUemProduct @getSplat
  }

  process {              
    foreach ($_product in $products) {
      if ($PSCmdlet.ShouldProcess(('{0} with ID {1}' -f $_product.Name, $_product.ID.Value))) {
        $_uri = ('{0}/{1}' -f $removeUri, $_product.Id.Value)

        Invoke-RestMethod @splat -Uri $_uri
      }
    }
  }

  end { }
}