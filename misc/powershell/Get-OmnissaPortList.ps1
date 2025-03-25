  <#
    .DESCRIPTION
    Retrieves Omnissa port list.

    .EXAMPLE
    Get-OmnissaPortList

    .OUTPUTS
    PSCustomObject.

    .LINK
    https://ports.omnissa.com/
#>

function Get-OmnissaPortList {
  [CmdletBinding()]
  [OutputType([HashTable])]
  param ()

  begin {
    $baseUri = 'https://ports-manage-svc.gid.omnissa.com/manage/view/v1/omnissaproducts'

    $products = Invoke-RestMethod -Uri $baseUri -Method Get

    $hash = [Ordered]@{}    
  }

  process {
    foreach ($_product in ($products | Sort-Object -Property productName)) {
      $ports = Invoke-RestMethod -Uri ('{0}/{1}/listings1' -f $baseUri, $_product.id) -Method Get

      if (($ports | Measure-Object).Count -ne 0) {
        $hash.Add($_product.productName, $ports)
      }
    }
  }

  end {
    $hash
  }
}