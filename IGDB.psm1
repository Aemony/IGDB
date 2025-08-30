<#
  .SYNOPSIS
    PowerShell module for interfacing with the IGDB API.

  .DESCRIPTION
    PowerShell module for interfacing with the IGDB API.

  .NOTES
    Work in progress.
#>

Write-Host ""
Write-Host "---------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""
Write-Host "       This PowerShell module allows you to connect to the IGDB API.       " -ForegroundColor Yellow
Write-Host ""
Write-Host "         To establish a new connection: "                                    -ForegroundColor Yellow -NoNewline
                                         Write-Host "Connect-IGDBSession"                -ForegroundColor DarkGreen
Write-Host "      To use/setup a persistent config: "                                    -ForegroundColor Yellow -NoNewline
                                         Write-Host "Connect-IGDBSession -Persistent"    -ForegroundColor DarkYellow
Write-Host "      To disconnect the active session: "                                    -ForegroundColor Yellow -NoNewline
                                         Write-Host "Disconnect-IGDBSession"             -ForegroundColor Gray
Write-Host "        To reset the persistent config: "                                    -ForegroundColor Yellow -NoNewline
                                         Write-Host "Connect-IGDBSession -Reset"         -ForegroundColor DarkGray
Write-Host ""
Write-Host "---------------------------------------------------------------------------" -ForegroundColor Yellow
Write-Host ""
































# --------------------------------------------------------------------------------------- #
#                                                                                         #
#                                         NOTEs                                           #
#                                                                                         #
# --------------------------------------------------------------------------------------- #

# - Most endpoints are defined through dynamic 
























# --------------------------------------------------------------------------------------- #
#                                                                                         #
#                                      GLOBAL STUFF                                       #
#                                                                                         #
# --------------------------------------------------------------------------------------- #

# Enum used to indicate authorization token type
enum TokenType
{
  None
  Bearer
}

# Unset all variables when the module is being removed from the session
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = { Disconnect-IGDBSession }

# Global configurations
$script:ProgressPreference = 'SilentlyContinue' # Suppress progress bar (speeds up Invoke-WebRequest by a ton)

# Global variable to hold the web session
$global:IGDBSession

# Script variable to indicate the location of the saved config file
$script:ConfigFileName = $env:LOCALAPPDATA + '\PowerShell\IGDB\config.json'

# Script variables used internally during runtime
$script:Config = @{
  ClientID     = $null
  AuthURL      = $null
  BaseURL      = $null
  Persistent   = $false
  TokenType    = $null
  AccessToken  = $null
  ExpiresIn    = $null
}
$script:Cache          = @{
}

# PowerShell prefers using pascal case wherever is possible so let us rename as many property names as possible.
# This can potentially cause issues when something is renamed (e.g. Anon -> Anonymous)
$script:PropertyNamePascal    = @{
  # Nothing yet
}










# --------------------------------------------------------------------------------------- #
#                                                                                         #
#                                     HELPER CMDLETs                                      #
#                                                                                         #
# --------------------------------------------------------------------------------------- #

#region Copy-Object
function Copy-Object
{
<#
  .SYNOPSIS
    Helper function to do a deep copy on input objects.
  .DESCRIPTION
    In various situations PowerShell can pass a reference to another object instead of
    passing a copy of the object. This can result in situations where modifying the data
    in a later function or call also modifies the original data. This helper function
    works around the issue by forcing a deep copy of the input objects to ensure no
    references to the original copy remain.

    Note that depending on the complexity of the input object, this action can be slow
    and should therefor only be used when necessary.
  .PARAMETER InputObject
    The input object to perform a deep copy of. The object will be traversed to the
    depth specified by the -Depth parameter (default 100).
  .PARAMETER Depth
    The depth of the object to traverse when doing the deep copy. Defaults to 100.
  .LINK
    https://stackoverflow.com/a/57045268
  .NOTES
    Licensed by CC BY-SA 4.0
    https://creativecommons.org/licenses/by-sa/4.0/
#>
  [CmdletBinding()]
  param (
    [Parameter(ValueFromPipeline)]
    [Object[]]$InputObject,
    
    [Parameter()]
    [uint32] $Depth = 100
  )

  Begin { }

  Process {
    $Clones = ForEach ($Object in $InputObject) {
      $Object | ConvertTo-Json -Compress -Depth $Depth | ConvertFrom-Json
    }

    return $Clones
  }

  End { }
}
#endregion

#region ConvertFrom-JsonToHashtable
<#
  .SYNOPSIS
    Helper function to take a JSON string and turn it into a hashtable
  .DESCRIPTION
    The ConvertFrom-Json method does not have the -AsHashtable switch in Windows PowerShell,
    which makes it inconvenient to convert JSON to hashtable.
  .LINK
    https://github.com/abgox/ConvertFrom-JsonToHashtable
  .NOTES
    MIT License

    Copyright (c) 2024-present abgox <https://github.com/abgox | https://gitee.com/abgox>

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
#>
function ConvertFrom-JsonToHashtable
{
  param (
      [Parameter(ValueFromPipeline = $true)]
      [string]$InputObject
  )

  $Results = [regex]::Matches($InputObject, '\s*"\s*"\s*:')
  foreach ($Result in $Results)
  { $InputObject = $InputObject -replace $Result.Value, "`"empty_key_$([System.Guid]::NewGuid().Guid)`":" }
  $InputObject = [regex]::Replace($InputObject, ",`n?(\s*`n)?\}", "}")

  function ProcessArray ($Array)
  {
    $NestedArray = @()
    foreach ($Item in $Array)
    {
      if ($Item -is [System.Collections.IEnumerable] -and $Item -isnot [string])
      { $NestedArray += , (ProcessArray $Item) }
      elseif ($Item -is [System.Management.Automation.PSCustomObject])
      { $NestedArray += ConvertToHashtable $Item }
      else
      { $NestedArray += $Item }
    }
    return , $NestedArray
  }

  function ConvertToHashtable ($Object)
  {
    $Hash = [ordered]@{}

    if ($Object -is [System.Management.Automation.PSCustomObject])
    {
      foreach ($Property in $Object | Get-Member -MemberType Properties)
      {
        $Key   = $Property.Name # Key
        $Value = $Object.$Key   # Value

        # Handle array (preserve nested structure)
        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
        { $Hash[[object] $Key] = ProcessArray $Value }

        # Handle object
        elseif ($Value -is [System.Management.Automation.PSCustomObject])
        { $Hash[[object] $Key] = ConvertToHashtable $Value }

        else
        { $Hash[[object] $Key] = $Value }
      }
    }

    else
    { $Hash = $Object }

    $Hash # Do not convert to [PSCustomObject] and output. # [PSCustomObject]
  }

  # Recurse
  ConvertToHashtable ($InputObject | ConvertFrom-Json)
}
#endregion

#region ConvertFrom-HashtableToPSObject
# Based on ConvertFrom-JsonToHashtable just above
function ConvertFrom-HashtableToPSObject
{
  param (
    [Parameter(Mandatory, ValueFromPipeline)]
    [AllowNull()]
    $InputObject
  )

  function ProcessArray ($Array)
  {
    $NestedArray = @()
    #$NestedArray = [ordered] @{}

    foreach ($Item in $Array)
    {
      if ($Item -is [System.Collections.Specialized.OrderedDictionary])
      { $NestedArray += ConvertToPSObject $Item }
      elseif ($Item -is [System.Collections.IEnumerable] -and $Item -isnot [string])
      { $NestedArray += , (ProcessArray $Item) }
      else
      { $NestedArray += $Item }
    }
    return , $NestedArray
  }

  function ConvertToPSObject ($Object)
  {
    $Hash = [ordered] @{}

    if ($Object -is [System.Collections.Specialized.OrderedDictionary])
    {
      foreach ($Property in $Object.GetEnumerator())
      {
        $Key   = $Property.Name # Key
        $Value = $Object.$Key   # Value
        $NewName = $PropertyNamePascal[$Key]

        if ($NewName)
        { $Key = $NewName }
        elseif ($Key -notmatch "^[-]?[\d]+$")
        { Write-Verbose "Missing pascal case for: $Key" }

        # Handle array (preserve nested structure)
        if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string])
        { $Hash[[object] $Key] = ProcessArray $Value }

        # Handle object
        elseif ($Value -is [System.Collections.Specialized.OrderedDictionary])
        { $Hash[[object] $Key] = ConvertToPSObject $Value }

        else
        { $Hash[[object] $Key] = $Value }
      }
    }

    else
    { $Hash = $Object }

    [PSCustomObject]$Hash # Convert to [PSCustomObject] and output
  }

  # Recurse
  ConvertToPSObject ($InputObject)
}
#endregion

#region Rename-PropertyName
function Rename-PropertyName
{
<#
  .SYNOPSIS
    Helper function used to rename specific property names to something else.
  .DESCRIPTION
    When used to validate a [string] parameter, the input object will only be allowed if it
    matches a positive namespace ID or name registered on the MediaWiki site.
  .PARAMETER InputObject
    An object to perform the validation on.
  .EXAMPLE
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory, Position=0)]
    $InputObject,
    [Parameter(Mandatory, Position=1)]
    $PropertyName,
    [Parameter(Mandatory, Position=2)]
    $NewPropertyName
  )

  $Value = $InputObject.$PropertyName
  $InputObject.PSObject.Properties.Remove($PropertyName)
  $InputObject | Add-Member -MemberType NoteProperty -Name $NewPropertyName -Value $Value

  return $InputObject
}
#endregion

#region Test-IGDBResultSize
function Test-IGDBResultSize
{
<#
  .SYNOPSIS
    Validation helper used to ensure the input is an 'Unlimited' string or a positive integer.
  .DESCRIPTION
    When used to validate a [string] parameter, the input object will only be accepted if it is
    a positive integer or 'Unlimited' is specified.
  .PARAMETER InputObject
    An object to perform the validation on.
  .EXAMPLE
    [ValidateScript({ Test-IGDBResultSize -InputObject $PSItem })]
    [string]$ResultSize = 1000,
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    $InputObject
  )

  if (([string]$InputObject -eq 'Unlimited') -or ([int32]$InputObject -gt 0))
  { $true }
  else
  { throw ('Specify a valid number of results to retrieve, or "Unlimited" to retrieve all.') }
}
#endregion

#region Write-IGDBWarningResultSize
function Write-IGDBWarningResultSize
{
<#
  .SYNOPSIS
    Warning helper used to throw a common warning message when there are more results available
  .DESCRIPTION
    The input object is used to validate if more data is available, and if so this warning helper
    throws an appropriate warning based on the default result size and the given result size.
  .PARAMETER InputObject
    Used to indicate if more data is available. The variable is checked against $null so any
    non-null value will be handled as if more data is available.
  .PARAMETER DefaultSize
    The default result size of the caller function, when not specified by an input parameter.
  .PARAMETER ResultSize
    The actual result size value of the caller function, typically specified through an input parameter.
  .EXAMPLE
    Write-IGDBWarningResultSize -InputObject $Body.apcontinue -DefaultSize 1000 -ResultSize $ResultSize
#>
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [AllowNull()]
    $InputObject,
    [Parameter(Mandatory)]
    [uint32]$DefaultSize,
    [Parameter(Mandatory)]
    [uint32]$ResultSize
  )

  if ($InputObject)
  {
    $Message = if ($ResultSize -eq $DefaultSize) { "By default, only the first $DefaultSize items are returned." }
                                            else { 'There are more results available than currently displayed.'  }
    $Message += ' Use the ResultSize parameter to specify the number of items returned. To return all items, specify "-ResultSize Unlimited".'
    Write-Warning $Message
  }
}
#endregion

#region Set-Substring
Set-Alias -Name Replace-Substring -Value Set-Substring
function Set-Substring
{
<#
  .SYNOPSIS
    String helper used to replace the nth occurrence of a substring.
  .DESCRIPTION
    Function used to replace the nth occurrence of a substring within a given string,
    using an optional string comparison type.
  .PARAMETER InputObject
    String to act upon.
  .PARAMETER Substring
    Substring to search for.
  .PARAMETER NewSubstring
    The new substring to replace the found substring with.
  .PARAMETER Occurrence
    The nth occurrence to replace. Defaults to first occurrence.
  .PARAMETER Comparison
    The string comparison type to use. Defaults to InvariantCultureIgnoreCase.
  .EXAMPLE
    $ContentBlock | Set-Substring -Substring $Target -NewSubstring $NewSection -Occurrence -1
  .INPUTS
    String to act upon.
  .OUTPUTS
    Returns InputObject with the nth matching substring changed.
#>
  [CmdletBinding()]
  param(
    [Parameter(Mandatory, ValueFromPipeline)]
    [string]$InputObject,
    
    [Parameter(Mandatory, Position=0)]
    [string]$Substring,

    [Parameter(Mandatory, Position=1)]
    [Alias('Replacement')]
    [AllowEmptyString()]
    [string]$NewSubstring,

    [Parameter()]
       [int]$Occurrence = 0, # Positive: from start; Negative: from back.

    [Parameter()]
    [StringComparison]$Comparison = [StringComparison]::InvariantCultureIgnoreCase
  )
  
  Begin { }

  Process
  {
    $Index   = -1
    $Indexes = @()

    if ($Occurrence -gt 0)
    {
      $Occurrence--
    }

    do
    {
      $Index = $InputObject.IndexOf($Substring, 1 + $Index, $Comparison)
      if ($Index -ne -1)
      {
        $Indexes += $Index
      }
    } while ($Index -ne -1)

    if ($null  -ne   $Indexes[$Occurrence]) {
      $Index       = $Indexes[$Occurrence]
      $InputObject = $InputObject.Remove($Index, $Substring.Length).Insert($Index, $NewSubstring)
    } elseif ($Indexes.Count -gt 0) {
      Write-Verbose "The specified occurrence does not exist."
    } else {
      Write-Verbose "No matching substring was found."
    }

    return $InputObject
  }

  End { }
}
#endregion
































# --------------------------------------------------------------------------------------- #
#                                                                                         #
#                                         CMDLETs                                         #
#                                                                                         #
# --------------------------------------------------------------------------------------- #

#region Clear-IGDBSession
function Clear-IGDBSession
{
  [CmdletBinding()]
  param ( )

  Begin { }

  Process { }

  End
  {
    # Clear the variables of their current values
    if ($null -ne $global:IGDBSession)
    { Clear-Variable IGDBSession -Scope Global }

    if ($null -ne $script:Config)
    { Clear-Variable Config -Scope Script }

    if ($null -ne $script:Cache)
    { Clear-Variable Cache -Scope Script }

    # Reset the variables to their default values
    $global:IGDBSession      = $null

    $script:Config         = @{
      ClientID     = $null
      AuthURL      = $null
      BaseURL      = $null
      Persistent   = $false
      TokenType    = $null
      AccessToken  = $null
      ExpiresIn    = $null
    }

    $script:Cache          = @{
    }
  }
}
#endregion

#region Connect-IGDBSession
function Connect-IGDBSession
{
  [CmdletBinding()]
  param (
    <#
      Main parameters
    #>
    [switch]$Persistent,
    [switch]$Reset,

    <#
      Optional parameters
    #>
    [switch]$Silent
  )

  Begin
  {
    $TempConfig = $null

    if ($Reset)
    {
      if ((Test-Path $script:ConfigFileName) -eq $true)
      { Remove-Item $script:ConfigFileName }
    }

    if ($Persistent -and (Test-Path $script:ConfigFileName) -eq $true)
    {
      Write-Verbose "Using stored credentials. Use -Reset to recreate or bypass the stored credentials."

      Try
      {
        # Try to load the config file.
        $TempConfig = Get-Content $script:ConfigFileName -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop

        # Try to convert the hashed client secret. This will only work on the same machine that the config file was created on.
        $TempConfig.ClientSecret = ConvertTo-SecureString $TempConfig.ClientSecret -ErrorAction Stop
      } Catch [System.Management.Automation.ItemNotFoundException], [System.ArgumentException] {
        # Handle corrupt config file
        Write-Warning "The stored configuration could not be found or was corrupt."
        $TempConfig = $null
      } Catch [System.Security.Cryptography.CryptographicException] {
        # Handle an invalid client secret hash
        Write-Warning "The stored Client Secret could not be read."
        $TempConfig = $null
      } Catch {
        # Unknown exception
        Write-Warning "Unknown error occurred when trying to read the stored configuration."
        $TempConfig = $null
      }
    }

    if ($null -eq $TempConfig)
    {
      $ClientID = Read-Host 'Client ID'

      if ($ClientID.Length -eq 0)
      {
        Write-Warning 'A Client ID is required! See https://api-docs.igdb.com/ for how to retrieve one.'
        exit
      }

      [SecureString]$SecureSecret = Read-Host 'Client Secret' -AsSecureString

      if ($SecureSecret.Length -eq 0)
      {
        Write-Warning 'A Client Secret is required! See https://api-docs.igdb.com/ for how to retrieve one.'
        exit
      }

      $TempConfig = @{
        ClientID     = $ClientID
        ClientSecret = $SecureSecret | ConvertFrom-SecureString
      }

      if ($Persistent)
      {
        # Create the file first using New-Item with -Force parameter so missing directories are also created.
        New-Item -Path $script:ConfigFileName -ItemType "file" -Force | Out-Null

        # Output the config to the recently created file
        $TempConfig | ConvertTo-Json | Out-File $script:ConfigFileName
      }

      # Convert the hashed password back to a SecureString
      if ($SecureSecret.Length -gt 0)
      { $TempConfig.ClientSecret = $SecureSecret }
    }

    $script:Config = @{
      AuthURL      = 'https://id.twitch.tv/oauth2/'
      BaseURL      = 'https://api.igdb.com/v4/'
      ClientID     = $TempConfig.ClientID
      TokenType    = [TokenType]::None
      AccessToken  = ''
      ExpiresIn    = '' # seconds
      Persistent   = $Persistent
    }

    # Authenticated login
    $PlainSecret = $null

    $BSTR        = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($TempConfig.ClientSecret)
    $PlainSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $Body = [ordered]@{
      client_id     = $TempConfig.ClientID
      client_secret = $PlainSecret
      grant_type    = 'client_credentials'
    }

    if ($Response = Invoke-IGDBApiRequest -Uri $script:Config.AuthURL -Endpoint 'token' -Body $Body -Method POST -IgnoreDisconnect -NoAuthentication -SessionVariable global:IGDBSession)
    {
      if ($Response.'token_type' -eq 'bearer')
      {
        $script:Config.TokenType   = [TokenType]::Bearer
        $script:Config.AccessToken = $Response.'access_token'
        $script:Config.ExpiresIn   = $Response.'expires_in'
      }
    }
  }

  Process { }

  End
  {
    $SecureSecret = $null
    $PlainSecret  = $null
    $TempConfig   = $null

    if ($BSTR)
    { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR) }

    if (-not $Silent)
    {

    }
  }
}
#endregion

#region Confirm-IGDBSession
function Confirm-IGDBSession
{
  [CmdletBinding()]
  param (
    <#
      Debug
    #>
    [switch]$JSON
  )

  Begin { }

  Process { }

  End
  {
    if ($null -eq $script:Config.BaseURL)
    { return $null }

    $Body = @{}

    $Response = Invoke-IGDBApiRequest -Uri $script:Config.AuthURL -Endpoint 'validate' -Body $Body -Method GET -IgnoreDisconnect -SessionVariable global:IGDBSession

    if ($Response)
    {
      if ($null -ne $Response.'expires_in')
      {
        Write-Host ('Access token is valid and set to expire on ' + (Get-Date).AddSeconds(5200956).ToString() )
      } else {
        Write-Warning 'Access token is invalid!'
      }
    }

    if ($JSON)
    { return $Response }

    return $null
  }
}
#endregion

#region Disconnect-IGDBSession
Set-Alias -Name Remove-IGDBSession -Value Disconnect-IGDBSession
function Disconnect-IGDBSession
{
  [CmdletBinding()]
  param (
    <#
      Debug
    #>
    [switch]$JSON
  )

  Begin { }

  Process { }

  End
  {
    if ($null -eq $script:Config.BaseURL)
    { return $null }

    $Body = [ordered]@{
      client_id = $script:Config.ClientID
      token     = $script:Config.AccessToken
    }

    $Response = Invoke-IGDBApiRequest -Uri $script:Config.AuthURL -Endpoint 'revoke' -Body $Body -Method POST -IgnoreDisconnect -SessionVariable global:IGDBSession

    Clear-IGDBSession

    if ($JSON)
    { return $Response }

    return $null
  }
}
#endregion

#region Get-IGDBSession
function Get-IGDBSession
{
  <#
  .SYNOPSIS
    Retrieves data about the established IGDB API session.

  .INPUTS
    None.

  .OUTPUTS
    Returns the session variable for the active connection.
  #>
  [CmdletBinding()]
  param ( )

  Begin { }

  Process
  {
    if ($null -eq $global:IGDBSession)
    { Write-Verbose "There is no active IGDB session! Please use Connect-IGDBSession to sign in to the IGDB API." }

    return $global:IGDBSession
  }

  End { }
}
#endregion

#region Invoke-IGDBApiContinueRequest
# Helper function to loop over and retrieve all available results
function Invoke-IGDBApiContinueRequest
{
# TODO: Rework to be appropriate for IGDB since it's currently a straight copy from the MediaWiki original one
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    $Body,

    [ValidateSet('GET', 'POST')]
    $Method,

    [int32]$ResultSize = 0,

    $Uri = ($script:Config.BaseURL)
  )

  Begin
  {
    $ArrJSON = @()
  }

  Process 
  {
    $Request = $Body

    do
    {
      $Response = Invoke-IGDBApiRequest -Body $Request -Method $Method
      $ArrJSON += $Response

      # Break when we have hit the desired amount
      if ($ResultSize -gt 0)
      {
        if ($ArrJSON.Count -ge $ResultSize)
        {
          $MoreAvailable = $true
          Write-IGDBWarningResultSize -InputObject $MoreAvailable -DefaultSize 500 -ResultSize $ResultSize
          break
        }
      }

      #$Response | ConvertTo-Json -Depth 10 | Out-File '.\json.json' -Append

      # Continue can sometimes include another element (e.g. dfcontinue instead of gaicontinue)
      # so we need to reset the request and carry the whole continue array over...
      $Request = $Body

      if ($null -ne $Response.('continue'))
      {
        # Some continue values, e.g. offsets, might already be present in the original
        # so we need to remove any of those from the object first...
        ForEach ($Object in $Response.('continue').GetEnumerator())
        { $Request.Remove($Object.Name) }

        # Add the new continue values over
        $Request += $Response.('continue')
      }
    } while ($null -ne $Response.('continue'))
  }

  End
  {
    return $ArrJSON
  }
}

#endregion

#region Invoke-IGDBApiRequest
function Invoke-IGDBApiRequest
{
  [CmdletBinding(DefaultParameterSetName = 'WebSession')]
  param (
    [Parameter(Mandatory, Position=0)]
    $Body,

    [ValidateSet('GET', 'POST')]
    [Parameter(Mandatory, Position=1)]
    $Method,

    [string]$Uri = ($script:Config.BaseURL),

    [Parameter(Mandatory, Position=1)]
    [string]$Endpoint,

    [int32]$RateLimit = 60, # In seconds

    # Used by pretty much all cmdlets
    [Parameter(ParameterSetName = 'WebSession')]
    [Microsoft.PowerShell.Commands.WebRequestSession]
    $WebSession,

    # Used by Connect-IGDBSession
    [Parameter(ParameterSetName = 'SessionVariable')]
    [string]
    $SessionVariable,

    # Used by Disconnect-IGDBSession and Get-IGDBToken to not renew an expired CSRF/edit token
    [switch]$IgnoreDisconnect,
    # Used by Disconnect-IGDBSession and Connect-IGDBSession to suppress adding asserings to the calls
    [switch]$NoAuthentication,

    # Used to export errors/warnings to a JSON file
    [switch]$WriteIssuesToDisk
  )

  Begin { }

  Process
  {
    $Headers = $null

    # Insert any necessary authorization
    if (-not $NoAuthentication)
    {
      $Headers = @{
        'Client-ID'     =  $script:Config.ClientID
        'Authorization' = ($script:Config.TokenType.ToString() + " " + $script:Config.AccessToken)
      }
    }

    $Attempt    = 0 # Max three attempts before aborting
    $JsonObject = $null
    $Retry      = $false

    do {
      # Reset every loop
      $Retry   = $false

      $RequestParams = @{
        Body         = $Body
        Uri          = ($Uri + $Endpoint)
        Method       = $Method
      }

      if ($null -ne $Headers)
      {
        $RequestParams.Headers = $Headers
      }

      if ($PSBoundParameters.ContainsKey('SessionVariable'))
      {
        $RequestParams   += @{
          SessionVariable = $SessionVariable
        }
      } elseif ($WebSession) {
        $RequestParams   += @{
          WebSession      = $WebSession
        }
      } else {
        $RequestParams   += @{
          WebSession      = Get-IGDBSession
        }
      }

      if (-not [string]::IsNullOrWhiteSpace($ContentType))
      {
        $RequestParams   += @{
          ContentType     = $ContentType
        }
      }

      Write-Debug ($RequestParams | ConvertTo-Json -Depth 10)
      $Response = Invoke-WebRequest @RequestParams

      # Built-in : ConvertFrom-Json
      # Custom   : ConvertFrom-JsonToHashtable
      if ($Response.Content -is [System.Byte[]])
      {
        return $Response
      }
      elseif ($JsonObject = ConvertFrom-JsonToHashtable $Response.Content)
      {
        $RateLimited  = $false
        $Disconnected = $false

        if ($Disconnected -and $IgnoreDisconnect -eq $false)
        {
          # Create a local copy as Disconnect-IGDBSession will clear the original copy
          #$LocalCopy = $script:Config | Copy-Object

          $Retry = $true

          $ReconParams = @{
            Persistent = $script:Config.Persistent
          }

          if ($script:Config.Persistent)
          { Write-Warning 'The session has expired and is automatically being refreshed...' }
          else
          { Write-Warning 'The session has expired! Please sign in to continue, or press Ctrl + Z to abort.' }

          Disconnect-IGDBSession
          Connect-IGDBSession @ReconParams
        }

        if ($RateLimited)
        {
          $Retry = $true
          Write-Warning "Pausing execution to adhere to the rate limit."
          Start-Sleep -Seconds ($RateLimit + 5)
        }
      }
    } while ($Retry -and ++$Attempt -lt 3)

    if ($Attempt -eq 3)
    { Write-Warning 'Aborted after three failed attempt at retrying the request.' }

    return $JsonObject
  }

  End { }
}
#endregion

# This command exports all the functions and aliases defined in the script module.
Export-ModuleMember -Function * -Alias *
































# --------------------------------------------------------------------------------------- #
#                                                                                         #
#                                     DYNAMIC CMDLETs                                     #
#                                                                                         #
# --------------------------------------------------------------------------------------- #

# The recognized endpoints and which function they will map to.
# The second parameter indicates if the endpoint is searchable or not.
$script:EndpointFunctions = @{
  age_rating_categories                  = @('Get-IGDBAgeRatingCategory')
  age_rating_content_description_types   = @('Get-IGDBAgeRatingContentDescriptionType')
  age_rating_content_descriptions        = @('Get-IGDBAgeRatingContentDescription') # Deprecated
  age_rating_content_descriptions_v2     = @('Get-IGDBAgeRatingContentDescriptionV2')
  age_rating_organizations               = @('Get-IGDBAgeRatingOrganization')
  age_ratings                            = @('Get-IGDBAgeRating')
  alternative_names                      = @('Get-IGDBAlternativeName')
  artwork_types                          = @('Get-IGDBArtworkType')
  artworks                               = @('Get-IGDBArtwork')
  characters                             = @('Get-IGDBCharacter', $true)
  character_genders                      = @('Get-IGDBCharacterGender')
  character_mug_shots                    = @('Get-IGDBCharacterMugShot')
  character_species                      = @('Get-IGDBCharacterSpecies')
  collections                            = @('Get-IGDBCollection', $true)
  collection_membership_types            = @('Get-IGDBCollectionMembershipType')
  collection_memberships                 = @('Get-IGDBCollectionMembership')
  collection_relation_types              = @('Get-IGDBCollectionRelationType')
  collection_relations                   = @('Get-IGDBCollectionRelation')
  collection_types                       = @('Get-IGDBCollectionType')
  companies                              = @('Get-IGDBCompany')
  company_logos                          = @('Get-IGDBCompanyLogo')
  company_statuses                       = @('Get-IGDBCompanyStatus')
  company_websites                       = @('Get-IGDBCompanyWebsite')
  covers                                 = @('Get-IGDBCover')
  date_formats                           = @('Get-IGDBDateFormat')
  events                                 = @('Get-IGDBEvent')
  event_logos                            = @('Get-IGDBEventLogo')
  event_networks                         = @('Get-IGDBEventNetwork')
  external_game_sources                  = @('Get-IGDBExternalGameSource')
  external_games                         = @('Get-IGDBExternalGame')
  franchises                             = @('Get-IGDBFranchise')
  games                                  = @('Get-IGDBGame', $true)
 'games/count'                           = @('Get-IGDBGameCount')
  game_engine_logos                      = @('Get-IGDBGameEngineLogo')
  game_engines                           = @('Get-IGDBGameEngine')
  game_localizations                     = @('Get-IGDBGameLocalization')
  game_modes                             = @('Get-IGDBGameMode')
  game_release_formats                   = @('Get-IGDBGameReleaseFormat')
  game_statuses                          = @('Get-IGDBGameStatus')
  game_time_to_beats                     = @('Get-IGDBGameTimeToBeat')
  game_types                             = @('Get-IGDBGameType')
  game_version_feature_values            = @('Get-IGDBGameVersionFeatureValue')
  game_version_features                  = @('Get-IGDBGameVersionFeature')
  game_versions                          = @('Get-IGDBGameVersion')
  game_videos                            = @('Get-IGDBGameVideo')
  genres                                 = @('Get-IGDBGenre')
  involved_companies                     = @('Get-IGDBInvolvedCompany')
  keywords                               = @('Get-IGDBKeyword')
  languages                              = @('Get-IGDBLanguage')
  language_support_types                 = @('Get-IGDBLanguageSupportType')
  language_supports                      = @('Get-IGDBLanguageSupport')
  multiplayer_modes                      = @('Get-IGDBMultiplayerMode')
  network_types                          = @('Get-IGDBNetworkType')
  platforms                              = @('Get-IGDBPlatform', $true)
  platform_families                      = @('Get-IGDBPlatformFamily')
  platform_logos                         = @('Get-IGDBPlatformLogo')
  platform_types                         = @('Get-IGDBPlatformType')
  platform_version_companies             = @('Get-IGDBPlatformVersionCompany')
  platform_version_release_dates         = @('Get-IGDBPlatformVersionReleaseDate')
  platform_versions                      = @('Get-IGDBPlatformVersion')
  platform_websites                      = @('Get-IGDBPlatformWebsite')
  player_perspectives                    = @('Get-IGDBPlayerPerspective')
  popularity_primitives                  = @('Get-IGDBPopularityPrimitives')
  popularity_types                       = @('Get-IGDBPopularityType')
  regions                                = @('Get-IGDBRegion')
  release_dates                          = @('Get-IGDBReleaseDate')
  release_date_regions                   = @('Get-IGDBReleaseDateRegion')
  release_date_statuses                  = @('Get-IGDBReleaseDateStatus')
  screenshots                            = @('Get-IGDBScreenshot')
  search                                 = @('Search-IGDB', $true)
  themes                                 = @('Get-IGDBTheme', $true)
  websites                               = @('Get-IGDBWebsite')
  website_types                          = @('Get-IGDBWebsiteType')
}

# Let us now define our dynamic functions
function Register-DynamicFunctions
{
  foreach ($Endpoint in $script:EndpointFunctions.Keys)
  {
    $Function      = $script:EndpointFunctions.$Endpoint
    $FunctionName  = $Function[0]

    $WherePosition = '0'
    $Searchable    = ''

    if ($Function[1] -eq $true)
    {
      $WherePosition = '1'
      $Searchable = @"
    [Parameter(ValueFromPipelineByPropertyName, Position=0)]
    [string]`$Search, # Search
"@
    }

    $Expression = @"
function $FunctionName
{
  [CmdletBinding()]
  param (

    $Searchable

    [Parameter(ValueFromPipelineByPropertyName, Position=$WherePosition)]
    [Alias('Filters')]
    [string]`$Where, # The conditions for the query, corresponding to an SQL WHERE clause

    [Parameter(ValueFromPipelineByPropertyName)]
    [AllowEmptyString()]
    [string[]]`$Fields = '', # The table field(s) to retrieve

    [Parameter(ValueFromPipelineByPropertyName)]
    [string]`$OrderBy, # The order of results, corresponding to an SQL ORDER BY clause

    [Parameter(ValueFromPipelineByPropertyName)]
    [uint32]`$Offset, # The query offset. The value must be no less than 0.

    [Parameter(ValueFromPipelineByPropertyName)]
    [Alias('ResultSize')]
    [ValidateScript({ Test-IGDBResultSize -InputObject `$PSItem })]
    [string]`$Limit # A limit on the number of results returned, corresponding to an SQL LIMIT clause
  )

  Begin { }

  Process { }

  End
  {
    if (`$null -eq `$script:Config.BaseURL)
    { return `$null }

    `$Body = ''

    if ([string]::IsNullOrWhiteSpace(`$Fields))
    { `$Fields = '*' }

    if (`$Fields.Count -gt 1)
    { `$Fields = `$Fields -join ','}

    `$Body += "fields `$Fields;"

    if (-not [string]::IsNullOrWhiteSpace(`$Search))
    { `$Body += "search ```"`$Search```";" }

    if (-not [string]::IsNullOrWhiteSpace(`$Where))
    { `$Body += "where `$Where;" }

    if (-not [string]::IsNullOrWhiteSpace(`$OrderBy))
    { `$Body += "sort `$OrderBy;" }

    if (-not [string]::IsNullOrWhiteSpace(`$Limit))
    { `$Body += "limit `$Limit;" }

    if (-not [string]::IsNullOrWhiteSpace(`$Offset))
    { `$Body += "offset `$Offset;" }

    `$Response = Invoke-IGDBApiRequest -Uri `$script:Config.BaseURL -Endpoint '$Endpoint' -Body `$Body -Method POST -IgnoreDisconnect -SessionVariable global:IGDBSession

    return `$Response
  }
}
"@

    Invoke-Expression -Command $Expression
    Export-ModuleMember -Function $FunctionName
  }
}

. Register-DynamicFunctions