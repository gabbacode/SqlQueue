﻿CREATE TABLE [Queue_Schema_Name].[Messages2] (
    [ID]      BIGINT           NOT NULL,
    [Created] DATETIME2 (7)    NOT NULL,
    [Body]    VARBINARY (8000) NOT NULL,
    PRIMARY KEY NONCLUSTERED HASH ([ID]) WITH (BUCKET_COUNT = 1048576)
)
WITH (MEMORY_OPTIMIZED = ON);

