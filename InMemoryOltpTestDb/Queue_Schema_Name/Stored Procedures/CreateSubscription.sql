﻿




CREATE PROCEDURE [Queue_Schema_Name].[CreateSubscription]
  @name nvarchar(255),
  @subscriptionID int out
  WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
  AS 
  BEGIN ATOMIC 
  WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')


declare @MaxID1 int
declare @MaxID2 int
declare @IsFirstActive bit

select top 1 @MaxID1 = MaxID1, @MaxID2 = MaxID2, @IsFirstActive = IsFirstActive
from [Queue_Schema_Name].[State]

if (@MaxID1 is null)
begin
    exec [Queue_Schema_Name].[RestoreState]

    select top 1 @MaxID1 = MaxID1, @MaxID2 = MaxID2, @IsFirstActive = IsFirstActive
    from [Queue_Schema_Name].[State]
end


if (@IsFirstActive = 1)
    insert into [Queue_Schema_Name].[Subscription] ([Name], [LastCompletedID], [LastCompletedTime], [Disabled])
    values (@name, @MaxID1, sysutcdatetime(), 0)
else
    insert into [Queue_Schema_Name].[Subscription] ([Name], [LastCompletedID], [LastCompletedTime], [Disabled])
    values (@name, @MaxID2, sysutcdatetime(), 0)

set @subscriptionID = scope_identity()

END