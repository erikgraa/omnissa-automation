<#
    .SYNOPSIS
    Retrieves Omnissa Workspace ONE UEM product(s).

    .DESCRIPTION
    Retrieves Omnissa Workspace ONE UEM product(s). If neither name(s) nor id(s) are specified, every product will be enumerated within the pagesize.

    .PARAMETER Name
    Specifies one or more product name(s) to retrieve (search filter).

    .PARAMETER Id
    Specifies one or more id(s) of products to retrieve.

    .PARAMETER Server
    Specifies the Omnissa Workspace ONE UEM REST API URL.

    .PARAMETER AccessToken
    Specifies the Omnissa Workspace ONE UEM REST API Access Token.

    .PARAMETER PageSize
    Specifies the page size. Defaults to 500.

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Get-OmnissaUemProduct -Server $server -AccessToken $accessToken

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Get-OmnissaUemProduct -Server $server -AccessToken $accessToken -Name 'Product 1','Product 2'    

    .EXAMPLE
    $accessToken = Request-OmnissaUemAccessToken -Region Frankfurt
    $server = 'https://cn<ID>.awmdm.com/API'
    Get-OmnissaUemProduct -Server $server -AccessToken $accessToken -Id '1337','1338'

    .OUTPUTS
    SecureString.

    .LINK
    https://developer.omnissa.com/workspace-one-uem-apis
#>

function Get-OmnissaUemProduct {
 [CmdletBinding(DefaultParameterSetName = 'AllSet')]
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
    [SecureString]$AccessToken,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10000)]
    [Int]$PageSize
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

    $commonSplat = @{}

    $commonSplat.Add('Headers', $Headers)
    $commonSplat.Add('Method', 'Get')

    $lookupUri = ('{0}/mdm/products' -f $uri)
    $extensiveSearchUri = ('{0}/extensivesearch' -f $lookupUri)
  }

  process {
    if ($PSCmdlet.ParameterSetName -eq 'AllSet') {
      $searchUri = $extensiveSearchUri 

      if ($PSBoundParameters.ContainsKey('PageSize')) {
          $searchUri += ('?pagesize={0}' -f $PageSize)
      }

      $splat = $commonSplat.Clone()
      
      $splat.Add('Uri', $searchUri)
      
      (Invoke-RestMethod @splat).Product 
    }
    elseif ($PSCmdlet.ParameterSetName -eq 'NameSet') {
      foreach ($_name in $Name) {
        $searchUri = ('{0}?name={1}' -f $extensiveSearchUri, $_name)

        $splat = $commonSplat.Clone()
    
        $splat.Add('Uri', $searchUri)
    
        (Invoke-RestMethod @splat).Product
      }
  }
    elseif ($PSCmdlet.ParameterSetName -eq 'IdSet') {
      foreach ($_id in $Id) {
        $searchUri = ('{0}/{1}' -f $lookupUri, $_id)

        $splat = $commonSplat.Clone()
    
        $splat.Add('Uri', $searchUri)
    
        Invoke-RestMethod @splat
      }
    }
  }

  end { }
}