-- usp_PurchaseSpaceRanger: shared purchase entry point called by the webshop.
-- Rewritten for the MicroHack framework: instead of a hardcoded TailspinToys_User001..100
-- loop, it discovers every per-attendee database by name pattern and fans a purchase
-- out to Demo_Final plus each attendee database that currently exists.
USE [TailspinToys_Demo_Final]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER PROC [dbo].[usp_PurchaseSpaceRanger]
  @CustomerName nvarchar(200),
  @Email        nvarchar(320),
  @Amount       INT
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @SQLCMD_TEMPLATE NVARCHAR(MAX)
  DECLARE @SQLCMD NVARCHAR(MAX)
  DECLARE @DBNAME NVARCHAR(128)

  SET @SQLCMD_TEMPLATE = '
    BEGIN TRAN;

    DECLARE @CustomerId       int;
    DECLARE @ProductId        int;
    DECLARE @Price            decimal(9,2) = 49.99;
    DECLARE @DiscountAmount   decimal(9,2) = 10.00;
    DECLARE @CustomerStateID  int;

    -- Pick product
    SELECT TOP (1)
      @ProductId = ProductId
    FROM [##db-name##].dbo.Product
    WHERE ProductName LIKE ''%Fabric Space Ranger%'';

    IF @ProductId IS NULL
      THROW 50001, ''Product not found (Fabric Space Ranger).'', 1;

    -- Random state id 1..51
    SET @CustomerStateID = 1 + ABS(CHECKSUM(NEWID())) % 51;

    -- Insert customer
    INSERT INTO [##db-name##].dbo.Customer (CustomerName, Email,Country,DateCreated)
    VALUES (@CustomerName, @Email,''MicroHack'', GETDATE());

    SET @CustomerId = SCOPE_IDENTITY();

    -- Insert sales row
    INSERT INTO [##db-name##].dbo.Sales
      (OrderDate, ShipDate, CustomerStateID, ProductID, Quantity, UnitPrice,
       DiscountAmount, PromotionCode, CustomerID, TotalPrice)
    VALUES
      (GETDATE(), NULL,
       @CustomerStateID,
       @ProductId,
       @Amount,
       @Price,
       @DiscountAmount,
       ''LaunchDay'',
       @CustomerId,
       (@Price - @DiscountAmount) * @Amount);

    COMMIT;'

  -- Iterate over Demo_Final plus every per-attendee TailspinToys database.
  DECLARE db_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT name FROM sys.databases
    WHERE name = 'TailspinToys_Demo_Final'
       OR (name LIKE 'TailspinToys[_]%'
           AND name NOT LIKE 'TailspinToysFeedback[_]%'
           AND name NOT LIKE '%[_]Demo[_]%')

  OPEN db_cursor
  FETCH NEXT FROM db_cursor INTO @DBNAME
  WHILE @@FETCH_STATUS = 0
  BEGIN
    SET @SQLCMD = REPLACE(@SQLCMD_TEMPLATE,'##db-name##',@DBNAME)
    BEGIN TRY
      EXECUTE sp_executesql @SQLCMD,
        N'@CustomerName NVARCHAR(200), @Email NVARCHAR(320), @Amount INT',
        @CustomerName=@CustomerName, @Email=@Email, @Amount=@Amount
    END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0 ROLLBACK;
      PRINT ERROR_MESSAGE()
    END CATCH
    FETCH NEXT FROM db_cursor INTO @DBNAME
  END
  CLOSE db_cursor
  DEALLOCATE db_cursor
END;
GO
