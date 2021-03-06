set ansi_nulls on
go
set quoted_identifier on
go
create procedure [dbo].[commandexecute]

@command nvarchar(max),
@commandtype nvarchar(max),
@mode int,
@comment nvarchar(max) = null,
@databasename nvarchar(max) = null,
@schemaname nvarchar(max) = null,
@objectname nvarchar(max) = null,
@objecttype nvarchar(max) = null,
@indexname nvarchar(max) = null,
@indextype int = null,
@statisticsname nvarchar(max) = null,
@partitionnumber int = null,
@extendedinfo xml = null,
@logtotable nvarchar(max),
@execute nvarchar(max)

as

begin

  ----------------------------------------------------------------------------------------------------
  --// source: https://ola.hallengren.com                                                          //--
  ----------------------------------------------------------------------------------------------------

  set nocount on

  declare @startmessage nvarchar(max)
  declare @endmessage nvarchar(max)
  declare @errormessage nvarchar(max)
  declare @errormessageoriginal nvarchar(max)

  declare @starttime datetime
  declare @endtime datetime

  declare @starttimesec datetime
  declare @endtimesec datetime

  declare @id int

  declare @error int
  declare @returncode int

  set @error = 0
  set @returncode = 0

  ----------------------------------------------------------------------------------------------------
  --// check core requirements                                                                    //--
  ----------------------------------------------------------------------------------------------------

  if @logtotable = 'y' and not exists (select * from sys.objects objects inner join sys.schemas schemas on objects.[schema_id] = schemas.[schema_id] where objects.[type] = 'u' and schemas.[name] = 'dbo' and objects.[name] = 'commandlog')
  begin
    set @errormessage = 'the table commandlog is missing. download https://ola.hallengren.com/scripts/commandlog.sql.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @error <> 0
  begin
    set @returncode = @error
    goto returncode
  end

  ----------------------------------------------------------------------------------------------------
  --// check input parameters                                                                     //--
  ----------------------------------------------------------------------------------------------------

  if @command is null or @command = ''
  begin
    set @errormessage = 'the value for the parameter @command is not supported.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @commandtype is null or @commandtype = '' or len(@commandtype) > 60
  begin
    set @errormessage = 'the value for the parameter @commandtype is not supported.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @mode not in(1,2) or @mode is null
  begin
    set @errormessage = 'the value for the parameter @mode is not supported.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @logtotable not in('y','n') or @logtotable is null
  begin
    set @errormessage = 'the value for the parameter @logtotable is not supported.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @execute not in('y','n') or @execute is null
  begin
    set @errormessage = 'the value for the parameter @execute is not supported.' + char(13) + char(10) + ' '
    raiserror(@errormessage,16,1) with nowait
    set @error = @@error
  end

  if @error <> 0
  begin
    set @returncode = @error
    goto returncode
  end

  ----------------------------------------------------------------------------------------------------
  --// log initial information                                                                    //--
  ----------------------------------------------------------------------------------------------------

  set @starttime = getdate()
  set @starttimesec = convert(datetime,convert(nvarchar,@starttime,120),120)

  set @startmessage = 'date and time: ' + convert(nvarchar,@starttimesec,120) + char(13) + char(10)
  set @startmessage = @startmessage + 'command: ' + @command
  if @comment is not null set @startmessage = @startmessage + char(13) + char(10) + 'comment: ' + @comment
  set @startmessage = replace(@startmessage,'%','%%')
  raiserror(@startmessage,10,1) with nowait

  if @logtotable = 'y'
  begin
    insert into dbo.commandlog (databasename, schemaname, objectname, objecttype, indexname, indextype, statisticsname, partitionnumber, extendedinfo, commandtype, command, starttime)
    values (@databasename, @schemaname, @objectname, @objecttype, @indexname, @indextype, @statisticsname, @partitionnumber, @extendedinfo, @commandtype, @command, @starttime)
  end

  set @id = scope_identity()

  ----------------------------------------------------------------------------------------------------
  --// execute command                                                                            //--
  ----------------------------------------------------------------------------------------------------

  if @mode = 1 and @execute = 'y'
  begin
    execute(@command)
    set @error = @@error
    set @returncode = @error
  end

  if @mode = 2 and @execute = 'y'
  begin
    begin try
      execute(@command)
    end try
    begin catch
      set @error = error_number()
      set @returncode = @error
      set @errormessageoriginal = error_message()
      set @errormessage = 'msg ' + cast(@error as nvarchar) + ', ' + isnull(@errormessageoriginal,'')
      raiserror(@errormessage,16,1) with nowait
    end catch
  end

  ----------------------------------------------------------------------------------------------------
  --// log completing information                                                                 //--
  ----------------------------------------------------------------------------------------------------

  set @endtime = getdate()
  set @endtimesec = convert(datetime,convert(varchar,@endtime,120),120)

  set @endmessage = 'outcome: ' + case when @execute = 'n' then 'not executed' when @error = 0 then 'succeeded' else 'failed' end + char(13) + char(10)
  set @endmessage = @endmessage + 'duration: ' + case when datediff(ss,@starttimesec, @endtimesec)/(24*3600) > 0 then cast(datediff(ss,@starttimesec, @endtimesec)/(24*3600) as nvarchar) + '.' else '' end + convert(nvarchar,@endtimesec - @starttimesec,108) + char(13) + char(10)
  set @endmessage = @endmessage + 'date and time: ' + convert(nvarchar,@endtimesec,120) + char(13) + char(10) + ' '
  set @endmessage = replace(@endmessage,'%','%%')
  raiserror(@endmessage,10,1) with nowait

  if @logtotable = 'y'
  begin
    update dbo.commandlog
    set endtime = @endtime,
        errornumber = case when @execute = 'n' then null else @error end,
        errormessage = @errormessageoriginal
    where id = @id
  end

  returncode:
  if @returncode <> 0
  begin
    return @returncode
  end

  ----------------------------------------------------------------------------------------------------

end
go
