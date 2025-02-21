unit Pasfmt.OnSave;

interface

uses
  ToolsAPI,
  System.Classes,
  DockForm,
  System.Generics.Collections,
  Pasfmt.FormatEditor;

type
  TConfigureFormatterProc = reference to procedure(var Formatter: TEditBufferFormatter);

  TFormatOnSaveInstallerNotifier = class(TNotifierObject, INTAEditServicesNotifier)
  private
    FFormatOnSaveModules: TDictionary<IOTAModule, Integer>;
    FConfigureFormatterProc: TConfigureFormatterProc;
  public
    constructor Create;
    destructor Destroy; override;

    procedure OnFormatOnSaveNotifierDestroyed(Sender: TObject);
    procedure UninstallAll;

    procedure WindowShow(const EditWindow: INTAEditWindow; Show: Boolean; LoadedFromDesktop: Boolean);
    procedure WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
    procedure WindowActivated(const EditWindow: INTAEditWindow);
    procedure WindowCommand(const EditWindow: INTAEditWindow; Command: Integer; Param: Integer; var Handled: Boolean);
    procedure EditorViewModified(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure EditorViewActivated(const EditWindow: INTAEditWindow; const EditView: IOTAEditView);
    procedure DockFormVisibleChanged(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
    procedure DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);

    property ConfigureFormatter: TConfigureFormatterProc read FConfigureFormatterProc write FConfigureFormatterProc;
  end;

  TFormatOnSaveModuleNotifier = class(TNotifierObject, IOTAModuleNotifier)
  private
    FModule: IOTAModule;
    FOnDestroyed: TNotifyEvent;
    FConfigureFormatterProc: TConfigureFormatterProc;
  public
    constructor Create(Module: IOTAModule);

    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;
    function CheckOverwrite: Boolean;
    procedure ModuleRenamed(const NewName: string);

    property Module: IOTAModule read FModule;
    property OnDestroyed: TNotifyEvent read FOnDestroyed write FOnDestroyed;
    property ConfigureFormatter: TConfigureFormatterProc read FConfigureFormatterProc write FConfigureFormatterProc;
  end;

function OnSaveInstaller: TFormatOnSaveInstallerNotifier;

implementation

uses
  System.SysUtils,
  Pasfmt.Log,
  Pasfmt.Settings;

var
  // TFormatOnSaveInstallerNotifier
  GOnSaveInstaller: INTAEditServicesNotifier;

function OnSaveInstaller: TFormatOnSaveInstallerNotifier;
begin
  if not Assigned(GOnSaveInstaller) then begin
    GOnSaveInstaller := TFormatOnSaveInstallerNotifier.Create;
  end;

  Result := TFormatOnSaveInstallerNotifier(GOnSaveInstaller);
end;

constructor TFormatOnSaveInstallerNotifier.Create;
begin
  FFormatOnSaveModules := TDictionary<IOTAModule, Integer>.Create;
end;

//______________________________________________________________________________________________________________________

destructor TFormatOnSaveInstallerNotifier.Destroy;
begin
  UninstallAll;
  FreeAndNil(FFormatOnSaveModules);
  inherited;
end;

//______________________________________________________________________________________________________________________

procedure TFormatOnSaveInstallerNotifier.OnFormatOnSaveNotifierDestroyed(Sender: TObject);
var
  Notifier: TFormatOnSaveModuleNotifier;
begin
  Notifier := Sender as TFormatOnSaveModuleNotifier;
  FFormatOnSaveModules.Remove(Notifier.Module);
  Log.Debug('Deregistered format-on-save for module "%s"', [Notifier.Module.FileName]);
end;

//______________________________________________________________________________________________________________________

procedure TFormatOnSaveInstallerNotifier.UninstallAll;
var
  Pair: TPair<IOTAModule, Integer>;
  Count: Integer;
begin
  for Pair in FFormatOnSaveModules do
    Pair.Key.RemoveNotifier(Pair.Value);

  Count := FFormatOnSaveModules.Count;
  FFormatOnSaveModules.Clear;

  Log.Debug('Deregistered all %d format-on-saves', [Count]);
end;

//______________________________________________________________________________________________________________________

procedure TFormatOnSaveInstallerNotifier.DockFormRefresh(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.DockFormUpdated(const EditWindow: INTAEditWindow; DockForm: TDockableForm);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.DockFormVisibleChanged(
    const EditWindow: INTAEditWindow;
    DockForm: TDockableForm
);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.EditorViewActivated(
    const EditWindow: INTAEditWindow;
    const EditView: IOTAEditView
);
var
  Notifier: TFormatOnSaveModuleNotifier;
  Module: IOTAModule;
  Index: Integer;
begin
  Module := EditView.Buffer.Module;
  if PasfmtSettings.FormatOnSave and not FFormatOnSaveModules.ContainsKey(Module) then begin
    Notifier := TFormatOnSaveModuleNotifier.Create(Module);
    Notifier.OnDestroyed := OnFormatOnSaveNotifierDestroyed;
    Notifier.ConfigureFormatter := ConfigureFormatter;
    Index := Module.AddNotifier(Notifier);
    FFormatOnSaveModules.Add(Module, Index);
    Log.Debug('Registered format-on-save for module "%s"', [Module.FileName]);
  end;
end;

procedure TFormatOnSaveInstallerNotifier.EditorViewModified(
    const EditWindow: INTAEditWindow;
    const EditView: IOTAEditView
);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.WindowActivated(const EditWindow: INTAEditWindow);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.WindowCommand(
    const EditWindow: INTAEditWindow;
    Command, Param: Integer;
    var Handled: Boolean
);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.WindowNotification(const EditWindow: INTAEditWindow; Operation: TOperation);
begin
  // implement interface
end;

procedure TFormatOnSaveInstallerNotifier.WindowShow(const EditWindow: INTAEditWindow; Show, LoadedFromDesktop: Boolean);
begin
  // implement interface
end;

//______________________________________________________________________________________________________________________

constructor TFormatOnSaveModuleNotifier.Create(Module: IOTAModule);
begin
  FModule := Module;
end;

procedure TFormatOnSaveModuleNotifier.AfterSave;
begin
  inherited;
end;

procedure TFormatOnSaveModuleNotifier.BeforeSave;
var
  Formatter: TEditBufferFormatter;
  Buffer: IOTAEditBuffer;
begin
  inherited;
  if Supports(Module.CurrentEditor, IOTAEditBuffer, Buffer) then begin
    Log.Debug('Format-on-save triggered for "%s"', [Module.FileName]);
    Formatter := Default(TEditBufferFormatter);
    if Assigned(FConfigureFormatterProc) then begin
      FConfigureFormatterProc(Formatter);
    end;
    Formatter.Format(Buffer);
  end;
end;

function TFormatOnSaveModuleNotifier.CheckOverwrite: Boolean;
begin
  // implement interface
  Result := True;
end;

procedure TFormatOnSaveModuleNotifier.Destroyed;
begin
  inherited;
  if Assigned(FOnDestroyed) then begin
    FOnDestroyed(Self);
  end;
end;

procedure TFormatOnSaveModuleNotifier.Modified;
begin
  inherited;
  // implement interface
  // todo format on type
end;

procedure TFormatOnSaveModuleNotifier.ModuleRenamed(const NewName: string);
begin
  // implement interface
end;

//______________________________________________________________________________________________________________________

end.
