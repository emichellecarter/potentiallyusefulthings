<#
.SYNOPSIS
    This script pulls the unique publishers of VMs from all subscriptions or one resource group within a subscription.
.PARAMETER ResourceGroupName
    The name of the Resource Group to run the script against.

.EXAMPLE
Get-Publishers -ResourceGroupName 'MyResourceGroup'

#>

Function Get-Publishers
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [String] $ResourceGroupName
    )
    if (([string]::IsNullOrEmpty($ResourceGroupName))){
        $table = New-Object System.Data.DataTable
        $table.Columns.Add("Publisher",[string]) | Out-Null 
        $subscriptions = Get-AzSubscription
        foreach ($subscription in $subscriptions){
            Set-AzContext -SubscriptionObject $subscription
               $publisher = (Get-AzVM).StorageProfile.ImageReference.Publisher
                foreach ($p in $publisher) {
                    if ($p -ne $null){
                    $table.Rows.Add($p) | Out-Null
                    }
                }   
        }
        $table | Select-Object Publisher -Unique
    }
    else{
        $table = New-Object System.Data.DataTable
        $table.Columns.Add("Publisher",[string]) | Out-Null
        $publisher = (Get-AzVM -ResourceGroupName $ResourceGroupName).StorageProfile.ImageReference.Publisher
            foreach ($p in $publisher) {
                  $table.Rows.Add($p) | Out-Null
            }
        $table | Select-Object Publisher -Unique
    } 
}
