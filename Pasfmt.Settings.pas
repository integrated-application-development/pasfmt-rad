unit Pasfmt.Settings;

interface

uses Pasfmt.Log, System.Win.Registry;

type
  TPasfmtSettings = class(TObject)
  private
    const
      CLogLevelName = 'Log Level';
      CExecutablePathName = 'Executable Path';
      CFormatOnSaveName = 'Format On Save';
      CFormatTimeoutName = 'Format Timeout';
  private
    FRegistry: TRegistry;
    FBaseKey: string;

    FLogLevel: TLogLevel;
    FExecutablePath: string;
    FFormatOnSave: Boolean;
    FFormatTimeout: Integer;

    procedure SetLogLevel(Value: TLogLevel);
    procedure SetExecutablePath(Value: string);
    procedure SetFormatOnSave(Value: Boolean);
    procedure SetFormatTimeout(Value: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Load;

    property LogLevel: TLogLevel read FLogLevel write SetLogLevel;
    property ExecutablePath: string read FExecutablePath write SetExecutablePath;
    property FormatOnSave: Boolean read FFormatOnSave write SetFormatOnSave;
    property FormatTimeout: Integer read FFormatTimeout write SetFormatTimeout;
  end;

function PasfmtSettings: TPasfmtSettings;

implementation

uses ToolsAPI, System.SysUtils, Winapi.Windows;

var
  GSettings: TPasfmtSettings;

  //______________________________________________________________________________________________________________________

function PasfmtSettings: TPasfmtSettings;
begin
  if not Assigned(GSettings) then begin
    GSettings := TPasfmtSettings.Create;
    GSettings.Load;
  end;

  Result := GSettings;
end;

//______________________________________________________________________________________________________________________

constructor TPasfmtSettings.Create;
begin
  FBaseKey := (BorlandIDEServices as IOTAServices).GetBaseRegistryKey + '\Pasfmt';
  FRegistry := TRegistry.Create(KEY_ALL_ACCESS);
  FRegistry.RootKey := HKEY_CURRENT_USER;
end;

//______________________________________________________________________________________________________________________

destructor TPasfmtSettings.Destroy;
begin
  FreeAndNil(FRegistry);
  inherited;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettings.SetExecutablePath(Value: string);
begin
  FExecutablePath := Value;

  FRegistry.OpenKey(FBaseKey, True);
  try
    FRegistry.WriteString(CExecutablePathName, Value);
  finally
    FRegistry.CloseKey;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettings.SetFormatOnSave(Value: Boolean);
begin
  FFormatOnSave := Value;

  FRegistry.OpenKey(FBaseKey, True);
  try
    FRegistry.WriteBool(CFormatOnSaveName, Value);
  finally
    FRegistry.CloseKey;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettings.SetFormatTimeout(Value: Integer);
begin
  FFormatTimeout := Value;

  FRegistry.OpenKey(FBaseKey, True);
  try
    FRegistry.WriteInteger(CFormatTimeoutName, Value);
  finally
    FRegistry.CloseKey;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettings.SetLogLevel(Value: TLogLevel);
begin
  FLogLevel := Value;

  FRegistry.OpenKey(FBaseKey, True);
  try
    FRegistry.WriteInteger(CLogLevelName, Ord(Value));
  finally
    FRegistry.CloseKey;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettings.Load;
begin
  FRegistry.OpenKey(FBaseKey, True);
  try
    FLogLevel := llWarn;
    FExecutablePath := '';
    FFormatOnSave := False;
    FFormatTimeout := 500;

    if FRegistry.ValueExists(CLogLevelName) then
      FLogLevel := TLogLevel(FRegistry.ReadInteger(CLogLevelName))
    else
      FRegistry.WriteInteger(CLogLevelName, Ord(FLogLevel));

    if FRegistry.ValueExists(CExecutablePathName) then
      FExecutablePath := FRegistry.ReadString(CExecutablePathName)
    else
      FRegistry.WriteString(CExecutablePathName, FExecutablePath);

    if FRegistry.ValueExists(CFormatOnSaveName) then
      FFormatOnSave := FRegistry.ReadBool(CFormatOnSaveName)
    else
      FRegistry.WriteBool(CFormatOnSaveName, FFormatOnSave);

    if FRegistry.ValueExists(CFormatTimeoutName) then
      FFormatTimeout := FRegistry.ReadInteger(CFormatTimeoutName)
    else
      FRegistry.WriteInteger(CFormatTimeoutName, FFormatTimeout);
  finally
    FRegistry.CloseKey;
  end;
end;

//______________________________________________________________________________________________________________________

initialization
finalization
  FreeAndNil(GSettings);

end.
