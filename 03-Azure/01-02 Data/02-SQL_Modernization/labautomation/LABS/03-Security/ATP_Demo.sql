--Advanced Threat Protection
DECLARE @UserInput nvarchar(max) = ''' OR 1=1--';
DECLARE @SQL nvarchar(max) = 'SELECT * FROM sys.databases WHERE name = ''' + @UserInput + '''';
EXEC(@SQL);
