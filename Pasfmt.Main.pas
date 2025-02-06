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
    Vcl.Dialogs;

type
  TPlugin = class(TObject)
  private
    FPasfmtMenu: TMenuItem;
    FKeyboardBindingIndex: Integer;

    procedure FormatKeyBinding(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
    procedure FormatEvent(Sender: TObject);
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
var
  FormatAction: TAction;
  FormatItem: TMenuItem;
begin
  FPasfmtMenu := TMenuItem.Create((BorlandIDEServices as INTAServices).MainMenu);
  FPasfmtMenu.Caption := 'Pasf&mt';

  FormatAction := TAction.Create(FPasfmtMenu);
  FormatAction.Caption := '&Format';
  FormatAction.Category := 'Pasfmt';
  FormatAction.OnExecute := FormatEvent;

  FormatItem := TMenuItem.Create(FPasfmtMenu);
  FormatItem.Name := 'PasfmtFormatItem';
  FormatItem.Action := FormatAction;
  FPasfmtMenu.Add(FormatItem);

  (BorlandIDEServices as INTAServices).AddActionMenu('', FormatAction, nil);
  (BorlandIDEServices as INTAServices).AddActionMenu('ToolsMenu', nil, FPasfmtMenu);
  FKeyboardBindingIndex :=
      (BorlandIDEServices as IOTAKeyboardServices).AddKeyboardBinding(TPasfmtKeyboardBinding.Create);
end;

//______________________________________________________________________________________________________________________

destructor TPlugin.Destroy;
begin
  (BorlandIDEServices as IOTAKeyboardServices).RemoveKeyboardBinding(FKeyboardBindingIndex);
  FreeAndNil(FPasfmtMenu);
  inherited;

end;

//______________________________________________________________________________________________________________________

procedure TPlugin.Format;
var
  Formatter: TEditViewFormatter;
begin
  Formatter := Default(TEditViewFormatter);
  Formatter.Format((BorlandIDEServices as IOTAEditorServices).TopView.Buffer);
end;

procedure TPlugin.FormatEvent(Sender: TObject);
begin
  Format;
end;

procedure TPlugin
    .FormatKeyBinding(const Context: IOTAKeyContext; KeyCode: TShortcut; var BindingResult: TKeyBindingResult);
begin
  Format;
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
