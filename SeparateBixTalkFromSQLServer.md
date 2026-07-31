BizTalk Server Application Database Separation

The following process was used to move the BizTalk Server databases off the same server as the application.  They may be useful if the process needs to be repeated or if the databases for Biztalk need to be moved to a new server.  Note: These instructions are intended for an experienced sysadmin.  Preparation for this includes creating two new drives that can be moved to the new server by a System Engineer.
1.  Shut down the BizTalk Ports – This will need to be done by the BizTalk Administrator until instructions for this can be obtained and tested.
2. Shutdown the BizTalk Services and corresponding services
   Open Powershell as an administrator and run the following
   get-service | where {($_.Displayname -like "*biz*")} | Stop-Service
   get-service | where {($_.Displayname -like "*Mino*")} | Stop-Service
   get-service | where {($_.Displayname -like "*Share*")} | Stop-Service
   get-service | where {($_.Displayname -like "*HL7*")} | Stop-Service
3.  Shut down the Enterprise Single Sign on Process
   Open the Services Admin Tool (Start > Administrative Tools > Services) ; locate the Enterprise Single Sign On > right click and select to STOP Services
4. Disable all SQL Server Jobs – There should be a job under the SQL Server Agent that can simply be executed.
5. Create a Final System Database backup with copy only – Most servers have this set up as a job that can simply be executed
6. Detach all non-system databases.  The following script can be used to generate the commands to create a script to detach all non-system databases.
		select'alter database ' + name + ' set single_user with rollback immediate;
Exec sp_dettach_db @dbname = N'+ '''' + name + '''' + ';'
frommaster.sys.databases where database_id > 4

1. Copy all database files to the new appropriate drives.  The following script can be used to generate powershell copy commands.  The second physical location of the file will need to be updated once they have been generated with the appropriate path to the new location.
Example Copy Command:
Copy-Item "e:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\ReportServer.mdf" "N:\MSSQL\Data\UserDataFiles\ReportServer.mdf"
Copy-Item "e:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\ReportServer_log.LDF" "T:\Logs\ReportServer_log.LDF" 
select'Copy-Item "' + physical_name + '" '  
+'"' + physical_name + '"'
frommaster.sys.master_files
where database_id > 4 

1. Attach Non System databases to the new locations.  The following script can be used to generate a script to attach all the non-system databases.

select'Exec sp_attach_db @dbname = N' + ''''
+ d.name + '''' + ',' +
case mf.type when 0 then '@filename1 = N'
+'''' +  mf.physical_name + '''' + ','
when 1 then '@filename2 = N' + ''''
+  mf.physical_name + '''' + ';' end
frommaster.sys.databases d
joinmaster.sys.master_files mf 
on d.database_id = mf.database_id
where d.database_id > 4

1. Run an alter statements to move the model, msdb, and temdb files.  Examples below:
Alter database [model] set single_user with rollback immediate;
Alter database [model] modify file (name=modeldev, FILENAME= 'N:\MSSQL\Data\SystemDataFiles\model.mdf');
Alter database [model] modify file (name=modellog, FILENAME= 'T:\LOGS\modellog.ldf');
Alter database [model] set multi_user;

Alter database [msdb] set single_user with rollback immediate;
Alter database [msdb] modify file (name=MSDBdata, FILENAME= 'N:\MSSQL\Data\SystemDataFiles\MSDBData.mdf');
Alter database [msdb] modify file (name=MSDBlog, FILENAME= 'T:\LOGS\MSDBLog.ldf');
Alter database [msdb] set multi_user;"

Alter database [tempdb] modify file (name=tempdev, FILENAME= 'N:\MSSQL\Data\SystemDataFiles\tempdb.mdf');
Alter database [tempdb] modify file (name=templog, FILENAME= 'T:\LOGS\templog.ldf');

1. Shutdown the SQL Server service (NET STOP MSSQLSERVER in a cmd prompt under administrative privileges) or using the configuration manager
2. Copy the system database files to the new location.  I used powershell copy commands. For example.
Copy-item "e:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\model.mdf" "N:\MSSQL\Data\SystemDataFiles\model.mdf"
Copy-item "e:\Microsoft SQL Server\MSSQL10_50.MSSQLSERVER\MSSQL\DATA\modellog.ldf" "T:\LOGS\modellog.ldf"
1. Assure permissions for the files are set for the system account.  On occasion the permissions do not replicate down from the parent folder and have to be set on the files themselves.
2. Start the SQL Server instance (NET START MSSQLSERVER in cmd prompt under administrative privileges) or by using the configuration manager
3. Verify files (select name, physical_name from master.sys.master_files;)
4. Backup the system databases
5. Shutdown the SQL Server instance you are moving from (NET STOP MSSQLSERVER or by using the Configuration manager).
6. Copy the master database files to the new server and have the new drives moved to the new server.
7. Verify files the SQL Server service account has permissions to the data and log files.
8. Start the new SQL Server instance in single user mode
   Add –m to the startup parameters
9.  Restore the master
   Start powershell
   Type the following commands
   Sqlcmd
   RESTORE DATABASE master FROM DISK = ‘some path where your master database is’;
   GO
   This will shut down the instance of SQL Server after the master restores.
10. Restart SQL Server without the –m startup parameter
11. Verify all files are in the correct place.  select name, physical_name from master.sys.master_files;
12. Verify all accounts that need to be a sysadmin are set up
13. Set up the report server.  See instructions on SharePoint for setting up reporting services
14. Verify BizTalk accounts and permissions on BizTalk server:
    HS\BizTalk Application Users
    HS\BizTalk Isolated Host Users
    HS\ BizTalk Server Administrators
    HS\BizTalk Server Operators
    HS\BizTalkSPAccess
			*Note since you restored the master the accounts will already be there and synced with the databases.  
1. Set up MSDTC with the following settings:
