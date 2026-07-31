#For use with sutomation accounts
param(
    [Parameter(Mandatory = $false)]
    [String] $resourceGroupName
)
try
{
    "Logging in to Azure..."
    Connect-AzAccount -EnvironmentName AzureUSGovernment -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
$Subscriptions = Get-AzSubscription
foreach ($Subscription in $Subscriptions) {
    Set-AzContext -SubscriptionObject $Subscription
if(([string]::IsNullOrEmpty($resourceGroupName)))
    {
        $pools=get-azwvdhostpool
    }
else
    {
        $pools=get-azwvdhostpool -ResourceGroupName $resourceGroupName 
    }
foreach ($pool in $pools)
        {
            $poolRg = $Pool.Id.split('/')[4]
            $hostpool = $pool.Name
            $sessionHosts = Get-AzWvdSessionHost -HostPoolName $Pool.Name -ResourceGroupName $poolRg | Where-Object {($_.status -eq "Available") -or ($_.AllowNewSession -eq $False)-and ($_.Session -eq 0)}
            if ($sessionHosts.count -gt 0){
                $throttle = 5
                if ($sessionHosts.count -gt 10)
                {
                    $throttle = $([math]::Ceiling($sessionHosts.count / 2))
                }
                $sessionHosts | ForEach-Object -ThrottleLimit $throttle -parallel {
                $Name = $_.Name.split('/')[1]
                    if ($_.AllowNewSession -eq $False){
                        Update-AzWvdSessionHost -ResourceGroupName $using:poolRg -HostPoolName $using:hostpool -Name $Name -AllowNewSession:$True
                    }
                    if ($_.Status -eq "Available"){
                        Stop-AzVM -Id $_.ResourceId -Force
                    }
                }
            }
        }
 }
