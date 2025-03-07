unit Pasfmt.Main;

interface

procedure Register;

implementation

uses
  System.Classes,
  ToolsAPI,
  System.SysUtils,
  Vcl.Menus,
  Vcl.ActnList,
  Pasfmt.FormatEditor,
  Pasfmt.SettingsFrame,
  Pasfmt.Settings,
  Winapi.Windows,
  Vcl.Graphics,
  System.JSON,
  Pasfmt.Log,
  Pasfmt.OnSave,
  System.Generics.Collections,
  System.IOUtils;

type
  TPlugin = class(TObject)
  private
    FPasfmtMenu: TMenuItem;
    FKeyboardBindingIndex: Integer;
    FInfoIndex: Integer;
    FEditorIndex: Integer;
    FAddInOptions: TPasfmtAddInOptions;
    FBitmaps: TObjectList<TBitmap>;

    function GetPluginVersion: string;

    procedure OnFormatKeyPress(const Context: IOTAKeyContext; KeyCode: TShortCut; var BindingResult: TKeyBindingResult);
    procedure OnFormatActionExecute(Sender: TObject);
    procedure OnSettingsActionExecute(Sender: TObject);
    procedure Format;

    procedure ConfigureFormatter(var Formatter: TEditBufferFormatter);
  public
    constructor Create;
    destructor Destroy; override;
  end;

  TPasfmtKeyboardBinding = class(TNotifierObject, IOTAKeyboardBinding)
  public
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure BindKeyboard(const BindingServices: IOTAKeyBindingServices);
  end;

var
  GPlugin: TPlugin;

procedure Register;
begin
  GPlugin := TPlugin.Create;
end;

//______________________________________________________________________________________________________________________

constructor TPlugin.Create;

  function CreateAction(Name: string; Caption: string; OnExecute: TNotifyEvent): TAction;
  begin
    Result := TAction.Create(FPasfmtMenu);
    Result.Name := Name;
    Result.Caption := Caption;
    Result.Category := 'Pasfmt';
    Result.OnExecute := OnExecute;
    (BorlandIDEServices as INTAServices).AddActionMenu('', Result, nil);
  end;

  function LoadBitmap(ResourceName: string): HBITMAP;
  var
    Stream: TResourceStream;
    Bitmap: TBitmap;
  begin
    // VCL LoadBitmap does not support 256-color bitmaps
    Stream := TResourceStream.Create(HInstance, ResourceName, RT_RCDATA);
    try
      Bitmap := TBitmap.Create;
      FBitmaps.Add(Bitmap);
      Bitmap.LoadFromStream(Stream);
      Result := Bitmap.Handle;
    finally
      FreeAndNil(Stream);
    end;
  end;

var
  MenuItem: TMenuItem;
  PluginName: string;
begin
  FBitmaps := TObjectList<TBitmap>.Create;

  FEditorIndex := (BorlandIDEServices as IOTAEditorServices).AddNotifier(OnSaveInstaller);
  OnSaveInstaller.ConfigureFormatter := ConfigureFormatter;

  FPasfmtMenu := TMenuItem.Create((BorlandIDEServices as INTAServices).MainMenu);
  FPasfmtMenu.Caption := '&Pasfmt';

  MenuItem := TMenuItem.Create(FPasfmtMenu);
  MenuItem.Name := 'PasfmtFormatItem';
  MenuItem.Action := CreateAction('PasfmtRunFormat', '&Format', OnFormatActionExecute);
  FPasfmtMenu.Add(MenuItem);

  MenuItem := TMenuItem.Create(FPasfmtMenu);
  MenuItem.Name := 'PasfmtSettingsItem';
  MenuItem.Action := CreateAction('PasfmtOpenSettings', '&Settings...', OnSettingsActionExecute);
  FPasfmtMenu.Add(MenuItem);

  (BorlandIDEServices as INTAServices).AddActionMenu('CustomToolsItem', nil, FPasfmtMenu);
  FKeyboardBindingIndex :=
      (BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(TPasfmtKeyboardBinding.Create);
  FAddInOptions := TPasfmtAddInOptions.Create;
  (BorlandIDEServices as INTAEnvironmentOptionsServices).RegisterAddInOptions(FAddInOptions);

  PluginName := 'Pasfmt for RAD Studio v' + GetPluginVersion;

  FInfoIndex :=
      (BorlandIDEServices as IOTAAboutBoxServices)
          .AddPluginInfo(
              PluginName,
              'RAD Studio plugin for pasfmt, the free and open source Delphi code formatter.'
                  + #13#10#13#10'Copyright © 2025 Integrated Application Development',
              LoadBitmap('LOGO48'));

  SplashScreenServices.AddPluginBitmap(PluginName, LoadBitmap('LOGO24'));
end;

//______________________________________________________________________________________________________________________

destructor TPlugin.Destroy;
begin
  FinalizeLog;
  (BorlandIDEServices as IOTAEditorServices).RemoveNotifier(FEditorIndex);
  (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(FInfoIndex);
  (BorlandIDEServices as INTAEnvironmentOptionsServices).UnregisterAddInOptions(FAddInOptions);
  (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FKeyboardBindingIndex);
  FreeAndNil(FPasfmtMenu);
  FreeAndNil(FBitmaps);
  inherited;
end;

//______________________________________________________________________________________________________________________

procedure TPlugin.ConfigureFormatter(var Formatter: TEditBufferFormatter);
var
  Project: IOTAProject;
begin
  Formatter.Core.Executable := PasfmtSettings.ExecutablePath;
  Formatter.Core.Timeout := PasfmtSettings.FormatTimeout;
  Formatter.MaxFileKiBWithUndoHistory := PasfmtSettings.MaxFileKiBWithUndoHistory;

  Project := (BorlandIDEServices as IOTAModuleServices).GetActiveProject;
  if Assigned(Project) then begin
    // Ensures pasfmt is reading the config file if present
    Formatter.Core.WorkingDirectory := TPath.GetDirectoryName(Project.FileName);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPlugin.Format;
var
  TopView: IOTAEditView;
  Buffer: IOTAEditBuffer;
  Formatter: TEditBufferFormatter;
begin
  Formatter := Default(TEditBufferFormatter);
  ConfigureFormatter(Formatter);

  TopView := (BorlandIDEServices as IOTAEditorServices).TopView;
  if not Assigned(TopView) then begin
    Log.Debug('Format request ignored: there is no active view to format');
    Exit;
  end;

  Buffer := TopView.Buffer;
  if not Assigned(Buffer) then begin
    Log.Debug('Format request ignored: the active view has no buffer to format');
    Exit;
  end;

  Formatter.Format(Buffer);
end;

procedure TPlugin.OnFormatActionExecute(Sender: TObject);
begin
  Format;
end;

procedure TPlugin.OnSettingsActionExecute(Sender: TObject);
begin
  (BorlandIDEServices as IOTAServices).GetEnvironmentOptions.EditOptions('', 'Pasfmt');
end;

procedure TPlugin.OnFormatKeyPress(
    const Context: IOTAKeyContext;
    KeyCode: TShortCut;
    var BindingResult: TKeyBindingResult
);
begin
  BindingResult := krHandled;
  Format;
end;

//______________________________________________________________________________________________________________________

function TPlugin.GetPluginVersion: string;
var
  Stream: TResourceStream;
  Obj: TJSONValue;
begin
  try
    Stream := TResourceStream.Create(HInstance, 'VERSIONJSON', RT_RCDATA);
    Obj := nil;
    try
      Obj := TJSONValue.ParseJSONValue(Stream.Memory, 0, Stream.Size, [TJSONValue.TJSONParseOption.IsUTF8]);
      Result := Obj.GetValue<string>('version');
    finally
      FreeAndNil(Obj);
      FreeAndNil(Stream);
    end;
  except
    Result := 'ERR';
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtKeyboardBinding.BindKeyboard(const BindingServices: IOTAKeyBindingServices);
begin
  BindingServices
      .AddKeyBinding([ShortCut(Ord('F'), [ssCtrl, ssAlt])], GPlugin.OnFormatKeyPress, nil, 0, '', 'PasfmtFormatItem');
end;

function TPasfmtKeyboardBinding.GetBindingType: TBindingType;
begin
  Result := btPartial;
end;

function TPasfmtKeyboardBinding.GetDisplayName: string;
begin
  Result := 'Pasfmt Keyboard Bindings';
end;

function TPasfmtKeyboardBinding.GetName: string;
begin
  Result := 'PasfmtBindings';
end;

//______________________________________________________________________________________________________________________

initialization

finalization
  FreeAndNil(GPlugin);

end.
