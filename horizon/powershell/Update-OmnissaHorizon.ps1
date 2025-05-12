 <#
  .DESCRIPTION
  Updates an Omnissa Horizon Connection Server.

  .EXAMPLE
  Update-OmnissaHorizon -FilePath 'Omnissa-Horizon-Connection-Server-x86_64-2503-8.15.0-14365030791.exe'

  .NOTES
  Tested on Omnissa Horizon 2406 to 2512.

  .OUTPUTS
  None.
#>

function Update-OmnissaHorizon {
  [CmdletBinding()]
  param(   
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [System.IO.FileInfo]$FilePath
  )

  begin {
    try {
      if (-not(Test-Path -Path $FilePath -PathType Leaf -ErrorAction SilentlyContinue)) {
        throw ("The file '{0}' does not exist" -f $FilePath.FullName)
      }

      $argumentList = '/s /v "/qb"'
      $logFilePattern = 'Installation operation completed successfully'      
      $logFileNamePattern = 'vmmsi.log'
    }
    catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
  
  process {
    try {
      Start-Process -FilePath $FilePath -ArgumentList $argumentList -Wait  
        
      $installationLogFile = Get-ChildItem -Path $env:Temp | Where-Object { $_.Name -match $logFileNamePattern } | Sort-Object -Property LastWriteTime | Select-Object -First 1 -ExpandProperty FullName

      if ($null -ne $installationLogFile) {
        if (Select-String -Path $installationLogFile -Pattern $logFilePattern) {
          Write-Output $logFilePattern
        }
        else {
          Write-Error ("Installation failed - details in the '{0}' log file" -f $installationLogFile)
        } 
      }
      else {
        Write-Error 'Installation log file could not be found'
      }
    }
    catch {
      $PSCmdlet.ThrowTerminatingError($_)
    }
  }
  
  end { }
}