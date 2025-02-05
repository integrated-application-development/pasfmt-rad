unit Pasfmt.Main;

interface

procedure Register;

implementation

uses
    Pasfmt.Subprocess,
    System.Classes,
    ToolsAPI,
    Winapi.ActiveX,
    Vcl.AxCtrls,
    System.SysUtils,
    Vcl.Menus,
    Vcl.ActnList,
    Pasfmt.FormatEditor,
    Pasfmt.SettingsFrame,
    Pasfmt.Settings,
    Winapi.Windows,
    System.JSON,
    Pasfmt.Log,
    Pasfmt.OnSave,
    Vcl.Dialogs;

type
  TPlugin = class(TObject)
  private
    FPasfmtMenu: TMenuItem;
    FKeyboardBindingIndex: Integer;
    FInfoIndex: Integer;
    FEditorIndex: Integer;
    FAddInOptions: TPasfmtAddInOptions;

    function GetPluginVersion: string;

    procedure FormatKeyBinding(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure OnFormatActionExecute(Sender: TObject);
    procedure OnSettingsActionExecute(Sender: TObject);
    procedure Format;
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

  //______________________________________________________________________________________________________________________

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

var
  MenuItem: TMenuItem;
  PluginName: string;
begin
  FEditorIndex := (BorlandIDEServices as IOTAEditorServices).AddNotifier(OnSaveInstaller);

  FPasfmtMenu := TMenuItem.Create((BorlandIDEServices as INTAServices).MainMenu);
  FPasfmtMenu.Caption := 'Pasf&mt';

  MenuItem := TMenuItem.Create(FPasfmtMenu);
  MenuItem.Name := 'PasfmtFormatItem';
  MenuItem.Action := CreateAction('PasfmtRunFormat', '&Format', OnFormatActionExecute);
  FPasfmtMenu.Add(MenuItem);

  MenuItem := TMenuItem.Create(FPasfmtMenu);
  MenuItem.Name := 'PasfmtSettingsItem';
  MenuItem.Action := CreateAction('PasfmtOpenSettings', '&Settings...', OnSettingsActionExecute);
  FPasfmtMenu.Add(MenuItem);

  (BorlandIDEServices as INTAServices).AddActionMenu('ToolsMenu', nil, FPasfmtMenu);
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
              nil,
              False,
              '');

  SplashScreenServices.AddPluginBitmap(PluginName, [], False);
end;

//______________________________________________________________________________________________________________________

destructor TPlugin.Destroy;
begin
  (BorlandIDEServices as IOTAEditorServices).RemoveNotifier(FEditorIndex);
  (BorlandIDEServices as IOTAAboutBoxServices).RemovePluginInfo(FInfoIndex);
  (BorlandIDEServices as INTAEnvironmentOptionsServices).UnregisterAddInOptions(FAddInOptions);
  (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FKeyboardBindingIndex);
  FreeAndNil(FPasfmtMenu);
  inherited;
end;

//______________________________________________________________________________________________________________________

procedure TPlugin.Format;
var
  TopView: IOTAEditView;
  Buffer: IOTAEditBuffer;
  Formatter: TEditViewFormatter;
begin
  Formatter := Default(TEditViewFormatter);
  Formatter.Formatter.Executable := PasfmtSettings.ExecutablePath;

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

procedure TPlugin.FormatKeyBinding( //
    const Context: IOTAKeyContext;
    KeyCode: TShortcut;
    var BindingResult: TKeyBindingResult
);
begin
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
      .AddKeyBinding([ShortCut(Ord('F'), [ssCtrl, ssAlt])], GPlugin.FormatKeyBinding, nil, 0, '', 'PasfmtFormatItem');
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
