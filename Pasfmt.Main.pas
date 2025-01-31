unit Pasfmt.Main;

interface

type
  TPlugin = class
    procedure Format(Sender: TObject);
  end;

procedure Register;

implementation

uses Pasfmt.Subprocess, System.Classes, ToolsAPI, Winapi.ActiveX, Vcl.AxCtrls, System.SysUtils, Vcl.Menus, Vcl.ActnList;

var
  GPlugin: TPlugin;
  GPasfmtMenu: TMenuItem;

procedure Register;
var
  FormatItem: TMenuItem;
  FormatAction: TAction;
begin
  GPlugin := TPlugin.Create;

  GPasfmtMenu := TMenuItem.Create((BorlandIDEServices as INTAServices).MainMenu);
  GPasfmtMenu.Caption := 'Pasf&mt';

  FormatAction := TAction.Create(GPasfmtMenu);
  FormatAction.Caption := '&Format';
  FormatAction.Category := 'pasfmt';
  FormatAction.OnExecute := GPlugin.Format;

  FormatItem := TMenuItem.Create(GPasfmtMenu);
  FormatItem.Action := FormatAction;
  GPasfmtMenu.Add(FormatItem);
  (BorlandIDEServices as INTAServices).AddActionMenu('', FormatAction, nil);

  (BorlandIDEServices as INTAServices).AddActionMenu('ToolsMenu', nil, GPasfmtMenu);
end;

function StreamToUTF8(Stream: IStream): UTF8String;
var
  OleStream: TOleStream;
begin
  OleStream := TOleStream.Create(Stream);
  try
    SetLength(Result, OleStream.Size);
    OleStream.Seek(0, soBeginning);
    if OleStream.Read(Result[1], Length(Result)) <> OleStream.Size then
      raise Exception.Create('The stream could not be read');
  finally
    OleStream.Free;
  end;
end;

procedure FormatView(EditView: IOTAEditView);

  function ParseCursorOffset(const Data: UTF8String): Integer;
  const
    CTag: UTF8String = 'CURSOR=';
  var
    TagPos: Integer;
    NumPos: Integer;
    NumLength: Integer;
  begin
    TagPos := System.Pos(CTag, Data);
    if TagPos > 0 then begin
      NumLength := 0;
      NumPos := TagPos + Length(CTag);
      while (NumPos + NumLength <= Length(Data)) and (Data[NumPos + NumLength] in [#$30..#$39]) do
        Inc(NumLength);

      if not TryStrToInt(string(System.Copy(Data, NumPos, NumLength)), Result) then
        Result := -1;
    end;
  end;

  procedure TrimTrailingNewlines(Data: PAnsiChar; Length: Integer);
  var
    StrEnd: PAnsiChar;
  begin
    StrEnd := Data + Length;
    while (StrEnd > Data) and ((StrEnd - 1)^ in [#$0A, #$0D]) do
      Dec(StrEnd);
    StrEnd^ := #0;
  end;

var
  SourceEditor: IOTAEditorContent;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
  BytePos: Integer;

  CommandLine: string;
  StdIn: UTF8String;
  StdOut: UTF8String;
  StdErr: UTF8String;
  ExitCode: Cardinal;

  NewCursorOffset: Integer;
  Writer: IOTAEditWriter;
begin
  if EditView.Buffer.QueryInterface(IOTAEditorContent, SourceEditor) = S_OK then begin
    StdIn := StreamToUTF8(SourceEditor.Content);
  end
  else begin
    raise Exception.Create('Editor doesn''t support IOTAEditorContent');
  end;

  EditPos := EditView.CursorPos;
  EditView.ConvertPos(True, EditPos, CharPos);
  BytePos := EditView.CharPosToPos(CharPos);

  CommandLine := 'pasfmt.exe -C encoding=utf-8 --cursor=' + IntToStr(BytePos);
  ExitCode := RunProcess(CommandLine, StdIn, StdOut, StdErr, 1);

  Assert(ExitCode = 0);

  Writer := EditView.Buffer.CreateUndoableWriter;
  Writer.DeleteTo(MaxInt);
  // the IDE always inserts a line ending after whatever we insert, so we have to trim the trailing line ending
  // that pasfmt creates.
  TrimTrailingNewlines(PAnsiChar(StdOut), Length(StdOut));
  // While it would possible to insert with this Writer incrementally as stdout is consumed from the subprocess
  // (avoiding collecting the entire output into a string), using this method from a thread other than the main thread
  // either hangs or breaks things. I think this is the fault of the VCL components.
  // Also, if you call this method more than once than the scroll position of the editor is ruined.
  Writer.Insert(PAnsiChar(StdOut));

  NewCursorOffset := ParseCursorOffset(StdErr);
  if NewCursorOffset > 0 then begin
    CharPos := EditView.PosToCharPos(NewCursorOffset);
    EditView.ConvertPos(False, EditPos, CharPos);
    EditView.CursorPos := EditPos;
  end;

  EditView.Paint;
end;

procedure TPlugin.Format(Sender: TObject);
begin
  FormatView((BorlandIDEServices as IOTAEditorServices).TopView);
end;

initialization

finalization
  FreeAndNil(GPlugin);
  FreeAndNil(GPasfmtMenu);

end.
