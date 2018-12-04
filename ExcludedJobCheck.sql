USE msdb

-- Change DBA_Tasks if you already have a Utility Database
GO
	
	IF DB_ID ('DBA_Tasks') IS NULL

		BEGIN

			Print 'Database DBA_Tasks has been created'

			CREATE DATABASE	[DBA_Tasks];

		END

GO

USE [DBA_Tasks]

	 IF OBJECT_ID ('dbo.p_ExcludedJobCheck') IS NOT NULL 

		BEGIN

			Print 'Procedure p_ExcludedJobCheck already exits, we will drop it and add the version from this script'

			DROP PROCEDURE [dbo].[p_ExcludedJobCheck]

		END

	IF OBJECT_ID ('dbo.ExcludedJobs') IS NULL

		BEGIN

			PRINT 'Required table Excluded Jobs dosen''t exist, we will create that now'

			CREATE TABLE [dbo].[ExcludedJobs]
			(
				[ID] [int] IDENTITY(1,1) NOT NULL PRIMARY KEY,
				[Job_name] [nvarchar](128) NOT NULL,
				[Active] [bit] NULL
			)

		END

GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[p_ExcludedJobCheck]

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
	FROM 
		[DBA_Tasks].[dbo].[ExcludedJobs] 
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
								ag.name = 'InstanceName' 
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

		IF @Job_name IN (SELECT name from msdb..sys.o)

		IF @Availability_Role = 'PRIMARY'

			BEGIN

				SET @SQLEnabled = 'EXEC msdb..sp_update_job @job_name =' + '''' + @Job_Name + '''' +  ', @enabled = 1'				

				EXEC sp_executesql @SQLEnabled

			END


		ELSE

			BEGIN

				SET @SQLDisabled = 'EXEC msdb..sp_update_job @job_name =' + '''' + @Job_Name + '''' + ', @enabled = 0'				

				EXEC sp_executesql @SQLDisabled

			END

			SET @Counter = @Counter + 1

	END

	DROP TABLE  #Excluded_Jobs

END