DECLARE 
	@CreateProc varchar(max)	 

	IF OBJECT_ID ('dbo.ExcludedJobs') IS NOT NULL

	BEGIN TRY
	DROP TABLE [dbo].[ExcludedJobs]
		RAISERROR('Required table Excluded Jobs already existed, dropping',0,1) WITH NOWAIT
	END TRY		

	BEGIN CATCH
		RAISERROR('Required table Excluded Jobs wasn''t dropped',0,1) WITH NOWAIT
	END CATCH			
			
	BEGIN TRY

	RAISERROR('Required table Excluded Jobs dosen''t exist, we will create that now',0,1) WITH NOWAIT	
			
	CREATE TABLE [dbo].[ExcludedJobs]
	(
		[ID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
		[Job_name] [nvarchar](128) NOT NULL,
		[Active] [bit] NULL
	)

	RAISERROR('Table Excluded Jobs created',0,1) WITH NOWAIT

	END TRY
	BEGIN CATCH
		RAISERROR('Creation of the table Excluded Jobs failed',0,1) WITH NOWAIT
	END CATCH

	DECLARE @ProcExists TINYINT
	SET @ProcExists = (SELECT COUNT(1) FROM sys.all_objects where name = 'p_ExcludedJobCheck')
	IF(@ProcExists > 0)

	BEGIN TRY
		DROP PROCEDURE [dbo].[p_ExcludedJobCheck]

		RAISERROR('Procedure p_ExcludedJobCheck already exits, we will drop it and add the version from this script',0,1) WITH NOWAIT

	END TRY
	BEGIN CATCH
		RAISERROR('Dropping of the stored procedure failed',0,1) WITH NOWAIT
	END CATCH

	BEGIN TRY

	SET @CreateProc = 

	'CREATE PROCEDURE [dbo].[usp_ExcludedJobCheck]

	AS

	BEGIN

		SET NOCOUNT ON;

		DECLARE
			@Availability_Role nvarchar(20)
			,@Job_Name NVARCHAR(128)
			,@SQLEnabled NVARCHAR(250)
			,@SQLDisabled NVARCHAR(250)
			,@Counter INT
			,@MaxID int

		CREATE TABLE #Excluded_Jobs 
		(
			ID INT IDENTITY(1,1) NOT NULL,
			Job_Name NVARCHAR(128) NOT NULL,
			Active BIT
		)

		INSERT INTO #Excluded_Jobs (Job_Name)
		SELECT 
			Job_Name 
		FROM [DBA_Tasks].[dbo].[ExcludedJobs]
			
		WHERE 
			Active = 1

		SET @Counter = 1
		SET @MaxID = (SELECT MAX(ID) FROM #Excluded_Jobs)
	
		SET @Availability_Role = 
								(
								SELECT 
									ars.role_desc
								FROM 
									sys.dm_hadr_availability_replica_states AS ars INNER JOIN
									sys.availability_groups AS ag ON ars.group_id = ag.group_id
								WHERE 
									ag.name = ''InstanceName''
									AND ars.is_local = 1
								)

		WHILE @Counter <= @MaxID

		BEGIN

			SET @Job_Name = (
							SELECT 
								Job_Name 
							FROM 
								#Excluded_Jobs 
							WHERE 
								ID = @Counter
							)

			IF @Job_name IN (SELECT name from msdb.dbo.sysjobs_view)

			IF @Availability_Role = ''PRIMARY''

				BEGIN

					SET @SQLEnabled = ''EXEC msdb..sp_update_job @job_name ='' + '''' + @Job_Name + '''' +  '', @enabled = 1''				

					EXEC sp_executesql @SQLEnabled

				END

			ELSE

				BEGIN

					SET @SQLDisabled = ''EXEC msdb..sp_update_job @job_name ='' + '''' + @Job_Name + '''' + '', @enabled = 0''			

					EXEC sp_executesql @SQLDisabled

				END

				SET @Counter = @Counter + 1

		END

		DROP TABLE  #Excluded_Jobs

	END'

	EXEC(@CreateProc)

	RAISERROR('Creation of stored procedure usp_ExcludedJobCheck completed',0,1) WITH NOWAIT

	END TRY

	BEGIN CATCH
		RAISERROR('Creation of stored procedure usp_ExcludedJobCheck failed',0,1) WITH NOWAIT
	END CATCH


BEGIN TRY

RAISERROR('Attempting to create SQL Agent Job',0,1) WITH NOWAIT

USE [msdb]
GO
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Availability Group Check', 
		@enabled=0, 
		@notify_level_eventlog=0, 
		@notify_level_email=0, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Execute Node Check', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'EXEC [dbo].[usp_ExcludedJobCheck]', 
		@database_name=N'DBA_Tasks', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Every 5 Minutes', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=5, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20220201, 
		@active_end_date=99991231, 
		@active_start_time=0, 
		@active_end_time=235959, 
		@schedule_uid=N'fdf13b73-34eb-4f48-b65b-e7f8df5421d5'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

END TRY
BEGIN CATCH
	RAISERROR('Creation of SQL Agent Job failed',0,1) WITH NOWAIT
END CATCH

