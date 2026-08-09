#Get all the vaults and loop through them to get the policies
#For any vaults where there is no match, print the vault name.
$vaults = Get-AzRecoveryServicesVault
foreach ($vault in $vaults) {
    $policies = (Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID).Name -match "^IL.*T[1,2]"
    if ($policies.Count -lt 4) {
        Write-Output "Adding Backup Policies for Vault: $($vault.Name)"
        #Get the customer name if the vault has it, otherwise prompt for it
        if ($vault.Name -match "IL.*-VLT-01$"){
            $customerName = $vault.Name.Split("-")[2]
        }
        else {
            $customerName = Read-Host "Please Enter a Customer Name to be used for the policies"
        }
        $retentionInDays                    = "30"
        $retentionInWeeks                   = "12"
        $retentionInMonths                  = "12"
        $retentionInYears                   = "10"
        $vmWorkLoadType                     = "AzureVM" 
        $azureFilesWorkLoadType             = "AzureFiles"
        $azureFilesManagementType           = "AzureStorage"
        $timeZone                           = Get-TimeZone -ListAvailable | Where-Object { $_.Id -eq "Eastern Standard Time" }
        $policyStartTime                    = (Get-Date -Date "2019-03-20 06:00:00Z").ToUniversalTime()

        # Enhanced Policies
        # Add the Enhanced VM policy if it does not exist
        $vmEnhancedCheck = (Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID).Name -match "^IL.*T1-VM$"
        if (-not $vmEnhancedCheck){
            Write-output "Creating Enhanced Policy for VMs"
            $vmBackupEnhancedPolicyName = "IL5-PRD-$CustomerName-T1-VM"
            $vmEnhancedSchedulePolicyparams = @{
                WorkloadType = $vmWorkLoadType
                BackupManagementType = $vmWorkLoadType
                PolicySubType = "Enhanced"
                ScheduleRunFrequency = "Hourly"
            }

            $vmEnhancedSchedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject @vmEnhancedSchedulePolicyparams -ErrorAction SilentlyContinue

            if (-not $vmEnhancedSchedulePolicy){
                throw "Failed to get the Enhanced Schedule Policy for VMs"
            }
            else {
                $vmEnhancedSchedulePolicy.ScheduleRunTimeZone = $timeZone.Id
                $vmEnhancedSchedulePolicy.HourlySchedule.WindowStartTime = $policyStartTime
                $vmEnhancedSchedulePolicy.HourlySchedule.Interval = 4
                $vmEnhancedSchedulePolicy.HourlySchedule.WindowDuration = 16
            }

            $vmEnhancedRetentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType $vmWorkLoadType -ErrorAction SilentlyContinue
            if (-not $vmEnhancedRetentionPolicy){
                throw "Failed to get the Enhanced Retention Policy for VMs"
            }
            else {
                $vmEnhancedRetentionPolicy.IsDailyScheduleEnabled = $true
                $vmEnhancedRetentionPolicy.IsWeeklyScheduleEnabled = $true
                $vmEnhancedRetentionPolicy.IsMonthlyScheduleEnabled = $true
                $vmEnhancedRetentionPolicy.IsYearlyScheduleEnabled = $true
                $vmEnhancedRetentionPolicy.DailySchedule.DurationCountInDays = $retentionInDays
                $vmEnhancedRetentionPolicy.WeeklySchedule.DurationCountInWeeks = $retentionInWeeks
                $vmEnhancedRetentionPolicy.WeeklySchedule.DaysOfTheWeek = "Sunday"
                $vmEnhancedRetentionPolicy.MonthlySchedule.DurationCountInMonths = $retentionInMonths
                $vmEnhancedRetentionPolicy.MonthlySchedule.RetentionScheduleFormatType = "Weekly"
                $vmEnhancedRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                $vmEnhancedRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                $vmEnhancedRetentionPolicy.YearlySchedule.DurationCountInYears = $retentionInYears
                $vmEnhancedRetentionPolicy.YearlySchedule.RetentionScheduleFormatType = "Weekly"
                $vmEnhancedRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                $vmEnhancedRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                $vmEnhancedRetentionPolicy.YearlySchedule.MonthsOfYear = "October"
            }

            $vmEnhancedBackupPolicyProtectionParams = @{
                Name = $vmBackupEnhancedPolicyName
                WorkloadType = $vmWorkLoadType
                BackupManagementType = $vmWorkLoadType
                RetentionPolicy = $vmEnhancedRetentionPolicy
                SchedulePolicy = $vmEnhancedSchedulePolicy
                MoveToArchiveTier = $true
                TieringMode = "TierAllEligible"
                TierAfterDuration = "3"
                TierAfterDurationType = "Months"
                VaultId = $vault.ID
            }
            
            $vmEnhancedBackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy @vmEnhancedBackupPolicyProtectionParams -ErrorAction SilentlyContinue
            if (-not $vmEnhancedBackupPolicy) {
                throw "Failed to create the Enhanced Policy for VMs"
            }   
        }

            #Add the Enhanced azureFiles policy if it does not exist
        $stgEnhancedCheck = (Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID).Name -match  "^IL.*T1-AF$"
        if (-not $stgEnhancedCheck){
            Write-output "Creating Enhanced Policy for Azure Files"
            $azureFilesBackupEnhancedPolicyName = "IL5-PRD-$CustomerName-T1-AF"

            $azureFilesEnhancedSchedulePolicyparams = @{
                WorkloadType = $azureFilesWorkLoadType
                BackupManagementType = $azureFilesManagementType
                ScheduleRunFrequency = "Hourly"
            }
            $azureFilesEnhancedSchedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject @azureFilesEnhancedSchedulePolicyparams -ErrorAction SilentlyContinue
                if (-not $azureFilesEnhancedSchedulePolicy){
                    throw "Failed to get the Enhanced Schedule Policy for Azure Files"
                }
                else {
                    $azureFilesEnhancedSchedulePolicy.ScheduleRunTimeZone = $timeZone.Id
                    $azureFilesEnhancedSchedulePolicy.ScheduleWindowStartTime = $policyStartTime
                    $azureFilesEnhancedSchedulePolicy.ScheduleInterval = 4
                    $azureFilesEnhancedSchedulePolicy.ScheduleWindowDuration = 16
                }

                $azureFilesEnhancedRetentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType $azureFilesWorkLoadType -ErrorAction SilentlyContinue
                if (-not $azureFilesEnhancedRetentionPolicy){
                    throw "Failed to get the Enhanced Retention Policy for Azure Files"
                }
                else{
                    $azureFilesEnhancedRetentionPolicy.IsDailyScheduleEnabled = $true
                    $azureFilesEnhancedRetentionPolicy.IsWeeklyScheduleEnabled = $true
                    $azureFilesEnhancedRetentionPolicy.IsMonthlyScheduleEnabled = $true
                    $azureFilesEnhancedRetentionPolicy.IsYearlyScheduleEnabled = $true
                    $azureFilesEnhancedRetentionPolicy.DailySchedule.DurationCountInDays = $retentionInDays
                    $azureFilesEnhancedRetentionPolicy.WeeklySchedule.DurationCountInWeeks = $retentionInWeeks
                    $azureFilesEnhancedRetentionPolicy.WeeklySchedule.DaysOfTheWeek = "Sunday"
                    $azureFilesEnhancedRetentionPolicy.MonthlySchedule.DurationCountInMonths = $retentionInMonths
                    $azureFilesEnhancedRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                    $azureFilesEnhancedRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                    $azureFilesEnhancedRetentionPolicy.YearlySchedule.DurationCountInYears = $retentionInYears
                    $azureFilesEnhancedRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                    $azureFilesEnhancedRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                    $azureFilesEnhancedRetentionPolicy.YearlySchedule.MonthsOfYear = "October"
                }

                $azureFilesEnhancedBackupPolicyParams = @{
                    Name = $azureFilesBackupEnhancedPolicyName
                    WorkloadType = $azureFilesWorkLoadType
                    BackupManagementType = $azureFilesManagementType
                    RetentionPolicy = $azureFilesEnhancedRetentionPolicy
                    SchedulePolicy = $azureFilesEnhancedSchedulePolicy
                    VaultId = $vault.ID
                }

                $azureFilesEnhancedBackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy @azureFilesEnhancedBackupPolicyParams -ErrorAction SilentlyContinue
                if (-not $azureFilesEnhancedBackupPolicy) {
                    throw "Failed to create the Enhanced Policy for Azure Files"
                }

            }
            # Standard Policies
            #Add the VM Policy if it doesn't exist
            $vmStandardCheck = (Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID).Name -match "^IL.*T2-VM$"
            if (-not $vmStandardCheck){
                write-output "Creating Standard Policy for VMs"
                $vmBackupStandardPolicyName = "IL5-PRD-$CustomerName-T2-VM"

                $vmStandardSchedulePolicyparams = @{
                    WorkloadType = $vmWorkLoadType
                    BackupManagementType = $vmWorkLoadType
                    PolicySubType = "Standard"
                    ScheduleRunFrequency = "Daily"
                }
                $vmStandardSchedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject @vmStandardSchedulePolicyparams -ErrorAction SilentlyContinue
                if (-not $vmStandardSchedulePolicy){
                    throw "Failed to get the Standard Schedule Policy for VMs"
                }
                else {
                    $vmStandardSchedulePolicy.ScheduleRunTimes.Clear()
                    $vmStandardSchedulePolicy.ScheduleRunTimes.Add($policyStartTime)
                    $vmStandardSchedulePolicy.ScheduleRunTimeZone = $timeZone
                }

                $vmStandardRetentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType $vmWorkLoadType -ErrorAction SilentlyContinue
                if (-not $vmStandardRetentionPolicy){
                    throw "Failed to get the Standard Retention Policy for VMs"
                }
                else{
                    $vmStandardRetentionPolicy.IsDailyScheduleEnabled = $true
                    $vmStandardRetentionPolicy.IsWeeklyScheduleEnabled = $true
                    $vmStandardRetentionPolicy.IsMonthlyScheduleEnabled = $true
                    $vmStandardRetentionPolicy.IsYearlyScheduleEnabled = $true
                    $vmStandardRetentionPolicy.DailySchedule.DurationCountInDays = $retentionInDays
                    $vmStandardRetentionPolicy.WeeklySchedule.DurationCountInWeeks = $retentionInWeeks
                    $vmStandardRetentionPolicy.WeeklySchedule.DaysOfTheWeek = "Sunday"
                    $vmStandardRetentionPolicy.MonthlySchedule.DurationCountInMonths = $retentionInMonths
                    $vmStandardRetentionPolicy.MonthlySchedule.RetentionScheduleFormatType = "Weekly"
                    $vmStandardRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                    $vmStandardRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                    $vmStandardRetentionPolicy.YearlySchedule.DurationCountInYears = $retentionInYears
                    $vmStandardRetentionPolicy.YearlySchedule.RetentionScheduleFormatType = "Weekly"
                    $vmStandardRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                    $vmStandardRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                    $vmStandardRetentionPolicy.YearlySchedule.MonthsOfYear = "October"
                }

                $vmRecoveryServicesBackupProtectionPolicyParams = @{
                    Name = $vmBackupStandardPolicyName
                    WorkloadType = $vmWorkLoadType
                    BackupManagementType = $vmWorkLoadType
                    RetentionPolicy = $vmStandardRetentionPolicy
                    SchedulePolicy = $vmStandardSchedulePolicy
                    MoveToArchiveTier = $true
                    TieringMode = "TierAllEligible"
                    TierAfterDuration = "3"
                    TierAfterDurationType = "Months"
                    VaultId = $vault.ID
                }

                $vmStandardBackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy @vmRecoveryServicesBackupProtectionPolicyParams -ErrorAction SilentlyContinue
                if (-not $vmStandardBackupPolicy) {
                    throw "Failed to create the Standard Policy for VMs"
                }

            }
        #Add the Azure Files Policy if it doesn't exist
        $stgStandardCheck = (Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $vault.ID).Name -match  "^IL.*T2-AF$"
        if (-not $stgStandardCheck){
            write-output "Creating Standard Policy for Azure Files"
            $azureFilesBackupStandardPolicyName = "IL5-PRD-$CustomerName-T2-AF"

            $azureFilesStandardSchedulePolicyparams = @{
            WorkloadType = $azureFilesWorkLoadType
            BackupManagementType = $azureFilesManagementType
            ScheduleRunFrequency = "Daily"
            }
            
            $azureFilesStandardSchedulePolicy = Get-AzRecoveryServicesBackupSchedulePolicyObject @azureFilesStandardSchedulePolicyparams -ErrorAction SilentlyContinue
   
            if (-not $azureFilesStandardSchedulePolicy){
                throw "Failed to get the Standard Schedule Policy for Azure Files"
            }
            else {
                $azureFilesStandardSchedulePolicy.ScheduleRunTimes.Clear()
                $azureFilesStandardSchedulePolicy.ScheduleRunTimes.Add($policyStartTime)
                $azureFilesStandardSchedulePolicy.ScheduleRunTimeZone = $timeZone.Id
            }

            $azureFilesRetentionPolicy = Get-AzRecoveryServicesBackupRetentionPolicyObject -WorkloadType $azureFilesWorkLoadType -ErrorAction SilentlyContinue

            if (-not $azureFilesRetentionPolicy){
                throw "Failed to get the Standard Retention Policy for Azure Files"
            }
            else{
                $azureFilesRetentionPolicy.IsDailyScheduleEnabled = $true
                $azureFilesRetentionPolicy.IsWeeklyScheduleEnabled = $true
                $azureFilesRetentionPolicy.IsMonthlyScheduleEnabled = $true
                $azureFilesRetentionPolicy.IsYearlyScheduleEnabled = $true
                $azureFilesRetentionPolicy.DailySchedule.DurationCountInDays = $retentionInDays
                $azureFilesRetentionPolicy.WeeklySchedule.DurationCountInWeeks = $retentionInWeeks
                $azureFilesRetentionPolicy.WeeklySchedule.DaysOfTheWeek = "Sunday"
                $azureFilesRetentionPolicy.MonthlySchedule.DurationCountInMonths = $retentionInMonths
                $azureFilesRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                $azureFilesRetentionPolicy.MonthlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                $azureFilesRetentionPolicy.YearlySchedule.DurationCountInYears = $retentionInYears
                $azureFilesRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.DaysOfTheWeek = "Sunday"  
                $azureFilesRetentionPolicy.YearlySchedule.RetentionScheduleWeekly.WeeksOfTheMonth = "First"
                $azureFilesRetentionPolicy.YearlySchedule.MonthsOfYear = "October"
            }

            $RecoveryServicesBackupProtectionPolicyparam = @{
                Name = $azureFilesBackupStandardPolicyName
                WorkloadType = $azureFilesWorkLoadType
                BackupManagementType = $azureFilesManagementType
                RetentionPolicy = $azureFilesRetentionPolicy
                SchedulePolicy = $azureFilesStandardSchedulePolicy
                VaultId = $vault.ID
            }

            $azureFilesStandardBackupPolicy = New-AzRecoveryServicesBackupProtectionPolicy @RecoveryServicesBackupProtectionPolicyparam -ErrorAction SilentlyContinue
                if (-not $azureFilesStandardBackupPolicy) {
                    throw "Failed to create the Standard Policy for Azure Files"
                }

        }
    } 
}
 
