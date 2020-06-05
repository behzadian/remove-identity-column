/****** Object:  UserDefinedFunction [dbo].[IndexScript]    Script Date: 13/03/1399 08:22:02 È.Ù ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


DROP FUNCTION IF EXISTS [dbo].[IndexScript]
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[IndexScript] 
(
	-- Add the parameters for the function here
	@IndexName NVarChar(MAX)
)
RETURNS NVarChar(MAX)
AS
BEGIN
	if(@IndexName IS NULL)
		RETURN NULL

	declare @enter NVARCHAR(MAX)
	SET @enter = CHAR(13)+CHAR(10)
	declare @script NVarChar(MAX)
	set @script = (
		SELECT 'CREATE ' + 
			CASE WHEN I.is_unique = 1 THEN ' UNIQUE ' ELSE '' END  +  
			I.type_desc COLLATE DATABASE_DEFAULT +' INDEX '+@enter+'[' + I.name  + '] ON '  +  
			Schema_name(T.Schema_id)+'.'+T.name + ' (' + KeyColumns + ') ' + @enter + 
			ISNULL('INCLUDE ('+IncludedColumns+' ) '+@enter,'') + 
			ISNULL('WHERE '+I.Filter_definition+@enter,'') + 
			'WITH ( ' + @enter +
			CHAR(9) + CASE WHEN I.is_padded = 1 THEN 'PAD_INDEX = ON' ELSE 'PAD_INDEX = OFF' END + ','  + @enter + 
			CHAR(9) + 'FILLFACTOR = '+CONVERT(VARCHAR(5),CASE WHEN I.Fill_factor = 0 THEN 100 ELSE I.Fill_factor END) + ','  + @enter + 
			-- default value 
			CHAR(9) + 'SORT_IN_TEMPDB = OFF'  + ','  + @enter + 
			CHAR(9) + CASE WHEN I.ignore_dup_key = 1 THEN 'IGNORE_DUP_KEY = ON' ELSE 'IGNORE_DUP_KEY = OFF' END + ','  + @enter + 
			CHAR(9) + CASE WHEN ST.no_recompute = 0 THEN 'STATISTICS_NORECOMPUTE = OFF ' ELSE 'STATISTICS_NORECOMPUTE = ON' END + ','  + @enter + 
			-- default value  
			--CHAR(9) + 'DROP_EXISTING = ON'  + ','  + @enter + 
			-- default value  
			CHAR(9) + 'ONLINE = OFF'  + ','  + @enter + 
			CHAR(9) + CASE WHEN I.allow_row_locks = 1 THEN 'ALLOW_ROW_LOCKS = ON ' ELSE 'ALLOW_ROW_LOCKS = OFF ' END + ','  + @enter + 
			CHAR(9) + CASE WHEN I.allow_page_locks = 1 THEN 'ALLOW_PAGE_LOCKS = ON ' ELSE 'ALLOW_PAGE_LOCKS = OFF ' END  + @enter +
			') ON [' + DS.name + ' ] ' + @enter 
			[CreateIndexScript] 
			FROM sys.indexes I   
			JOIN sys.tables T ON T.Object_id = I.Object_id    
			JOIN sys.sysindexes SI ON I.Object_id = SI.id AND I.index_id = SI.indid   
			JOIN (
				SELECT * FROM (  
					SELECT 
						IC2.object_id, 
						IC2.index_id,  
						STUFF((
							SELECT 
								', [' + C.name + ']' + CASE WHEN MAX(CONVERT(INT,IC1.is_descending_key)) = 1 THEN ' DESC' ELSE ' ASC' END 
							FROM sys.index_columns IC1  
							JOIN Sys.columns C   
							ON C.object_id = IC1.object_id   
							AND C.column_id = IC1.column_id   
							AND IC1.is_included_column = 0  
							WHERE 
								IC1.object_id = IC2.object_id   
								AND 
								IC1.index_id = IC2.index_id   
							GROUP BY 
								IC1.object_id,C.name,index_id  
							ORDER BY MAX(IC1.key_ordinal)  
							FOR XML PATH('')
							), 
							1, 
							2,
							''
					) KeyColumns   
					FROM sys.index_columns IC2   
					--WHERE IC2.Object_id = object_id('Person.Address') --Comment for all tables  
					GROUP BY IC2.object_id ,IC2.index_id)
					tmp3
				)tmp4   
				ON I.object_id = tmp4.object_id AND I.Index_id = tmp4.index_id  
				JOIN sys.stats ST ON ST.object_id = I.object_id AND ST.stats_id = I.index_id   
				JOIN sys.data_spaces DS ON I.data_space_id=DS.data_space_id   
				JOIN sys.filegroups FG ON I.data_space_id=FG.data_space_id   
				LEFT JOIN (
					SELECT * FROM (   
						SELECT 
							IC2.object_id, 
							IC2.index_id,
							STUFF((
								SELECT ' , ' + '['+ C.name +']'
								FROM sys.index_columns IC1   
								JOIN Sys.columns C    
								ON C.object_id = IC1.object_id    
								AND C.column_id = IC1.column_id    
								AND IC1.is_included_column = 1   
								WHERE IC1.object_id = IC2.object_id    
								AND IC1.index_id = IC2.index_id    
								GROUP BY IC1.object_id,C.name,index_id   
								FOR XML PATH('')),
								1,
								2, 
								''
							)IncludedColumns 
						FROM sys.index_columns IC2    
						--WHERE IC2.Object_id = object_id('Person.Address') --Comment for all tables   
						GROUP BY IC2.object_id ,IC2.index_id) tmp1   
						WHERE IncludedColumns IS NOT NULL ) tmp2    
						ON tmp2.object_id = I.object_id AND tmp2.index_id = I.index_id   
						WHERE 
							I.name = @IndexName 
							--I.is_primary_key = 0 AND 
							--I.is_unique_constraint = 0 
							--AND I.Object_id = object_id('Person.Address') --Comment for all tables 
							--AND I.name = 'IX_Address_PostalCode' --comment for all indexes 
	)
 
	RETURN @script

END
GO


/****** Object:  UserDefinedFunction [dbo].[ForeignKeyScript]    Script Date: 13/03/1399 08:21:55 È.Ù ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


DROP FUNCTION IF EXISTS [dbo].[ForeignKeyScript]
GO
-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date, ,>
-- Description:	<Description, ,>
-- =============================================
CREATE FUNCTION [dbo].[ForeignKeyScript]
(
	-- Add the parameters for the function here
	@KeyName NVarChar(MAX)
)
RETURNS NVarChar(MAX)
AS
BEGIN
	declare @script NVarChar(MAX)
	set @script = (
	SELECT 
		N'ALTER TABLE ' + QUOTENAME(cs.name) + '.' + QUOTENAME(ct.name) + 
		' ADD CONSTRAINT ' + QUOTENAME(fk.name) + 
		' FOREIGN KEY (' + STUFF(
			(
				SELECT ',' + QUOTENAME(c.name)
				-- get all the columns in the constraint table
				FROM sys.columns AS c 
				INNER JOIN sys.foreign_key_columns AS fkc 
				ON fkc.parent_column_id = c.column_id
				AND fkc.parent_object_id = c.[object_id]
				WHERE fkc.constraint_object_id = fk.[object_id]
				ORDER BY fkc.constraint_column_id 
				FOR XML PATH(N''), TYPE
			).value(N'.[1]', N'nvarchar(max)'),
			1, 
			1,
			N''
		) +
		') REFERENCES ' + QUOTENAME(rs.name) + '.' + QUOTENAME(rt.name) + 
		'(' + STUFF(
			(
				SELECT ',' + QUOTENAME(c.name)
				-- get all the referenced columns
				FROM sys.columns AS c 
				INNER JOIN sys.foreign_key_columns AS fkc 
				ON fkc.referenced_column_id = c.column_id
				AND fkc.referenced_object_id = c.[object_id]
				WHERE fkc.constraint_object_id = fk.[object_id]
				ORDER BY fkc.constraint_column_id 
				FOR XML PATH(N''), TYPE
			).value(N'.[1]', N'nvarchar(max)'), 
			1, 
			1, 
			N''
		) + 
		');'
	FROM sys.foreign_keys AS fk
	INNER JOIN sys.tables AS rt -- referenced table
	  ON fk.referenced_object_id = rt.[object_id]
	INNER JOIN sys.schemas AS rs 
	  ON rt.[schema_id] = rs.[schema_id]
	INNER JOIN sys.tables AS ct -- constraint table
	  ON fk.parent_object_id = ct.[object_id]
	INNER JOIN sys.schemas AS cs 
	  ON ct.[schema_id] = cs.[schema_id]
	WHERE rt.is_ms_shipped = 0 AND ct.is_ms_shipped = 0 and fk.name = @KeyName)

	RETURN @script
END
GO


/****** Object:  StoredProcedure [dbo].[DropIdentityColumn]    Script Date: 13/03/1399 08:22:12 È.Ù ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

DROP PROCEDURE IF EXISTS [dbo].[DropIdentityColumn]
GO

-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
-- =============================================
CREATE PROCEDURE [dbo].[DropIdentityColumn]
	@schemaTable NVarChar(MAX),
	@currentIdentifierCol NVarChar(MAX) = 'ID',
	@tempIdentifierCol NVarChar(MAX) = 'IdentityID'
AS
BEGIN
	declare @schema NVarChar(MAX)
	declare @table NVarChar(MAX)

	set @schema = TRIM('[]' FROM LEFT(@schemaTable,CHARINDEX('.',@schemaTable)-1))
	set @table = TRIM('[]' FROM RIGHT(@schemaTable,LEN(@schemaTable) - CHARINDEX('.',@schemaTable)))

	declare @identityState BIT
	set @identityState = (select columnproperty(object_id(@table),@currentIdentifierCol,'IsIdentity'))
	if(@identityState is null)
		RETURN
	if(@identityState <> 1)
		RETURN

	print 'Executing DropIdentityColumn for schema: '+@schema
	print 'Executing DropIdentityColumn for table: '+@table
	declare @identity NVARCHAR(MAX)
	set @identity = CONCAT(@table,'.',@currentIdentifierCol)
	print 'Rename current ID column:'
	exec sp_rename @identity,@tempIdentifierCol

	declare @addColumn NVARCHAR(MAX)
	set @addColumn = CONCAT('alter table ',@table,' add ',@currentIdentifierCol,' INT')
	exec sp_executesql  @addColumn
	print 'New ID column:'
	print @addColumn

	declare @updateID NVARCHAR(MAX)
	set @updateID = CONCAT('update ',@table,' set ',@currentIdentifierCol,' = ',@tempIdentifierCol,' where ',@currentIdentifierCol,' is null')
	exec sp_executesql  @updateID
	print 'Update:'
	print @updateID

	declare @alter NVARCHAR(MAX)
	set @alter = CONCAT('alter table ',@table,' alter column ',@currentIdentifierCol,' INT NOT NULL')
	print @alter
	exec sp_executesql  @alter

	declare @index NVARCHAR(MAX)
	declare @indexDropScript NVarChar(MAX)
	declare @indexGenerateScript NVarChar(MAX)

	declare @CreateScripts TABLE (
		Position INT,
		Script NVarChar(MAX)
	)
	
	---FULLTEXT Indexes

	DECLARE @Catalog NVARCHAR(128),
			@SQL NVARCHAR(MAX),
			@COLS NVARCHAR(4000),
			@Owner NVARCHAR(128),
			@fullTextTable NVARCHAR(128),
			@ObjectID INT,
			@AccentOn BIT,
			@CatalogID INT,
			@IndexID INT,
			@Max_objectId INT,
			@NL CHAR(2),
			@i int
		
	SELECT @NL = CHAR(13) + CHAR(10) --Carriage Return

	-- Cursor to fetch the name of catalogs one by one for the current database
	declare FullTextIndexesCursor cursor for 
	SELECT Name FROM sys.fulltext_catalogs ORDER BY NAME 

	OPEN FullTextIndexesCursor

	FETCH FullTextIndexesCursor INTO @Catalog
	WHILE @@FETCH_status >= 0
	BEGIN
		-- Check catalog exists
		IF EXISTS(SELECT Name FROM sys.fulltext_catalogs WHERE Name = @Catalog) 
		BEGIN
			declare @fullTextCatalogCreateScript NVarChar(MAX)
			declare @fullTextIndexCreateScript NVarChar(MAX)
			-- Store the catalog details
			SELECT
				@CatalogID = i.fulltext_catalog_id,
				@ObjectID = 0,
				@Max_objectId = MAX(object_id),
				@AccentOn = is_accent_sensitivity_on
			FROM sys.fulltext_index_catalog_usages AS i
			JOIN sys.fulltext_catalogs c
				ON i.fulltext_catalog_id = c.fulltext_catalog_id
			WHERE c.Name = @Catalog
			GROUP BY	
				i.fulltext_catalog_id,
				is_accent_sensitivity_on

			-- Script out catalog
			set @fullTextCatalogCreateScript = 'IF NOT EXISTS (SELECT 1 FROM sys.fulltext_catalogs WHERE name = '''+@Catalog+''') CREATE FULLTEXT CATALOG ' + @Catalog + 'WITH ACCENT_SENSITIVITY = ' + CASE @AccentOn WHEN 1 THEN 'ON' ELSE 'OFF' END
		
			DECLARE FTObject CURSOR FOR 
			SELECT	
				MIN(i.object_id) objectId,
				u.name AS schemaName,
				t.Name,
				unique_index_id,
				c.name as catalogueName
			FROM sys.tables AS t
			JOIN sys.schemas AS u
				ON u.schema_id = t.schema_id
			JOIN sys.fulltext_indexes i
				ON t.object_id = i.object_id
			JOIN sys.fulltext_catalogs c
				ON i.fulltext_catalog_id = c.fulltext_catalog_id
			WHERE t.name = @table 
			AND c.Name = @Catalog
			--AND i.object_id > @ObjectID
			GROUP BY	
				u.name,
				t.Name,
				unique_index_id,
				c.name

			OPEN FTObject
		
			FETCH FTObject INTO @ObjectID, @Owner, @fullTextTable, @IndexID, @Catalog
			-- Loop through all fulltext indexes within catalog
			WHILE @@FETCH_status >= 0 
			BEGIN
				-- Script Fulltext Index
				SELECT
					@COLS = NULL,
					@SQL = 'CREATE FULLTEXT INDEX ON ' + QUOTENAME(@Owner) + '.' + QUOTENAME(@fullTextTable) + ' (' + @NL
			
				-- Script columns in index
				SELECT
					@COLS = COALESCE(@COLS + ',', '') + c.Name + ' Language ' + CAST(Language_id AS varchar) + ' ' + @NL
				FROM sys.fulltext_index_columns AS fi
					JOIN sys.columns AS c
					ON c.object_id = fi.object_id
					AND c.column_id = fi.column_id
				WHERE fi.object_id = @ObjectID

				-- Script unique key index
				SELECT
					@SQL = @SQL + @COLS + ') ' + @NL + 'KEY INDEX ' + i.Name + @NL + 'ON ' + @Catalog + @NL + 'WITH CHANGE_TRACKING ' + fi.change_tracking_state_desc + ';' + @NL
				FROM sys.indexes AS i
				JOIN sys.fulltext_indexes AS fi
					ON i.object_id = fi.object_id
				WHERE i.Object_ID = @ObjectID
					AND Index_Id = @IndexID

				-- Output script SQL
				set @fullTextIndexCreateScript = @SQL

				FETCH FTObject INTO @ObjectID, @Owner, @fullTextTable, @IndexID,@Catalog
			END
			CLOSE FTObject;
			DEALLOCATE FTObject;

			if(@fullTextTable is not null)
			begin
				--print @fullTextIndexCreateScript
				insert @CreateScripts VALUES(4,@fullTextIndexCreateScript)
				declare @dropFullText NVarChar(MAX)
				set @dropFullText = 'DROP FULLTEXT INDEX ON '+@fullTextTable
				print @dropFullText 
				exec sp_executesql @dropFullText
			end
			else
			begin
				print 'NO FULLTEXT catalog found for table '+@table
			end
		END
		ELSE
		BEGIN
			PRINT 'Catalog '+@catalog+' does not exists'
		END
		FETCH FullTextIndexesCursor INTO @catalog
	END
	CLOSE FullTextIndexesCursor
	DEALLOCATE FullTextIndexesCursor

	---DROP KEYS
	print 'Dropping Keys'

	declare @foreinKeys TABLE (
		PKTABLE_QUALIFIER NVarChar(MAX),
		PKTABLE_OWNER NVarChar(MAX),
		PKTABLE_NAME NVarChar(MAX),
		PKCOLUMN_NAME NVarChar(MAX),
		FKTABLE_QUALIFIER NVarChar(MAX),
		FKTABLE_OWNER NVarChar(MAX),
		FKTABLE_NAME NVarChar(MAX),
		FKCOLUMN_NAME NVarChar(MAX),
		KEY_SEQ INT,
		UPDATE_RULE INT,
		DELETE_RULE INT,
		FK_NAME NVarChar(MAX),
		PK_NAME NVarChar(MAX),
		DEFERRABILITY INT
	)
	INSERT INTO @foreinKeys
	EXEC sp_fkeys @pktable_name = @table, @pktable_owner = 'dbo'

	DECLARE ForeignKeesCursor Cursor FOR
	select FK_NAME, FKTABLE_NAME from @foreinKeys where PKCOLUMN_NAME = @tempIdentifierCol

	declare @key NVarChar(MAX)
	declare @keyTable NVarChar(MAX)
	declare @keyDropScript NVarChar(MAX)
	declare @keyGenerateScript NVarChar(MAX)

	OPEN ForeignKeesCursor 
	FETCH NEXT FROM ForeignKeesCursor INTO @Key, @keyTable
	WHILE @@FETCH_STATUS=0
	begin
		set @keyDropScript = CONCAT('ALTER TABLE [dbo].[',@keyTable,'] DROP CONSTRAINT [',@key,'] WITH ( ONLINE = OFF )')

		set @keyGenerateScript = dbo.ForeignKeyScript(@key)
		set @keyGenerateScript = REPLACE(@keyGenerateScript,@tempIdentifierCol,@currentIdentifierCol)
		insert into @CreateScripts VALUES (2,@keyGenerateScript)

		print 'Drop Key:'
		print @keyDropScript 
		exec sp_executesql @keyDropScript

		FETCH NEXT FROM ForeignKeesCursor INTO @key, @keyTable
	end
	CLOSE ForeignKeesCursor
	DEALLOCATE ForeignKeesCursor 

	------------------------------PRIMARY KEY
	print 'Dropping Primary Key'

	declare @primaryKeyDropScript NVarChar(MAX)
	declare @primaryKeyGenerateScript NVarChar(MAX)

	declare PrimaryKeysCursor CURSOR FOR
		SELECT 
			IndexName = indexes.name
		FROM 
			 sys.indexes indexes
		INNER JOIN 
			 sys.index_columns indexColumns ON  indexes.object_id = indexColumns.object_id and indexes.index_id = indexColumns.index_id 
		INNER JOIN 
			 sys.columns columns ON indexColumns.object_id = columns.object_id and indexColumns.column_id = columns.column_id 
		INNER JOIN 
			 sys.tables tables ON indexes.object_id = tables.object_id 
		WHERE 
			 indexes.is_primary_key = 1
			 and 
			 columns.name = @tempIdentifierCol
			 and 
			 tables.name = @table
		ORDER BY 
			 tables.name, indexes.name, indexes.index_id, indexColumns.index_column_id

	OPEN PrimaryKeysCursor 

	FETCH NEXT FROM PrimaryKeysCursor INTO @index
	WHILE @@FETCH_STATUS = 0
	BEGIN
		set @primaryKeyDropScript = CONCAT('ALTER TABLE [dbo].[',@table,'] DROP CONSTRAINT [',@index,'] WITH ( ONLINE = OFF )')

		set @primaryKeyGenerateScript = CONCAT('
			ALTER TABLE dbo.',@table,' ADD CONSTRAINT
			',@index,' PRIMARY KEY CLUSTERED 
			(
			',@currentIdentifierCol,'
			) WITH( STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]'
		)
		insert into @CreateScripts VALUES (1,@primaryKeyGenerateScript)

		print 'Drop Primary Key:'
		print @primaryKeyDropScript
		exec sp_executesql @primaryKeyDropScript

		FETCH NEXT FROM PrimaryKeysCursor INTO @index
	END

	CLOSE PrimaryKeysCursor 
	DEALLOCATE PrimaryKeysCursor 

	----------------------
	print 'Dropping Indexes depend on '+@tempIdentifierCol

	declare IndexesCursor CURSOR FOR
		SELECT 
			IndexName = indexes.name
		FROM 
			 sys.indexes indexes
		INNER JOIN 
			 sys.index_columns indexColumns ON  indexes.object_id = indexColumns.object_id and indexes.index_id = indexColumns.index_id 
		INNER JOIN 
			 sys.columns columns ON indexColumns.object_id = columns.object_id and indexColumns.column_id = columns.column_id 
		INNER JOIN 
			 sys.tables tables ON indexes.object_id = tables.object_id 
		WHERE 
			indexes.is_primary_key = 0
			and 
			columns.name = @tempIdentifierCol
			and 
			tables.name = @table
		ORDER BY 
			 tables.name, indexes.name, indexes.index_id, indexColumns.index_column_id

	OPEN IndexesCursor

	FETCH NEXT FROM IndexesCursor INTO @index
	WHILE @@FETCH_STATUS = 0
	BEGIN
		--set @indexDropScript = CONCAT('ALTER TABLE [dbo].[',@table,'] DROP CONSTRAINT [',@index,'] WITH ( ONLINE = OFF )')
		set @indexDropScript = CONCAT('DROP INDEX [',@index,'] ON [dbo].[',@table,']')

		set @indexGenerateScript = dbo.IndexScript(@index)
		set @indexGenerateScript = REPLACE(@indexGenerateScript,@tempIdentifierCol,@currentIdentifierCol)
		insert into @CreateScripts VALUES (3,@indexGenerateScript)

		print 'Drop Index:'
		print @indexDropScript
		exec sp_executesql @indexDropScript

		FETCH NEXT FROM IndexesCursor INTO @index
	END

	CLOSE IndexesCursor 
	DEALLOCATE IndexesCursor 

	--------------------
	
	print 'Dropping Old Identity Column'

	declare @dropIdentityID NVARCHAR(MAX)
	set @dropIdentityID = CONCAT('alter table ',@table,' drop column ',@tempIdentifierCol)
	print @dropIdentityID
	exec sp_executesql  @dropIdentityID

	----------------------
	declare CreateScriptsCursor CURSOR FOR
		SELECT Script FROM @CreateScripts order by Position asc

	OPEN CreateScriptsCursor

	declare @script NVarChar(MAX)

	FETCH NEXT FROM CreateScriptsCursor INTO @script
	WHILE @@FETCH_STATUS = 0
	BEGIN
		PRINT 'Executing script:'
		Print @script
		exec sp_executesql @script

		FETCH NEXT FROM CreateScriptsCursor INTO @script
	END

	CLOSE CreateScriptsCursor 
	DEALLOCATE CreateScriptsCursor 
END
GO


