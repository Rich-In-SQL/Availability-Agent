# Availability Agent

Availabiltiy Agent is a T-SQL script that is designed to be created as a stored procedure and referenced inside a SQL Agent Job that runs on a regular frequency to disable agent jobs on the secondary node that would otherwise cause a job failure.

### Downloading

The script can be downloaded from the projects GitHub

### Installation 

These steps should be first carried out on the primary node in your availabiltiy group.

1. Ensure your connected to the primary node in your availability group
2. Change database context to the database you would like the soloution installed within.
3. Run the ExcludedJobCheck.sql script from the zip file, this assumes you have a database called DBA_Tasks which is where the stored procedure will resdide. If this is no the case change ```@database_name=N'DBA_Tasks'``` to the database name of your choosing. 
