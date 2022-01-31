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

