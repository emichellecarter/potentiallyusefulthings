#!/bin/bash
## Script to copy snapshot with db key, rename and restore an instance
##This script may need some tweaking as I was not able to test on an oracle instance.
##Temp files are used to avoid json output to the user when running commands so the script will continue without interaction.
## probably want add a wait or nohup in here.
#get the snapshot you want to restore
while [ -z "$DB_SnapShotName" ]; do
  read -p "Please enter the snapshot name:  " DB_SnapShotName
  done

#Verify that this is the snapshot you want to restore
DB_Instance=$(aws rds describe-db-snapshots \
    --query 'DBSnapshots[*].{DBInstanceIdentifier:DBInstanceIdentifier}' \
    --filters Name=db-snapshot-id,Values=$DB_SnapShotName \
    --output text)

    read -p "The snapshot chosen is a backup of $DB_Instance.  Is this the intended database?: " ansdbinstance
        ansdbinstance=${ansdbinstance^^}
      if [ $ansdbinstance = "Y" -o $ansdbinstance = "YES" ] || [ $ansdbinstance = "N" -o $ansdbinstance = "NO" ]; then
        if [ $ansdbinstance = "N" -o $ansdbinstance = "NO" ]; then
          echo "Please run the script again with the correct snapshot.  Exiting Script..."
          exit 1
        else

	#key information
          KmsKeyARN=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{KmsKeyId:KmsKeyId}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

    #Get the Key id for the KMS key
	    set -o pipefail
	    echo $KmsKeyARN | grep "arn"
	 if [ $? -eq 0 ] ; then
          KMSKeyID=$(aws kms describe-key \
            --key-id $KmsKeyARN \
            --output text | awk '{ print $7 }')
	 fi

	  #DB instance class
          DBInstanceClass=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{DBInstanceClass:DBInstanceClass}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

          #DB subnet group
          DBSubnetGroupName=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{DBSubnetGroup:DBSubnetGroup}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output table | grep DBSubnetGroupName | awk -F"|" '{ print $4 }')

	  # DB parameter group - This is not included in the restore but should be modified after the the restore.
          DBParameterGroupName=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{DBParameterGroups:DBParameterGroups}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text   | awk '{ print $2 }')

          #Get the security group info
          sg=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{VpcSecurityGroups:VpcSecurityGroups}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text | awk '{ print $3 }' | awk -v RS= -v OFS=\",\" '{$1 = $1} 1')
            #This line formats the security groups
	        VpcSecurityGroupIds=$(echo {\"$sg\"})
	         #Get the allocated storage
          AllocatedStorage=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{AllocatedStorage:AllocatedStorage}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

          #Get the DB Name
          DBName=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{BDName:DBName}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

          #Get the DB option group name
          OptionGroupName=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{OptionGroupMemberships:OptionGroupMemberships}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text | awk '{ print $2}')

          #Get the monitoring information for the current databases
          MInterval=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{MonitoringInterval:MonitoringInterval}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

          RoleARN=$(aws rds describe-db-instances \
            --query 'DBInstances[*].{MonitoringRoleArn:MonitoringRoleArn}' \
            --filters Name=db-instance-id,Values=$DB_Instance \
            --output text)

          echo "The parameters below will used to restore the database listed."
          echo "KeyID: $KMSKeyID"
          echo "DB Instance Class: $DBInstanceClass"
          echo "DB Subnet Group Name: $DBSubnetGroupName"
          echo "DB Parameter Group Name: $DBParameterGroupName"
          echo "VPC Security Group Ids: $VpcSecurityGroupIds"
          echo "Allocated Storage: $AllocatedStorage"
          echo "DB Name: $DBName"
          echo "DB Option Group Name: $OptionGroupName"
          echo "DB Instance: $DB_Instance"
          echo "DB SnapShot Name: $DB_SnapShotName"
	    #Make a copy of the snap with the db key
          New_SnapShotName=$(echo "$DB_SnapShotName-copy")
	  echo "DB SNapShot Copy Name: $New_SnapShotName"
	  #Delete the snapshot copy if it already exists before recreating it.
	  echo "Removing any existing snapshot copies and creating copy of snapshot with the database key."
    CheckSnapShot=$(aws rds describe-db-snapshots \
        --query 'DBSnapshots[*].{DBInstanceIdentifier:DBInstanceIdentifier}' \
        --filters Name=db-snapshot-id,Values=$New_SnapShotName \
        --output text 2> /dev/null)

    if [ ! -z $CheckSnapShot ]; then
    	 aws rds delete-db-snapshot --db-snapshot-identifier $New_SnapShotName > /tmp/delete
    fi
    #Get rid of the tmp file
    rm -f /tmp/delete
         aws rds copy-db-snapshot \
            --source-db-snapshot-identifier $DB_SnapShotName \
            --target-db-snapshot-identifier $New_SnapShotName\
            --kms-key-id $KMSKeyID > /tmp/copy
    fi
	#Get rid of the temp file
	rm -f /tmp/copy
	#Rename the current database to -old.
	echo "Renaming current db instance...."
	Rename_Instance=$(echo "$DB_Instance-old")
    nohup	aws rds modify-db-instance \
          --db-instance-identifier $DB_Instance \
          --new-db-instance-identifier $Rename_Instance \
          --apply-immediately > /tmp/rename
	#Get rid of the temp file
	rm -f /tmp/rename
	#We have copied the snapshot so now we need to restore it.  These sleep times may need to be adjusted for ldac.
	echo "Allowing rename and snapshot copy to complete."
	sleep 240
	echo "Restoring snapshot copy....."
	nohup aws rds restore-db-instance-from-db-snapshot \
  	  --db-instance-identifier $DB_Instance \
  	  --db-snapshot-identifier $New_SnapShotName \
  	  --db-instance-class $DBInstanceClass \
      --option-group-name $OptionGroupName \
      --db-parameter-group-name $DBParameterGroupName \
  	  --auto-minor-version-upgrade \
  	  --no-publicly-accessible \
  	  --multi-az \
   	  --db-subnet-group-name $DBSubnetGroupName \
      --deletion-protection > /tmp/restore
       #Get rid of temp file
	rm -f /tmp/restore

	#Add a sleep so the restore can finihs prior to modifying the instance and let the user know.  Sleep times may need to be adjusted for ldac.
  echo " Allowing the restore to complete prior to modifying the instance. This is a long sleep so you may want to get a cup of coffee."
	sleep 6000
	#Modify the instance
	  aws rds modify-db-instance \
        --db-instance-identifier $DB_Instance \
        --allocated-storage $AllocatedStorage \
        --vpc-security-group-ids $VpcSecurityGroupIds\
        --monitoring-interval $MInterval \
        --monitoring-role-arn $RoleARN \
        --apply-immediately > /tmp/modify
    #Get rid of temp file
    rm -f /tmp/modify

    #Commented cli for the deleting an instances
    #Modify database instance to remove deletion protection.
    #aws rds modify-db-instance \
    #  --no-deletion-protection

    #Delete the instances
    #aws rds delete-db-instance \
    #    --db-instance-identifier $Rename_Instance

     else
	#User did not answer yes or no
	echo "You are supposed to answer yes or no silly goose...exiting script."
	exit 1
      fi
