unit Pasfmt.Log;

interface

type
  TLogLevel = (llDebug, llInfo, llWarn, llError, llNone);

  ILogger = interface
    ['{722CD5E4-CD6F-4DDA-85E7-C598AFB4E314}']
    procedure Debug(Msg: string); overload;
    procedure Debug(Msg: string; Args: array of const); overload;
    procedure Warn(Msg: string); overload;
    procedure Warn(Msg: string; Args: array of const); overload;
    procedure Error(Msg: string); overload;
    procedure Error(Msg: string; Args: array of const); overload;
    procedure Info(Msg: string); overload;
    procedure Info(Msg: string; Args: array of const); overload;

    procedure SetLogLevel(LogLevel: TLogLevel);
  end;

function Log: ILogger;

implementation

uses ToolsAPI, System.SysUtils, Pasfmt.Settings;

type
  TMessageWindowLogger = class(TNotifierObject, ILogger, IOTAMessageNotifier)
  private
    FGroup: IOTAMessageGroup;
    FLogLevel: TLogLevel;
    FNotifierIndex: Integer;

    procedure Log(Msg: string; Prefix: string);
    procedure EnsureGroup;
    procedure MessageGroupAdded(const Group: IOTAMessageGroup);
    procedure MessageGroupDeleted(const Group: IOTAMessageGroup);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Cleanup;

    procedure Debug(Msg: string); overload;
    procedure Debug(Msg: string; Args: array of const); overload;
    procedure Warn(Msg: string); overload;
    procedure Warn(Msg: string; Args: array of const); overload;
    procedure Error(Msg: string); overload;
    procedure Error(Msg: string; Args: array of const); overload;
    procedure Info(Msg: string); overload;
    procedure Info(Msg: string; Args: array of const); overload;

    procedure SetLogLevel(LogLevel: TLogLevel);
  end;

//______________________________________________________________________________________________________________________

var
  GLog: ILogger;

function Log: ILogger;
begin
  if not Assigned(GLog) then begin
    GLog := TMessageWindowLogger.Create;
    GLog.SetLogLevel(PasfmtSettings.LogLevel);
  end;

  Result := GLog;
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.Cleanup;
begin
  (BorlandIDEServices as IOTAMessageServices).RemoveNotifier(FNotifierIndex);
end;

constructor TMessageWindowLogger.Create;
begin
  FLogLevel := llDebug;
  FNotifierIndex := (BorlandIDEServices as IOTAMessageServices).AddNotifier(Self);
end;

//______________________________________________________________________________________________________________________

destructor TMessageWindowLogger.Destroy;
begin
  if Assigned(FGroup) then begin
    (BorlandIDEServices as IOTAMessageServices).RemoveMessageGroup(FGroup);
  end;

  inherited;
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.EnsureGroup;
begin
  if not Assigned(FGroup) then begin
    FGroup := (BorlandIDEServices as IOTAMessageServices).AddMessageGroup('Pasfmt');
    (BorlandIDEServices as IOTAMessageServices).ClearMessageGroup(FGroup);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.Debug(Msg: string);
begin
  if FLogLevel > llDebug then
    Exit;

  Log(Msg, 'DEBUG');
end;

procedure TMessageWindowLogger.Debug(Msg: string; Args: array of const);
begin
  if FLogLevel > llDebug then
    Exit;

  Debug(Format(Msg, Args));
end;

procedure TMessageWindowLogger.Error(Msg: string);
begin
  if FLogLevel > llError then
    Exit;

  Log(Msg, 'ERROR');
end;

procedure TMessageWindowLogger.Error(Msg: string; Args: array of const);
begin
  if FLogLevel > llError then
    Exit;

  Error(Format(Msg, Args));
end;

procedure TMessageWindowLogger.Info(Msg: string);
begin
  if FLogLevel > llInfo then
    Exit;

  Log(Msg, 'INFO');
end;

procedure TMessageWindowLogger.Info(Msg: string; Args: array of const);
begin
  if FLogLevel > llInfo then
    Exit;

  Info(Format(Msg, Args));
end;

procedure TMessageWindowLogger.Warn(Msg: string);
begin
  if FLogLevel > llWarn then
    Exit;

  Log(Msg, 'WARN');
end;

procedure TMessageWindowLogger.Warn(Msg: string; Args: array of const);
begin
  if FLogLevel > llWarn then
    Exit;

  Warn(Format(Msg, Args));
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.Log(Msg: string; Prefix: string);
var
  Dummy: Pointer;
begin
  EnsureGroup;
  (BorlandIDEServices as IOTAMessageServices).AddToolMessage('', Msg, Prefix, 0, 0, nil, Dummy, FGroup);
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.SetLogLevel(LogLevel: TLogLevel);
begin
  FLogLevel := LogLevel;
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.MessageGroupAdded(const Group: IOTAMessageGroup);
begin
  // No-op to implement interface
end;

//______________________________________________________________________________________________________________________

procedure TMessageWindowLogger.MessageGroupDeleted(const Group: IOTAMessageGroup);
begin
  if Assigned(FGroup) and (Group = FGroup) then begin
    // The user has closed the message group
    FGroup := nil;
  end;
end;

//______________________________________________________________________________________________________________________

initialization
finalization
  if Assigned(GLog) then begin
    TMessageWindowLogger(GLog).Cleanup;
    GLog := nil;
  end;

end.
