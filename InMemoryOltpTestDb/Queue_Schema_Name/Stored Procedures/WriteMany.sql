﻿
CREATE PROCEDURE [Queue_Schema_Name].[WriteMany] 
    @messageList Queue_Schema_Name.MessageList READONLY,
    @returnIDs bit
  WITH NATIVE_COMPILATION, SCHEMABINDING, EXECUTE AS OWNER
  AS 
  BEGIN ATOMIC 
  WITH (TRANSACTION ISOLATION LEVEL = SNAPSHOT, LANGUAGE = N'us_english')

declare @date datetime2(7) = sysutcdatetime()
declare @stateUpdated bit = 0

declare @IsFirstActive bit
declare @MaxID1 bigint
declare @MaxID2 bigint
declare @Num1 int
declare @Num2 int
declare @NeedClean1 bit
declare @NeedClean2 bit
declare @MinNum int
declare @TresholdNum int

declare @lastID bigint

declare @cnt int = (select count(*) from @messageList)

if (@cnt = 0)
    return;

select top 1 @IsFirstActive = IsFirstActive, @MaxID1 = MaxID1, @MaxID2 = MaxID2,
    @Num1 = Num1, @Num2 = Num2, @NeedClean1 = NeedClean1, @NeedClean2 = NeedClean2, 
    @MinNum = MinNum, @TresholdNum = TresholdNum
from [Queue_Schema_Name].[State]

if (@MaxID1 is null)
begin
    exec [Queue_Schema_Name].[RestoreState]

    select top 1 @IsFirstActive = IsFirstActive, @MaxID1 = MaxID1, @MaxID2 = MaxID2,
        @Num1 = Num1, @Num2 = Num2, @NeedClean1 = NeedClean1, @NeedClean2 = NeedClean2, 
        @MinNum = MinNum, @TresholdNum = TresholdNum
    from [Queue_Schema_Name].[State]
end

-- всегда оставляем последнее сообщение
if (@MinNum < 1)
    set @MinNum = 1

-- если можем очистить другую таблицу, то помечаем для очистки
if (@IsFirstActive = 1 and @Num1 >= @MinNum and @MaxID2 > 0 and @NeedClean2 = 0)
begin
    update [Queue_Schema_Name].[State]
    set Modified = @date, NeedClean2 = 1
end
else if (@IsFirstActive = 0 and @Num2 >= @MinNum and @MaxID1 > 0 and @NeedClean1 = 0)
begin
    update [Queue_Schema_Name].[State]
    set Modified = @date, NeedClean1 = 1
end


-- если превысили количество сообщений и другая таблица свободна, то переключаемся
if (@IsFirstActive = 1 and @Num1 >= @TresholdNum and @MaxID2 = 0)
begin
    set @IsFirstActive = 0
    set @lastID = @MaxID1

    update [Queue_Schema_Name].[State]
    set Modified = @date, MinID2 = @MaxID1 + 1, MaxID2 = @MaxID1 + @cnt, Num2 = @cnt, IsFirstActive = 0

    set @stateUpdated = 1
end
else if (@IsFirstActive = 0 and @Num2 >= @TresholdNum and @MaxID1 = 0)
begin
    set @IsFirstActive = 1
    set @lastID = @MaxID2

    update [Queue_Schema_Name].[State]
    set Modified = @date, MinID1 = @MaxID2 + 1, MaxID1 = @MaxID2 + @cnt, Num1 = @cnt, IsFirstActive = 1

    set @stateUpdated = 1
end


if (@IsFirstActive = 1)
begin
    if (@stateUpdated = 0)
    begin
        set @lastID = @MaxID1

        update [Queue_Schema_Name].[State]
	    set Modified = @date, MaxID1 = @MaxID1 + @cnt, Num1 = @Num1 + @cnt
    end

    insert into [Queue_Schema_Name].Messages1 (ID, Created, Body)
    select @lastID + ID, @date, Body
    from @messageList
    order by ID
end
else
begin
    if (@stateUpdated = 0)
    begin
        set @lastID = @MaxID2

        update [Queue_Schema_Name].[State]
        set Modified = @date, MaxID2 = @MaxID2 + @cnt, Num2 = @Num2 + @cnt
    end

    insert into [Queue_Schema_Name].Messages2 (ID, Created, Body)
    select @lastID + ID, @date, Body
    from @messageList
    order by ID
end

if (@returnIDs = 1)
begin
    select @lastID + ID
    from @messageList
    order by ID
end

END