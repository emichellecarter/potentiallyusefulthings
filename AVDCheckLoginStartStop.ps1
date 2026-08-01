<#
.SYNOPSIS
    Script to stop AVD pools and set drain mode to off when there are no active sessions.   

.DESCRIPTION
    The script does not have powershell azure logon so must be done first. The script can be run on a schedule or on demand.  
    It takes an optional parameter for a resource group or can be run on all AVDs.  The script must be run using PowerShell version 7 as it utilizes parallelism 
    to open mulitple threads for powershell loop executions through. Skips AVD when someone is logged in.

.PARAMETER SubscriptionName (string)
    This parameter is optional. This is the subscription the resource groups are to limit the script execution against exist.

.PARAMETER ResourceGroupNames (string[])
    This parameter is optional. This is the Resource Group list to limit the script execution against.

.PARAMETER DrainMode (string)
    This parameter is optional. This is the Drain mode to set the pools for which the script is executed against.  Must pass in "Yes" or "No"
    This parameter can be used to reset the drain mode on machine that are all available as well as unavailable in a resource group.

#>
param(
    [CmdletBinding()]
    [Parameter(Mandatory = $false)]
    [string] 
    $SubscriptionName,

    [Parameter(Mandatory = $false)]
    [string[]] 
    $ResourceGroupNames,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Yes", "No")]
    [string] 
    $DrainMode
)

if (([string]::IsNullOrEmpty($ResourceGroupNames)))
{
    $subscriptions = Get-AzSubscription
    foreach ($subscription in $subscriptions)
    {
        Set-AzContext -SubscriptionObject $subscription
        $pools=get-azwvdhostpool
        foreach ($pool in $pools)
        {
            $poolRg = $pool.Id.split('/')[4]
            $hostpool = $pool.Name
            $sessionHosts = Get-AzWvdSessionHost -HostPoolName $hostpool -ResourceGroupName $poolRg | Where-Object {($_.Session -eq 0)}
            switch($sessionHosts.count)
            {
                { $_.count -gt 0 } { $throttle = 5 }
                { $_.count -gt 10 } { $throttle = $([math]::Ceiling($sessionHosts.count / 2)) }
                { $_.count -gt 30 } { $throttle = $([math]::Ceiling($sessionHosts.count / 3)) }
            }
            $sessionHosts | ForEach-Object -ThrottleLimit $throttle -parallel {
                if ([String]::IsNullOrEmpty($using:DrainMode))
                {
                    $drainMode = $_.AllowNewSession
                }
                else
                {
                    $drainMode = if ($using:DrainMode -eq 'No') 
                    { 
                        $true 
                    } 
                    else 
                    { 
                        $false 
                    }
                }
                $vmName = $_.resourceid.split('/')[-1]
                $sessionName = $_.Name.split('/')[1]
                $subscriptionId = $_.ResourceId.split('/')[2]
                $status = Get-AzVM -Name $vmName -ResourceGroupName $using:poolRg -Status
                $login = $null
                if ($status.Statuses[1].Code -eq 'PowerState/running')
                {
                    $hostStatus = Invoke-AzVMRunCommand -ResourceId $_.ResourceId -CommandId 'RunPowerShellScript' -ScriptString 'query user'
                    $login=$hostStatus.Value[0].message | Select-String -Pattern 'Active' -CaseSensitive -SimpleMatch
                    if ($login.Line -ne $null)
                    {
                        Write-Output "Host $vmName has active sessions and will not be altered.  Skipping..."
                        Continue
                    }
                    else
                    {
                        Write-Output "Shutting Down $vmName and setting any drain mode changes requested"
                        Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $sessionName -SubscriptionId $subscriptionId -AllowNewSession:$drainMode
                        Stop-AzVM -Id $_.ResourceId -Force
                    }
                }
                else
                {   
                    Write-Output "Setting Drain mode changes $vmName requested"
                    Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $sessionName -SubscriptionId $subscriptionId -AllowNewSession:$drainMode

                }
            }
        }
    }  
}
else
{
    $subscriptions = Get-AzSubscription -SubscriptionName $SubscriptionName
    foreach ($subscription in $subscriptions)
    {
    Set-AzContext -SubscriptionObject $subscription
        foreach ($resourceGroupName in $ResourceGroupNames)
        {
            $pools=get-azwvdhostpool -ResourceGroupName $resourceGroupName 
            foreach ($pool in $pools)
            {
                $poolRg = $pool.Id.split('/')[4]
                $hostpool = $pool.Name
                $sessionHosts = Get-AzWvdSessionHost -HostPoolName $hostpool -ResourceGroupName $poolRg | Where-Object {($_.Session -eq 0)}
                switch($sessionHosts.count)
                {
                    { $_.count -gt 0 } { $throttle = 5 }
                    { $_.count -gt 10 } { $throttle = $([math]::Ceiling($sessionHosts.count / 2)) }
                    { $_.count -gt 30 } { $throttle = $([math]::Ceiling($sessionHosts.count / 3)) }
                }
                $sessionHosts | ForEach-Object -ThrottleLimit $throttle -parallel {
                    if ([String]::IsNullOrEmpty($using:DrainMode))
                    {
                        $drainMode = $_.AllowNewSession
                    }
                    else
                    {
                        $drainMode = if ($using:DrainMode -eq 'No') 
                        { 
                            $true 
                        } 
                        else 
                        { 
                            $false 
                        }
                    }
                    $vmName = $_.resourceid.split('/')[-1]
                    $sessionName = $_.Name.split('/')[1]
                    $subscriptionId = $_.ResourceId.split('/')[2]
                    $status = Get-AzVM -Name $vmName -ResourceGroupName $using:poolRg -Status
                    $login = $null
                    if ($status.Statuses[1].Code -eq 'PowerState/running')
                    {
                        $hostStatus = Invoke-AzVMRunCommand -ResourceId $_.ResourceId -CommandId 'RunPowerShellScript' -ScriptString 'query user'
                        $login=$hostStatus.Value[0].message | Select-String -Pattern 'Active' -CaseSensitive -SimpleMatch
                        if ($login.Line -ne $null)
                        {
                            Write-Output "Host $vmName has active sessions and will not be altered.  Skipping..."
                            Continue
                        }
                        else
                        {
                            Write-Output "Shutting Down $vmName and setting any drain mode changes requested"
                            Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $sessionName -SubscriptionId $subscriptionId -AllowNewSession:$drainMode
                            Stop-AzVM -Id $_.ResourceId -Force
                        }
                    }
                    else
                    {   
                        Write-Output "Setting Drain mode changes $vmName requested"
                        Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $sessionName -SubscriptionId $subscriptionId -AllowNewSession:$drainMode

                    }
                }
            }
        }
    }
}
