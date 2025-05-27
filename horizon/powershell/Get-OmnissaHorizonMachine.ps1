 <#
    .SYNOPSIS
    Retrieves details from Omnissa Horizon machine inventory.

    .DESCRIPTION
    Retrieves details from Omnissa Horizon machine inventory.

    .EXAMPLE
    Get-OmnissaHorizonMachine -Server 'connectionserver.fqdn' -Credential $credential

    .NOTES
    Tested on:
      * Omnissa Horizon 2503

    .OUTPUTS
    [PSCustomObject].

    .LINK
    https://developer.omnissa.com/horizon-apis
#>

#Requires -PSEdition Core

function Get-OmnissaHorizonMachine {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$Server,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]$Credential,

        [Parameter(Mandatory = $false)]
        [Int]$PageSize = 500,
    
        [Parameter(Mandatory = $false)]
        [Switch]$SkipCertificateCheck
    )

    begin {
        try {
            if ($SkipCertificateCheck) {
                if ($PSEdition -eq 'Core' -and -not(($PSDefaultParameterValues.Get_Item('Invoke-RestMethod:SkipCertificateCheck')))) {
                    $PSDefaultParameterValues.Add('Invoke-RestMethod:SkipCertificateCheck', $SkipCertificateCheck)
                }
                elseif ($PSEdition -eq 'Desktop') {
                    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12;

                    if (-not('TrustAllCertificatePolicy' -as [type])) {
                        Add-Type @"
                            using System.Net;
                            using System.Security.Cryptography.X509Certificates;
                            public class TrustAllCertificatePolicy : ICertificatePolicy {
                                public TrustAllCertificatePolicy() {}
                                public bool CheckValidationResult(
                                    ServicePoint sPoint, X509Certificate certificate,
                                    WebRequest wRequest, int certificateProblem) {
                                    return true;
                                }
                            }
"@
                    }
                
                    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertificatePolicy
                }
            }

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
          
            $desktopPoolUri = ('{0}/inventory/v8/desktop-pools' -f $uri)
            $machineUri = ('{0}/inventory/v5/machines' -f $uri)

            $desktopPool = @()

            $machine = @()            
        }
        catch {
            throw $_
        }
    }

    process {
        try {
            $i = 1
            
            if ($PSEdition -eq 'Core' -and -not(($PSDefaultParameterValues.Get_Item('Invoke-RestMethod:ResponseHeadersVariable')))) {
                $PSDefaultParameterValues.Add('Invoke-RestMethod:ResponseHeadersVariable', 'responseHeaders')
            }

            do {
                $response = Invoke-RestMethod -Method Get -Uri ('{0}?page={1}&size={2}' -f $desktopPoolUri, $i, $PageSize) -Headers $header

                if ($response.Count -ge 1) {
                    $desktopPool += $response
                }

                try {
                    $nextPage = [bool]::Parse($responseHeaders.HAS_MORE_RECORDS)
                }
                catch {
                    $nextPage = $false
                }
                
                $i++
            } while($nextPage)

            $i = 1

            do {
                $response = Invoke-RestMethod -Method Get -Uri ('{0}?page={1}&size={2}' -f $machineUri, $i, $PageSize) -Headers $header -ResponseHeadersVariable responseHeaders

                if ($response.Count -ge 1) {
                    $machine += $response
                }

                try {
                    $nextPage = [bool]::Parse($responseHeaders.HAS_MORE_RECORDS)
                }
                catch {
                    $nextPage = $false
                }

                $i++
            } while($nextPage)

            foreach ($_result in $machine) {
                $hash = [Ordered]@{
                    Name = $_result.Name
                    DesktopPool = $desktopPool | Where-Object { $_.id -eq $_result.desktop_pool_id } | Select-Object -ExpandProperty Name
                    DnsName = $_result.dns_name
                    Host = $_result.managed_machine_data.host_name
                    Agent = $_result.agent_version
                    Datastore = $_result.managed_machine_data.virtual_disks.datastore_path | Select-Object -Unique
                }

                New-Object -TypeName PSCustomObject -Property $hash
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
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