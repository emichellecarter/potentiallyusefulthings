$requiredModules = @('Az.RecoveryServices', 'Az.Compute', 'Az.Network', 'Az.Storage')
foreach ($module in $requiredModules)
{
    if (-Not (Get-Module -Name $module -ListAvailable))
    {
        Install-Module -Name $module -Force
    }
    Get-InstalledModule -Name $module | Update-Module -Force
}
<#
.SYNOPSIS
 Create snapshots for OS Disks and Data disks based off parameters.

.DESCRIPTION
 This function creates snapshots of disks based off parameters passed to function.
 This function accepts an array of VMs to create snapshots.

.PARAMETER VMResourceGroupName
 Optional paramter 
 The resource group of the virtual machine(s) for which the snapshots will be created.

.PARAMETER VMNames
 Mandatory 
 Array of VMs with which to create the VMs.

.PARAMETER DiskEncryptionSetName
 Mandatory 
 The disk Encryption set attached to the VM.

.EXAMPLE
     $params = @{
        VMResourceGroupName         = 'rgName' 
        VMNames                     = ('VM1', 'VM2')
        DiskEncryptionSetName       = 'desName'
    }
    New-DiskSnap @params
 #>
 Function New-DiskSnap
 {
 param (
     [CmdletBinding()]
     [Parameter(Mandatory=$false)]
     [string]
     $VMResourceGroupName,
 
     [Parameter(Mandatory=$true)]
     [string[]]
     $VMNames,
 
     [Parameter(Mandatory=$true)]
     [string]
     $DiskEncryptionSetName
     )
     
     $des=Get-AzDiskEncryptionSet -Name $DiskEncryptionSetName -ErrorAction 'SilentlyContinue'
     if (-Not $des){
         throw "The disk encryption set $DiskEncryptionSetName does not exist.  Please check the name and try again."
     }
     else 
     {
        foreach ($vmName in $VMNames)
        {
         $date=Get-Date -Format o | ForEach-Object { $vmName -replace ":", "." }
         $vm = Get-AzVM -Name $vmName -ErrorAction 'SilentlyContinue'
         $vm.SecurityProfile.DiskEncryptionSettings.DiskEncryptionSetId
             if (-Not $vm )
             {
             Write-Output "The VM $vmName does not exist.  Snapshot for this VM will not be created."
             Continue
             }
             else
             {
                 if (([string]::IsNullOrEmpty($VMResourceGroupName)))
                 {
                     $VMResourceGroupName = ($vm.Id.split('/')[4]).tolower()
                 }
                     #Snapshot the OS disk
                     $configParams = @{
                         SourceUri           = $vm.StorageProfile.OsDisk.ManagedDisk.Id
                         Location            = $vm.Location
                         CreateOption        = 'copy'
                         DiskEncryptionSetId = $des.id
                     }
                     
                     $params = @{
                         SnapshotName        = "${vmName}-os-$date"
                         ResourceGroupName   = $VMResourceGroupName
                         }
                     $scriptBlock = {
                         param($params, $configParams)     
                         $snapshotConfig =  New-AzSnapshotConfig @configParams
                         $null = New-AzSnapshot -Snapshot $snapshotConfig @params
                     }
                     Write-Output "Creating OS disk snapshot for $vmName"
                     $job=Start-job -ScriptBlock $scriptBlock -ArgumentList $params, $configParams
                     do
                     {
                         Start-Sleep -Seconds 5
                         $status=(Get-Job -Id $job.Id).State
                         Write-Output "Job is $status for $vmName."
                     } while ($status -eq 'Running')
                     if ($status -eq 'Completed')
                     {
                         Write-Output "OS snapshot for $vmName Created."
                     }
                     else 
                     {
                         Write-Error "Error creating new snapshot:`n$($vmName.Exception.Message)" 
                     } 
 
                 #Snapshot the data disks
                 if ($disks = $vm.StorageProfile.DataDisks)
                 {
                     foreach ($disk in $disks)
                     {
                        $diskRG = $vm.StorageProfile.DataDisks.ManagedDisk.id.split('/')[4]
                        $sourceid = (Get-AzDisk -ResourceGroupName $diskRG -DiskName $disk.Name).Id

                        $configParams = @{
                             SourceUri           = $sourceid
                             Location            = $vm.Location 
                             CreateOption        = 'copy' 
                             DiskEncryptionSetId = $des.id
                        }
                        $diskName = $disk.Name
                        $params = @{
                            Snapshot            = $snapshotConfigData
                            SnapshotName        = "${vmName}-$diskName-$date"
                            ResourceGroupName   = $vmResourceGroupName
                        }
                        $scriptBlock = {
                         param($params, $configParams)     
                         $snapshotConfig =  New-AzSnapshotConfig @configParams
                         $null = New-AzSnapshot -Snapshot $snapshotConfig @params
                        }
                         Write-Output "Creating datadisk snapshot for $vmName"
                         $job=Start-job -ScriptBlock $scriptBlock -ArgumentList $params, $configParams
                        do
                        {
                            Start-Sleep -Seconds 5
                            $status=(Get-Job -Id $job.Id).State
                            Write-Output "Job is $status for $vmName."
                        } while ($status -eq 'Running')
                        if ($status -eq 'Completed')
                        {
                            Write-Output "Data Disk snapshot for $vmName Created."
                        }
                        else 
                        {
                            Write-Error "Error creating new snapshot:`n$($vmName.Exception.Message)" 
                        } 
                    }
                }
            }
        }
    }
}

<#
.SYNOPSIS
    This function verifies that backups were successful for a recovery services vault.

.DESCRIPTION
    Allows the user to pass in a recovery services vault to verify all successful backups.
	 
.PARAMETER RecoveryVault
	Parameter string mandatory Recovery Services vault for backup.
	 
.PARAMETER VaultResourceGroupName
	Parameter string mandatory Name of resource group for recovery services vault.
		 
.EXAMPLE
	$params = @{
		RecoveryVault 			= 'vaultName' 
		VaultResourceGroupName 	= 'vaultRG'
	}
	Backup-verify @params

#>
Function Backup-verify
{
   param (
       [CmdletBinding()]
       [Parameter(Mandatory=$true)]
       [string] 
       $RecoveryVault,

       [Parameter(Mandatory=$true)]
       [string] 
       $VaultResourceGroupName
    )	if ( $vault = Get-AzRecoveryServicesVault -ResourceGroupName $VaultResourceGroupName -Name $RecoveryVault )
        {
           $BackupJobs = Get-AzRecoveryServicesBackupJob -VaultId $vault.ID -Status Completed -BackupManagementType AzureVM
           if ($BackupJobs)
           {
               Write-Output "The following backup jobs completed successfully"
               $BackupJobs | Select-Object WorkloadName, StartTime, EndTime, Status
           }
           else
           {
               Write-Output "There are no backups that completed successfully."
           }
       } 
       else
       {
           Write-Output "The recovery services vault $RecoveryVault does not exist in resource group $VaultResourceGroupName"
       }
}

<#
.SYNOPSIS
	This function will create a backup container in a recovery services vault if the user agrees 
	to create one with the default policy if one does not exist.  
	The function will then create a backup. 
 
.DESCRIPTION
	The function creates backups of an array of VMs.  All required rule checks are completed within the script
	with output to the user of any checks that have not passed.  If a backup container has not been created for the 
	VM, then the script requires user interaction to determine whether the script will create a 
	new backup container based off the default policy. Per the documentation, when restoring over an existing VM, the
    parameter TargetResourceGroupName should be avoided, however after testing, the parameter is required to restore over
    when called within a module. The parameter is not required when restoring using a script.
 
.PARAMETER RecoveryVault
	Parameter string mandatory Recovery Services vault for backup.
	 
.PARAMETER VMNames
	Parameter string mandatory Name of VMs to be backed up.
	 
.PARAMETER VaultResourceGroupName
	Parameter string mandatory Name of resource group for recovery services vault.
	 
.PARAMETER VMResourceGroupName
	Parameter string optional Name of resource group for VMs
	 
.PARAMETER DaysToRetain
	Parameter int mandatory Number of days to retain the backups for the VMs specified.
	 
.EXAMPLE
	$params = @{
		RecoveryVault 				= 'vaultName' 
		VaultResourceGroupName 		= 'vaultRG'
		VMNames						= ('VM1', 'VM2')
		#VMResourceGroupName		= 'VMRG'
		DaysToRetain				= 5
	}
	Backup-Vms @params
	 
.NOTES
	The recovery services vault must be in the same location as the virtual machines.  
	This script requires user intervention when backup is not enabled for the virtual machine.
	Backups of virutal machines attached to shared disks is not supported.
	 
#>
Function Backup-Vms
{
 	param (
        [CmdletBinding()]
		[Parameter(Mandatory=$true)]
		[string] 
		$RecoveryVault,

		[Parameter(Mandatory=$true)] 
		[array]  
		$VMNames,
		  
		[Parameter(Mandatory=$true)]
		[string] 
		$VaultResourceGroupName,

		[Parameter(Mandatory=$false)]
		[string] 
		$VMResourceGroupName,

		[Parameter(Mandatory=$true)]
		[int] 	  
		$DaysToRetain
	) 
	foreach ($vmName in $VMNames)
	{
		$date=(Get-date).AddDays($daysToRetain).ToUniversalTime()
		#check to see if the vault exists
		$vault = Get-AzRecoveryServicesVault -ResourceGroupName $VaultResourceGroupName -Name $RecoveryVault -ErrorAction 'SilentlyContinue'
		if (-Not $vault)
		{
			 throw "The recovery vault $RecoveryVault is not available in $VaultResourceGroupName."
		}
		else 
		{ 
			#Check to see if VM exists
			$vm = Get-AzVM -Name $vmName -ErrorAction 'SilentlyContinue' 
			if (-Not $vm)
			{
				Write-Output "The VM $vmName does not exist. Exiting or continuing to the next VM in the list." 
				Continue
			}
			else 
			{
				#Make sure the rsv and the vm are in the same location
				Write-Output "Checking to see if the VM $vmName is in the same location as the recovery services vault $RecoveryVault."
				if ($vm.Location -ne $vault.Location)
				{
					Write-Output "The VM location is not in the same location as the recovery services vault specified."
					Continue	
				}
				else
				{
					#Set the Recovery services vault context
					Set-AzRecoveryServicesVaultContext -Vault $vault
					if (([string]::IsNullOrEmpty($vmResourceGroupName)))
					{
					 	$vmResourceGroupName = ($vm.Id.split('/')[4]).tolower()
					}

					#If the vm exists check for the VM backup container. 
					$params = @{
						BackupManagementType 	= 'AzureVM'
						WorkloadType 			= 'AzureVM'
						VaultId					= $vault.ID
					}
					$item = Get-AzRecoveryServicesBackupItem @params | Where-Object SourceResourceId -eq $vm.Id 
					if(-Not $item){
						throw "There is no backup container for $vmName. Please contact your backup administrator."
					}
					else
					{
						#Get the backup container
						$params = @{
							BackupManagementType 	= 'AzureVM'
							WorkloadType 			= 'AzureVM'
							VaultId					= $vault.ID
						}
						$item = Get-AzRecoveryServicesBackupItem @params | Where-Object SourceResourceId -eq $vm.Id
						#Start the backup
						$recparams = @{
							Item 				= $item
							ExpiryDateTimeUTC 	= $date
							BackupType 			= 'CopyOnlyFull'
						}
						Write-Output "Creating a backup for $vmName.  Please wait..."
						$job = Backup-AzRecoveryServicesBackupItem @recparams -ErrorAction 'SilentlyContinue'
						$t = $host.ui.RawUI.ForegroundColor
						do 
						{
							$status = (Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).Status
							$host.ui.RawUI.ForegroundColor = 'Yellow'
							Write-Progress -Activity 'Backup' -Status $status -PercentComplete -1
							start-sleep -Seconds 30

						} While ( $status -eq "InProgress" )
						$host.ui.RawUI.ForegroundColor = $t

						If ($status -eq "Completed")
						{
							Write-Output "The backup for $vmName was created."
						}  
						else
						{
							Write-Output "The backup for $vmName had an error."
							$errDetails=(Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).ErrorDetails 
							Write-Output $errDetails
						} 
					}					
				}
			}	
		}
	}	
}
<#
.SYNOPSIS
    Script to restore VMs or create a new clone. Script will restore a VM whether it still exist or not.    

.DESCRIPTION
    Script to restore VMs or create a new clone. Script will restore a VM whether it still exist or not.

.PARAMETER RecoveryVault
    This parameter is mandatory. This is the Recovery Vault from which to pull the backup from.

.PARAMETER VMNames
    This parameter is mandatory. String array of VMs to restore.

.PARAMETER VaultResourceGroupName
    This parameter is mandatory. This is the Recovery Vault resource group from which to pull the backup from.

.PARAMETER VMResourceGroupName
    This parameter is conditional. This parameter is required if the VM does not currently exist.  
    If the VM exist, the parameter is optional unless a VM is named the same name in two different resource groups.

.PARAMETER TargetVMResourceGroupName
    This parameter is mandatory. Resource Group to restore or clone the VM.

.PARAMETER DestinationStorageAccount
    This parameter is mandatory. This is the storage account used in the restore process.

.PARAMETER DestinationStorageAccountResourceGroup
    This parameter is mandatory. This is the storage account resource group used in the restore process.

.PARAMETER TargetVirtualNetwork
    This parameter is mandatory. Virtual Network to restore or clone the VM within.

.PARAMETER TargetVirtualNetworkResourceGroup
    This parameter is mandatory. Virtual Network to restore or clone the VM within.

.PARAMETER TargetVirtualNetworkSubnetName
    This parameter is mandatory. Virtual Network Subnet to restore or clone the VM within.

.EXAMPLE
    $params = @{
        RecoveryVault                          = 'vault'
        VMNames                                = ('VM1', 'VM2')
        VaultResourceGroupName                 = 'vaultRG'
        VMResourceGroupName                    = 'VMRG'
        TargetVMResourceGroupName              = 'TargetVMRG'
        DestinationStorageAccount              = 'storageAccount'
        DestinationStorageAccountResourceGroup = 'storageAccountRG'
        TargetVirtualNetwork                   = 'vnet'
        TargetVirtualNetworkResourceGroup      = 'vnet-RG'
        TargetVirtualNetworkSubnetName         = 'vnet-subnet'
        }
    Restore-Vms @params

#>
Function Restore-Vms
{
    param
    (
        [CmdletBinding()]
        [Parameter(Mandatory=$true)]
        [string]
        $RecoveryVault,

        [Parameter(Mandatory=$true)] 
        [string[]]
        $VMNames, 

        [Parameter(Mandatory=$true)]
        [string]
        $VaultResourceGroupName,

        [Parameter(Mandatory=$false)]
        [string]
        $VMResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetVMResourceGroupName,

        [Parameter(Mandatory=$true)]
        [string]
        $DestinationStorageAccount,

        [Parameter(Mandatory=$true)]
        [string]
        $DestinationStorageAccountResourceGroup,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetVirtualNetwork,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetVirtualNetworkResourceGroup,

        [Parameter(Mandatory=$true)]
        [string]
        $TargetVirtualNetworkSubnetName
    )

    $vault = Get-AzRecoveryServicesVault -ResourceGroupName $VaultResourceGroupName -Name $RecoveryVault
	if (-Not $vault)
    {
        throw "The specified vault does not exist."
    }
    else
    {
		foreach ($vmName in $VMNames)
        {
            if (([string]::IsNullOrEmpty($vmResourceGroupName)))
            {
                $vm = Get-AzVM -Name $vmName -ErrorAction 'SilentlyContinue'
                if (-Not $vm) 
                {
                    Write-Output "The VM $vmName does not exist." 
                    Continue
                }
                else
                {
                    if ($vm.Location -ne $vault.Location)
                    {
                        throw "The VM location is not in the same location as the recovery services vault specified.  Exiting script..." 
                    }
                    else
                    {
                        $vmResourceGroupName = ($vm.Id.split('/')[4]).tolower()
                    }
                }
            }

            $backupItem = Get-AzRecoveryServicesBackupItem -BackupManagementType "AzureVM" -WorkloadType "AzureVM" -Name $vmName -VaultId $vault.ID -DeleteState NotDeleted -ErrorAction 'SilentlyContinue'
            if (-Not $backupItem)
            {
                Write-Output "There is no backup item for this VM.  Please create a backup with the backup option and rerun the restore option..."
                Continue 
            }
            else
            {
                $recoveryPoints = Get-AzRecoveryServicesBackupRecoveryPoint -Item $backupItem -VaultId $vault.ID -ErrorAction 'SilentlyContinue'
                if (-Not $recoveryPoints)
                {
                    throw "There are no Recovery Points Available for $vmName."
                }
                else
                {
                    $table = New-Object System.Data.DataTable
                    $table.Columns.Add("RecoveryPointTime",[string]) | Out-Null
                    $table.Columns.Add("RecoveryPointID",[string]) | Out-Null
                    $table.Columns.Add("RecoveryPointType",[string]) | Out-Null
                    $table.Columns.Add("PointID",[int]) | Out-Null
                    $rpt=$recoveryPoints.RecoveryPointTime
                    $i=0
                    foreach($r in $rpt)
                    {
                        $rpi = ($recoveryPoints | Where-Object RecoveryPointTime -eq $r).RecoveryPointId
                        $rptype = ($recoveryPoints | Where-Object RecoveryPointTime -eq $r).BackupType
                        $table.Rows.Add($r,$rpi,$rptype,$i++) | Out-Null
                    }

                    $display = $table | Out-string 
                    Write-Output $display
                    $pointid = Read-Host -prompt "Please Enter a Point ID to select a Recovery Point." 
                    $idrow = $table.select("PointID=$pointid")
                    $id = $idrow.RecoveryPointID
                    $recoveryPoint = Get-AzRecoveryServicesBackupRecoveryPoint -Item $backupItem -VaultId $vault.ID -RecoveryPointId $id
                    $caption = "Restore or Clone"
                    $message = "Would you like to create a clone or restore over $vmName?"
                    $choices = [System.Management.Automation.Host.ChoiceDescription[]] `
                    @("&Clone", "&Restore over VM", "&Exit Script")
                    [int]$defaultChoice = 1
                    $choiceRTN = $host.UI.PromptForChoice($caption, $message,$choices,$defaultChoice)
                    switch($choiceRTN)
                    {
                        0 {
                            Write-Output "Creating Clone for backup $vmName..."
                            $VMExists=Get-AzVM -Name "$vmName-clone" -ResourceGroupName $TargetVMResourceGroupName -ErrorAction 'SilentlyContinue'
                            if (-Not $VMExists)
                            {
                                $Params = @{
                                    RecoveryPoint                   = $recoveryPoint
                                    TargetResourceGroupName         = $TargetVMResourceGroupName
                                    StorageAccountName              = $DestinationStorageAccount
                                    StorageAccountResourceGroupName = $DestinationStorageAccountResourceGroup
                                    TargetVMName                    = "$vmName-clone"
                                    TargetVNetName                  = $TargetVirtualNetwork
                                    TargetVNetResourceGroup         = $TargetVirtualNetworkResourceGroup
                                    TargetSubnetName                = $TargetVirtualNetworkSubnetName
                                    VaultId                         = $vault.ID
                                    VaultLocation                   = $vault.Location
                                }
                                $job = Restore-AzRecoveryServicesBackupItem @Params -ErrorAction 'SilentlyContinue' 
                                $t = $host.ui.RawUI.ForegroundColor
                                do 
                                {
                                    $status = (Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).Status
                                    $host.ui.RawUI.ForegroundColor = 'Yellow'
                                    Write-Output $status 
                                    start-sleep -Seconds 30
                                } While ( $status -eq "InProgress" )
                                $host.ui.RawUI.ForegroundColor = $t

                                If ($status -eq "Completed")
                                {
                                    Write-Output "The clone $vmName-clone was created."
                                }  
                                else
                                {
                                    Write-Output "The clone $vmName-clone was not created."
                                    $errDetails=(Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).ErrorDetails 
                                    Write-Output $errDetails
                                } 
                            }    
                            else
                            {
                                $cloneName = Read-Host -prompt "The $vmName-clone already exists.  Please enter a name for the new clone." 
                                $Params = @{
                                    RecoveryPoint                   = $recoveryPoint
                                    TargetResourceGroupName         = $TargetVMResourceGroupName
                                    StorageAccountName              = $DestinationStorageAccount
                                    StorageAccountResourceGroupName = $DestinationStorageAccountResourceGroup
                                    TargetVMName                    = $cloneName
                                    TargetVNetName                  = $TargetVirtualNetwork
                                    TargetVNetResourceGroup         = $TargetVirtualNetworkResourceGroup
                                    TargetSubnetName                = $TargetVirtualNetworkSubnetName
                                    VaultId                         = $vault.ID
                                    VaultLocation                   = $vault.Location
                                }
                                $job = Restore-AzRecoveryServicesBackupItem @Params -ErrorAction 'SilentlyContinue' 

                                $t = $host.ui.RawUI.ForegroundColor
                                do 
                                {
                                    $status = (Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).Status
                                    $host.ui.RawUI.ForegroundColor = 'Yellow'
                                    Write-Progress -Status $status -Activity 'Creating Clone' -PercentComplete -1
                                    start-sleep -Seconds 30
                                } While ( $status -eq "InProgress" )
                                $host.ui.RawUI.ForegroundColor = $t

                                If ($status -eq "Completed")
                                {
                                    Write-Output "The clone $cloneName was created."
                                }
                                else
                                {
                                    Write-Output "The clone $cloneName was not created."
                                    $errDetails=(Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).ErrorDetails 
                                    Write-Output $errDetails  
                                }  
                            } 
                        }        
                        1 {
                            Write-Output "Restoring VM from backup...."
                            $Params = @{
                                RecoveryPoint                   = $recoveryPoint
                                StorageAccountName              = $DestinationStorageAccount
                                StorageAccountResourceGroupName = $DestinationStorageAccountResourceGroup
                                TargetResourceGroupName         = $vmResourceGroupName
                                VaultId                         = $vault.ID
                                VaultLocation                   = $vault.Location
                            }

                            $job = Restore-AzRecoveryServicesBackupItem @Params -ErrorAction 'SilentlyContinue'

                            $t = $host.ui.RawUI.ForegroundColor
                            do 
                            {
                                $status = (Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).Status
                                $host.ui.RawUI.ForegroundColor = 'Yellow'
                                Write-Progress -Status $status -Activity "Restoring $vmName" -PercentComplete -1
                                start-sleep -Seconds 30
                            } While ( $status -eq "InProgress" )
                            $host.ui.RawUI.ForegroundColor = $t

                            If ($status -eq "Completed")
                            {
                                Write-Output "The VM $vmName was restored."
                            }
                            else
                            {
                                Write-Output "The VM $vmName was not restored."
                                $errDetails=(Get-AzRecoveryServicesBackupJobDetail -Job $job -VaultId $vault.ID).ErrorDetails 
                                Write-Output $errDetails
                            } 
                        }
                        2 {
                            Write-Output "Exiting script..."
                            exit 0 
                        }
                        
                    }        
                } 
            }
        }
    }
}
<#
.SYNOPSIS
    This creates a static menu for this module.

.DESCRIPTION
   Creates static menu for module items.
	 
.PARAMETER Title
	Parameter string default is set to VM Management for this module.
	 
	 
.EXAMPLE
	Show-Menu

#>
function Show-Menu {
    param (
        [CmdletBinding()]
        [string]$Title = 'VM Management'
    )
    Clear-Host
    Write-Host "================ $Title ================"
    
    Write-Host "1: Press '1' to Verify Virtual Machine Backups."
    Write-Host "2: Press '2' to Create Virtual Machine Disk Snapshot/s."
    Write-Host "3: Press '3' to Backup Virtual Machines."
    Write-Host "4: Press '4' to Restore or Clone Virtual Machines."
    Write-Host "5: Press '5' to get the Disk Encryption Settings for a VM."
    Write-Host "6: Press '6' to update the disk encryption settings, size or sku of a for a disk."
    Write-Host "Q: Press 'Q' to quit."

    Write-Host "================ $Title ================"
}
<#
.SYNOPSIS
    This creates a menu for this module.

.DESCRIPTION
   Creates menu for module items.
	 
.EXAMPLE
	Start-Menu

#>

Function Start-Menu {
    Update-AzConfig -DisplayBreakingChangeWarning $false
    #Run the menu function until the user chooses Q to quit
    #Using Out-Host to wait for the output before the menu is shown again.  
    #Without this the menu is somtimes shown before the output of the previous command.
    do
     {
        Show-Menu
        $selection = Read-Host "Please make a selection"
        switch ($selection)
        {
        '1'
        {
            Backup-Verify | Out-Host
        } 
        '2' 
        {
            New-DiskSnap | Out-Host
        } 
        '3' 
        {
            Backup-Vms | Out-Host
        }
        '4' 
        {
            Restore-Vms | Out-Host
        }
        '5' 
        {
            Show-DiskEncryptionSettings | Out-Host
        }
        '6' 
        {
            $sku = Read-Host "Please enter null or the sku for the disk.  The following skus are supported: Standard_LRS, Premium_LRS, StandardSSD_LRS, UltraSSD_LRS"
            $size = Read-Host "Please enter null or the size for the disk.  The size must be greater than the current disk size."
            $des = Read-Host "Please enter null or the disk encryption set name for the disk."
            $desRG = Read-Host "Please enter null or the disk encryption set resource group name for the disk."
            Update-Disk -DiskEncryptionSet $des -DiskEncryptionResourceGroupName $desRG -SkuName $sku -DiskSizeGB $size | Out-Host
        }
        'Q' 
        { 
            exit 0
        }
        }
        pause
     }
     until ($selection -eq 'q')
}
<#
.SYNOPSIS
    This gets the disk encryption settings for a VM.

.DESCRIPTION
   Gets the disk encryption settings for a virtual machine.

.PARAMETER VMName
    Parameter string mandatory Name of VM to get disk encryption settings for.
	 
.EXAMPLE
	$param = @{
	VMName = 'VM1'
}
Show-DiskEncryptionSettings @param

#>
Function Show-DiskEncryptionSettings {
	param(
		[Parameter(Mandatory=$true)]
		[string]$VMName
	)
	#Get the VM and Disk(os and data disks) 
	$vm= Get-AzVM -Name $VMName
	if (-Not $vm) 
	{
		throw "VM $VMName not found"
	}
	else 
	{
		$osDisk = $vm.StorageProfile.OsDisk
		Write-Output "The Current OS Disk Encryption Settings are:"
		$encType= 
			if (([string]::IsNullOrEmpty($osDisk.Encryption.Type)))
			{
				'None'
			} 
			else 
			{
				$data.Encryption.Type
			}
		$encSet= 
			if (([string]::IsNullOrEmpty($osDisk.Encryption.DiskEncryptionSetId)))
			{
				'None'
			} 
			else 
			{
				($osDisk.Encryption.DiskEncryptionSetId.split('/')[8]).tolower()
			}
		$encSetRG= 
			if (([string]::IsNullOrEmpty($osDisk.Encryption.DiskEncryptionSetId)))
			{
				'None'
			} 
			else 
			{
				($osDisk.Encryption.DiskEncryptionSetId.split('/')[4]).tolower()
			}
		Write-Output "Encryption Type: ${encType}"
		Write-Output "Disk Encryption Set: ${encSet}"
		Write-Output "Disk Encryption Set Resource Group: ${encSetRG}"

		$datadisks = $vm.StorageProfile.DataDisks.Name
		if ($datadisks.count -gt 0)
		{
			foreach($datadisk in $datadisks)
			{
				$data = Get-AzDisk -ResourceGroupName $vm.ResourceGroupName -DiskName $datadisk
				$dataEncType= 
					if (([string]::IsNullOrEmpty($data.Encryption.Type)))
					{
						'None'
					} 
					else 
					{
						$data.Encryption.Type
					}
				$dataEncSet= 
					if (([string]::IsNullOrEmpty($data.Encryption.DiskEncryptionSetId)))
					{
						'None'
					} 
					else 
					{
						($data.Encryption.DiskEncryptionSetId.split('/')[8]).tolower()
					}
				$dataEncSetRG= 
					if (([string]::IsNullOrEmpty($data.Encryption.DiskEncryptionSetId)))
					{
						'None'
					} 
					else 
					{
						($data.Encryption.DiskEncryptionSetId.split('/')[4]).tolower()
					}
				Write-Output "The Current Data Disk Encryption Settings for $datadisk are:"
				Write-Output "Encryption Type:" $dataEncType
				Write-Output "Disk Encryption Set:" $dataEncSet
				Write-Output "Disk Encryption Set Resource Group:" $dataEncSetRG
			}
		}
	}
}
<#
.SYNOPSIS
    Function to update the disk encryption settings, size or sku of a for a disk.

.DESCRIPTION
   Allows the user to update a disk encryption settings, size or sku of a for a disk.
   All parameters are optional except for the disk name and resource group name.
   Sku, Size and Disk Encryption Set can be updated at the same time.
   If the disk encryption set is updated, the disk encryption resource group name must be provided.
   If the disk size is updated, the disk size must be greater than the current disk size.
   For the sku, the following skus are supported: Standard_LRS, Premium_LRS, StandardSSD_LRS, UltraSSD_LRS.
   If a sku, size or disk encryption set is not provided, the current value will be used.

.PARAMETER AZDisk
    Parameter string mandatory Name of disk to be updated.

.PARAMETER AZDiskResourceGroupName
    Parameter string mandatory Name of the disk resource group.

.PARAMETER DiskEncryptionSet
    Parameter string optional Name of the disk encryption set to be used.

.PARAMETER DiskEncryptionResourceGroupName
    Parameter string optional Name of the disk encryption set resource group.

.PARAMETER DiskSizeGB
    Parameter string optional Size of the disk in GB.

.PARAMETER SkuName
    Parameter string optional Sku of the disk.

.EXAMPLE
$params = @{
	AZDisk 							= 'VM1'
	AZDiskResourceGroupName 		= 'VMRG'
	DiskSizeGB 						= '8'
    DiskEncryptionSet 				= 'des1'
    DiskEncryptionResourceGroupName = 'desRG'
    SkuName 						= 'Standard_LRS'
}
Update-Disk @params

#>
Function Update-Disk {
    [CmdletBinding()]
	param(
		[Parameter(Mandatory=$false)]
		[string]
		$DiskEncryptionSet,

		[Parameter(Mandatory=$false)]
		[string]
		$DiskEncryptionResourceGroupName,

		[Parameter(Mandatory=$false)]
		[string]
		$DiskSizeGB,

		[Parameter(Mandatory=$false)]
		[string]
		$SkuName,

		[Parameter(Mandatory=$true)]
		[string]
		$AZDisk,

		[Parameter(Mandatory=$true)]
		[string]
		$AZDiskResourceGroupName
	)
	
	#Get the disk
	$disk=Get-AzDisk -Name $AZDisk -ResourceGroupName $AZDiskResourceGroupName
	if (-Not $disk) 
	{
		throw "Disk $AZDisk not found"
	}

	#Check the DES and set the DES if not provided
	if ((! [string]::IsNullOrEmpty($DiskEncryptionSet)))
	{
		$desType = 'EncryptionAtRestWithPlatformAndCustomerKeys'
		if ([string]::IsNullOrEmpty($DiskEncryptionResourceGroupName))
		{
			throw "Disk encryption resource group name must be specified when setting a disk encryption set"
		}
		$des=Get-AzDiskEncryptionSet -Name $DiskEncryptionSet -ResourceGroupName $DiskEncryptionResourceGroupName
		if (-Not $des) 
		{
			throw "Disk encryption set $DiskEncryptionSet not found"
		}
		else 
		{
			$desid = $des.Id
		}	
	}
	else 
	{
		$desid = $disk.Encryption.DiskEncryptionSetId
		$desType = $disk.Encryption.Type
	}

	#Sku checks and set the sku if not provided
	if ((! [string]::IsNullOrEmpty($SkuName)))
	{
		$possibleSkus = @('Standard_LRS', 'Premium_LRS', 'StandardSSD_LRS', 'UltraSSD_LRS')
		if (-Not $possibleSkus.Contains($SkuName))
		{
			throw "SkuName $SkuName is not a valid sku name"
		}
	}
	else 
	{
		$SkuName = $disk.Sku.Name
	}
	#Disk size checks and set the disk size if not provided
	if (! [string]::IsNullOrEmpty($DiskSizeGB))
	{
		if ($DiskSizeGB -lt 1 -or $DiskSizeGB -gt 32767 -and $DiskSizeGB -lt $disk.DiskSizeGB)
		{
			throw "DiskSizeGB $DiskSizeGB is not a valid disk size. This could be due to the disk size being less than the current disk size. The current disk size is $($disk.DiskSizeGB)"
		}
	}
	else 
	{
		$DiskSizeGB = $disk.DiskSizeGB
	}
	
	#update the disk
	$update = New-AzDiskUpdateConfig -DiskSizeGB $diskSizeGB -SkuName $SkuName -DiskEncryptionSetId $desid -EncryptionType $desType | Update-AzDisk -ResourceGroupName $AZDiskResourceGroupName -DiskName $AZDisk
	if ( -Not $update)
	{
		throw "Disk $AZDisk failed to update"
	}
	else 
	{
		write-output "Disk $AZDisk updated"
	}
}
Export-ModuleMember -Function New-DiskSnap
Export-ModuleMember -Function Backup-verify
Export-ModuleMember -Function Backup-Vms
Export-ModuleMember -Function Restore-Vms
Export-ModuleMember -Function Show-Menu
Export-ModuleMember -Function Start-Menu
Export-ModuleMember -Function Show-DiskEncryptionSettings
Export-ModuleMember -Function Update-Disk
