ALTER TABLE flow_definition ADD create_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_definition_create_by DEFAULT '';
GO

ALTER TABLE flow_definition ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_definition_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'创建人',
'SCHEMA', N'dbo',
'TABLE', N'flow_definition',
'COLUMN', N'create_by'
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_definition',
'COLUMN', N'update_by'
GO

ALTER TABLE flow_node ADD create_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_node_create_by DEFAULT '';
GO

ALTER TABLE flow_node ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_node_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'创建人',
'SCHEMA', N'dbo',
'TABLE', N'flow_node',
'COLUMN', N'create_by'
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_node',
'COLUMN', N'update_by'
GO

ALTER TABLE flow_skip ADD create_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_skip_create_by DEFAULT '';
GO

ALTER TABLE flow_skip ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_skip_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'创建人',
'SCHEMA', N'dbo',
'TABLE', N'flow_skip',
'COLUMN', N'create_by'
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_skip',
'COLUMN', N'update_by'
GO

ALTER TABLE flow_instance ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_instance_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_instance',
'COLUMN', N'update_by'
GO

ALTER TABLE flow_task ADD create_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_task_create_by DEFAULT '';
GO

ALTER TABLE flow_task ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_task_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'创建人',
'SCHEMA', N'dbo',
'TABLE', N'flow_task',
'COLUMN', N'create_by'
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_task',
'COLUMN', N'update_by'
GO

ALTER TABLE flow_user ADD update_by nvarchar(64) NOT NULL CONSTRAINT DF_flow_user_update_by DEFAULT '';
GO

EXEC sp_addextendedproperty
'MS_Description', N'更新人',
'SCHEMA', N'dbo',
'TABLE', N'flow_user',
'COLUMN', N'update_by'
GO
