<#
.SYNOPSIS
    Script to start AVD pools and set drain mode to parameter passed for drainmode when there are no active sessions.   

.DESCRIPTION
    The script uses the automation account system identity for authentication and authorization. It can be run on a schedule or on demand.  
    It takes an option parameter for a resource group or can be run on all AVDs.  The script must be run using PowerShell version 7 as it utilizes parallelism 
    to open mulitple threads for powershell loop executions through.

.PARAMETER ResourceGroupNames (String[])
    This parameter is optional. This is the Resource Group to limit the script execution against.

.PARAMETER DrainMode (bool)
    This parameter is optional. This is the Drain mode to set the pools for which the script is executed against.
    This parameter can be used to reset the drain mode on machine that are all available as well as unavailable in a resource group.

#>
param(
    [Parameter(Mandatory = $false)]
    [String[]] $ResourceGroupNames,
    [Parameter(Mandatory = $false)]
    [bool] $DrainMode
)
try {
    "Logging in to Azure..."
    Connect-AzAccount -EnvironmentName AzureUSGovernment -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
    $subscriptions = Get-AzSubscription
        foreach ($subscription in $subscriptions){
            Set-AzContext -SubscriptionObject $subscription
            #Set the drain mode to false if not specified
            $drainMode = $DrainMode ??= $False
                if (([string]::IsNullOrEmpty($ResourceGroupNames))){
                    $pools=get-azwvdhostpool
                        foreach ($pool in $pools){
                            $poolRg = $pool.Id.split('/')[4]
                            $hostpool = $pool.Name
                            $sessionHosts = Get-AzWvdSessionHost -HostPoolName $hostpool -ResourceGroupName $poolRg | Where-Object {($_.Session -eq 0)}
                            switch($sessionHosts.count){
                                { $_.count -gt 0} { $throttle = 5 }
                                { $_.count -gt 10 } { $throttle = $([math]::Ceiling($sessionHosts.count / 2)) }
                                { $_.count -gt 30 } { $throttle = $([math]::Ceiling($sessionHosts.count / 3)) }
                            }
                                $sessionHosts | ForEach-Object -ThrottleLimit $throttle -parallel {
                                $Name = $_.Name.split('/')[1]
                                Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $Name -AllowNewSession:$using:drainMode
                                if ($_.Status -eq "Unavailable"){
                                        Start-AzVM -Id $_.ResourceId
                                }
                            }
                        }
                }
                else {
                    foreach ($resourceGroupName in $ResourceGroupNames){
                        $pools=get-azwvdhostpool -ResourceGroupName $resourceGroupName 
                            foreach ($pool in $pools){
                                $poolRg = $pool.Id.split('/')[4]
                                $hostpool = $pool.Name
                                $sessionHosts = Get-AzWvdSessionHost -HostPoolName $hostpool -ResourceGroupName $poolRg | Where-Object {($_.status -eq "Unavailable") -and ($_.Session -eq 0)}
                                switch($sessionHosts.count){
                                    { $_.count -gt 0} { $throttle = 5 }
                                    { $_.count -gt 10 } { $throttle = $([math]::Ceiling($sessionHosts.count / 2)) }
                                    { $_.count -gt 30 } { $throttle = $([math]::Ceiling($sessionHosts.count / 3)) }
                                }
                                    $sessionHosts | ForEach-Object -ThrottleLimit $throttle -parallel {
                                    $Name = $_.Name.split('/')[1]
                                    Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $Name -AllowNewSession:$using:drainMode
                                    if ($_.Status -eq "Unavailable"){
                                            Start-AzVM -Id $_.ResourceId
                                    }
                                }
                            }
                        }
                }   
        }     
