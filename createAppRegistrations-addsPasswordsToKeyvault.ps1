<#
.SYNOPSIS 
  Creates an array of new application registrations, adds a named password, and adds the password and secret id to a keyvault.  Also will create a new secret for an existing 
  application registration and updates the secret and secret id in the key vault specified.

.DESCRIPTION
  Creates an array of new application registrations, adds a named password, and adds the password and secret id to a keyvault.  Also will create a new secret for an existing 
  application registration and updates the secret and secret id in the key vault specified.

.PARAMETER SpNames
  An array of names for the new application registrations to be created.

.PARAMETER KeyVaultName
  The name of the keyvault to add the secrets to.

.PARAMETER DaysUntilExpiration
  The number of days until the password and secret id expire.

.EXAMPLE
$params = @{
  SpNames = ('servicePrinName1', 'servicePrinName2')
  KeyVaultName = 'MyKeyvault'
  DaysUntilExpiration  = 365
}
#>

Function New-AppRegAndPassword {
  param(
  [CmdletBinding()]
  [Parameter(Mandatory=$true)]
  [string[]]
  $SpNames, 
  [Parameter(Mandatory=$true)]
  [string]
  $KeyVaultName,
  [Parameter(Mandatory=$true)]
  [int]
  $DaysUntilExpiration
  )
  $startDate = get-date
  $endDate = (get-date).AddDays($DaysUntilExpiration)
  
  foreach ($SpName in $SpNames){
    
    $sp = Get-AzADServicePrincipal -DisplayName $SpName -ErrorAction 'SilentlyContinue'
    if (-Not $sp){
      write-output "Creating service principal for $SpName"
      $newSP = New-AzADServicePrincipal -DisplayName $SpName -ErrorAction 'Stop'
      if (-not $newSP){
        throw "Failed to create service principal for $SpName"
      }
      else{
        #Wait for the application to be created or timeout after 90 seconds
        do{
          $timer = [Diagnostics.Stopwatch]::StartNew()
          $appid = Get-AzADApplication -ApplicationId $newSp.AppId -ErrorAction 'SilentlyContinue'
          write-output "Waiting for application to be created"
          start-sleep 5
        } Until (($null -ne $appid) -or ($timer.Elapsed.TotalSeconds -gt 90))
        if ($timer.Elapsed.TotalSeconds -gt 90){
          throw "Failed to create application for $SpName or the application took longer than 90 seconds to create."
        }
        $timer.Stop()
      } 
    }

      -Force

    write-output "Creating password for $SpName"
    $passwordparams = @{
      DisplayName =  $($sp.DisplayName)
      StartDateTime = $startDate
      EndDateTime = $endDate
    }

    #Create the password
    $pass = Get-AzADApplication -ApplicationId $newSp.AppId | New-AzADAppCredential -PasswordCredentials $passwordparams
    if (-not $pass){
      throw "Failed to create password for $SpName"
    }
    else{
      $securePassword = ConvertTo-SecureString -String $pass.SecretText -AsPlainText -Force
      $encryptedKeyId = ConvertTo-SecureString -String $pass.KeyId -AsPlainText -Force
    }
    
    #Add secrets to the keyvault
    $keyVault = Get-AzKeyVault -VaultName $KeyVaultName
    if (-not $keyVault){
      throw 'Failed to get keyvault $KeyVaultName'
    }
    else {
      $addPass = Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name "$SpName-AAD-password" -SecretValue $securePassword -Expires $endDate -ErrorAction 'Stop'
      if (-not $addPass){
        throw 'Failed to add password to $KeyVaultName'
      }
      $addSecretId = Set-AzKeyVaultSecret -VaultName $keyVault.VaultName -Name "$SpName-AAD-secretid" -SecretValue $encryptedKeyId -Expires $endDate -ErrorAction 'Stop'
      if (-not $addSecretId){
        throw 'Failed to add secret id to $KeyVaultName'
      }
    }
  }
}
$params = @{
  SpNames = ('spName1', 'spName2')
  KeyVaultName = 'myKeyVaultName'
  DaysUntilExpiration  = 365
}
New-AppRegAndPassword @params
