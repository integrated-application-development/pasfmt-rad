unit Pasfmt.SettingsFrame;

interface

uses System.Classes, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, ToolsAPI, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TPasfmtSettingsFrame = class(TFrame)
    LogLevelCombo: TComboBox;
    LogLevelLabel: TLabel;
    ExeChooseDialog: TOpenDialog;
    ExePathBrowseButton: TButton;
    ExePathRadioGroup: TRadioGroup;
    ExePathEdit: TEdit;
    ExePathLabel: TLabel;
    OnSaveCheckBox: TCheckBox;
    UserSettingsLabel: TLabel;
    TimeoutLabel: TLabel;
    TimeoutEdit: TEdit;
    FastModeThresholdEdit: TEdit;
    FastModeThresholdLabel: TLabel;
    procedure ExePathBrowseButtonClick(Sender: TObject);
    procedure ExePathRadioGroupClick(Sender: TObject);
  public
    procedure UpdateExePathControls(ExePath: string);
    procedure SyncExePathControls;
  end;

  TPasfmtAddInOptions = class(TInterfacedObject, INTAAddInOptions)
  private
    FFrame: TPasfmtSettingsFrame;
  public
    function GetArea: string;
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    procedure DialogClosed(Accepted: Boolean);
    function ValidateContents: Boolean;
    function GetHelpContext: Integer;
    function IncludeInIDEInsight: Boolean;
  end;

implementation

uses System.IOUtils, Pasfmt.Settings, Pasfmt.Log, System.StrUtils, Pasfmt.OnSave, System.SysUtils;

{$R *.dfm}

//______________________________________________________________________________________________________________________

procedure TPasfmtAddInOptions.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := TPasfmtSettingsFrame(AFrame);

  PasfmtSettings.Load;
  FFrame.LogLevelCombo.ItemIndex := Ord(PasfmtSettings.LogLevel);
  FFrame.UpdateExePathControls(PasfmtSettings.ExecutablePath);
  FFrame.OnSaveCheckBox.Checked := PasfmtSettings.FormatOnSave;
  FFrame.TimeoutEdit.Text := IntToStr(PasfmtSettings.FormatTimeout);
  FFrame.FastModeThresholdEdit.Text := IntToStr(PasfmtSettings.MaxFileKiBWithUndoHistory);
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtAddInOptions.DialogClosed(Accepted: Boolean);
var
  LogLevelOrd: Integer;
  NewTimeout: Integer;
  NewThreshold: Integer;
begin
  if Accepted then begin
    PasfmtSettings.ExecutablePath := IfThen(FFrame.ExePathRadioGroup.ItemIndex = 1, Trim(FFrame.ExePathEdit.Text), '');

    if TryStrToInt(FFrame.TimeoutEdit.Text, NewTimeout) then begin
      PasfmtSettings.FormatTimeout := NewTimeout;
    end;

    LogLevelOrd := FFrame.LogLevelCombo.ItemIndex;
    if (LogLevelOrd < 0) or (LogLevelOrd > Ord(High(TLogLevel))) then begin
      LogLevelOrd := Ord(llDebug);
    end;

    PasfmtSettings.LogLevel := TLogLevel(LogLevelOrd);
    Log.SetLogLevel(PasfmtSettings.LogLevel);
    PasfmtSettings.FormatOnSave := FFrame.OnSaveCheckBox.Checked;

    if not PasfmtSettings.FormatOnSave then begin
      OnSaveInstaller.UninstallAll;
    end;

    if TryStrToInt(FFrame.FastModeThresholdEdit.Text, NewThreshold) then begin
      PasfmtSettings.MaxFileKiBWithUndoHistory := NewThreshold;
    end;
  end;

  FFrame := nil;
end;

//______________________________________________________________________________________________________________________

function TPasfmtAddInOptions.GetArea: string;
begin
  Result := '';
end;

function TPasfmtAddInOptions.GetCaption: string;
begin
  Result := 'Pasfmt';
end;

function TPasfmtAddInOptions.GetFrameClass: TCustomFrameClass;
begin
  Result := TPasfmtSettingsFrame;
end;

function TPasfmtAddInOptions.GetHelpContext: Integer;
begin
  Result := -1;
end;

function TPasfmtAddInOptions.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

function TPasfmtAddInOptions.ValidateContents: Boolean;
begin
  Result := True;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettingsFrame.ExePathBrowseButtonClick(Sender: TObject);
begin
  if TPath.HasValidPathChars(ExePathEdit.Text, False) and (ExePathEdit.Text <> '') then begin
    ExeChooseDialog.FileName := TPath.GetFileName(ExePathEdit.Text);
    ExeChooseDialog.InitialDir := TPath.GetDirectoryName(ExePathEdit.Text);
  end;

  if ExeChooseDialog.Execute then begin
    ExePathEdit.Text := ExeChooseDialog.FileName;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettingsFrame.ExePathRadioGroupClick(Sender: TObject);
begin
  SyncExePathControls;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettingsFrame.SyncExePathControls;
begin
  ExePathEdit.Visible := ExePathRadioGroup.ItemIndex = 1;
  ExePathBrowseButton.Visible := ExePathEdit.Visible;
end;

//______________________________________________________________________________________________________________________

procedure TPasfmtSettingsFrame.UpdateExePathControls(ExePath: string);
begin
  ExePathRadioGroup.ItemIndex := Integer(ExePath <> '');
  ExePathEdit.Text := ExePath;
  SyncExePathControls;
end;

//______________________________________________________________________________________________________________________

end.
