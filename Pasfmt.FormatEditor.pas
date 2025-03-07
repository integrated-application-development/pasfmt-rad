unit Pasfmt.FormatEditor;

interface

uses
  ToolsAPI,
  Pasfmt.FormatCore,
  Pasfmt.Cursors;

type
  TEditBufferFormatter = record
    Core: TFormatter;
    MaxFileKiBWithUndoHistory: Integer;

    procedure Format(Buffer: IOTAEditBuffer);
  private
    procedure FormatWithCursors(Buffer: IOTAEditBuffer; SourceEditor: IOTAEditorContent; Cursors: TCursors);
  end;

implementation

uses
  System.SysUtils,
  System.Classes,
  Winapi.ActiveX,
  Vcl.AxCtrls,
  Pasfmt.Log,
  System.StrUtils,
  Vcl.Dialogs,
  System.UITypes;

//______________________________________________________________________________________________________________________

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
    FreeAndNil(OleStream);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TrimTrailingNewlines(Data: PAnsiChar; Length: Integer);
var
  StrEnd: PAnsiChar;
begin
  if Data = nil then begin
    Exit;
  end;

  StrEnd := Data + Length;
  while (StrEnd > Data) and ((StrEnd - 1)^ in [#$0A, #$0D]) do
    Dec(StrEnd);
  StrEnd^ := #0;
end;

//______________________________________________________________________________________________________________________

procedure SetBufferViewMessages(Buffer: IOTAEditBuffer; Msg: string);
var
  I: Integer;
begin
  for I := 0 to Buffer.EditViewCount - 1 do begin
    Buffer.EditViews[I].SetTempMsg(Msg);
  end;
end;

//______________________________________________________________________________________________________________________

function ConfirmFormatWhileDebugging: Boolean;
begin
  Result :=
      MessageDlg('Formatting will disrupt debugging in this file. Continue?', mtWarning, [mbOK, mbCancel], 0, mbCancel)
          = mrOK;
end;

//______________________________________________________________________________________________________________________

procedure TEditBufferFormatter.Format(Buffer: IOTAEditBuffer);
var
  SourceEditor: IOTAEditorContent;
  DebuggerServices: IOTADebuggerServices;
  Cursors: TCursors;
begin
  if not Supports(Buffer, IOTAEditorContent, SourceEditor) then begin
    Log.Debug('Format request ignored: the editor is not formattable', [Buffer.FileName]);
    Exit;
  end
  else if Buffer.IsReadOnly then begin
    Log.Debug('Format request ignored: "%s" is read-only', [Buffer.FileName]);
    Exit;
  end
  else if Supports(BorlandIDEServices, IOTADebuggerServices, DebuggerServices)
      and Assigned(DebuggerServices.CurrentProcess)
      and not ConfirmFormatWhileDebugging then
  begin
    Log.Debug('Format request ignored: debugger is running and user has cancelled');
    Exit;
  end;

  SetBufferViewMessages(Buffer, 'Formatting...');

  Cursors := TCursors.Create(Buffer);
  try
    FormatWithCursors(Buffer, SourceEditor, Cursors);
  finally
    FreeAndNil(Cursors);
  end;
end;

procedure TEditBufferFormatter.FormatWithCursors(
    Buffer: IOTAEditBuffer;
    SourceEditor: IOTAEditorContent;
    Cursors: TCursors
);
const
  CSuccessMsg = 'Formatted ✓';
  CErrMsg = 'Format error';
var
  EditorContent: UTF8String;
  FormatResult: TFormatResult;
  Writer: IOTAEditWriter;
  FileSizeKiB: Integer;
begin
  EditorContent := StreamToUTF8(SourceEditor.Content);
  try
    FormatResult := Core.Format(EditorContent, Cursors.Serialize);
  except
    on E: Exception do begin
      Log.Error('Format invocation failed: %s', [E.Message]);
      SetBufferViewMessages(Buffer, CErrMsg);
      Exit;
    end;
  end;

  if FormatResult.ErrorInfo <> '' then begin
    if ContainsText(FormatResult.ErrorInfo, 'error') then begin
      Log.Error(FormatResult.ErrorInfo);
    end
    else begin
      Log.Warn(FormatResult.ErrorInfo);
    end;
  end;

  if FormatResult.ExitCode <> 0 then begin
    Log.Error('Format of "%s" failed', [Buffer.FileName]);
    SetBufferViewMessages(Buffer, CErrMsg);
    Exit;
  end;

  if FormatResult.Output = EditorContent then begin
    SetBufferViewMessages(Buffer, CSuccessMsg);
    Log.Debug('"%s" is already formatted, skipping buffer update', [Buffer.FileName]);
    Exit;
  end;

  SetBufferViewMessages(Buffer, 'Rendering...');

  // the IDE always inserts a line ending after whatever we insert, so we have to trim the trailing line ending
  // that pasfmt creates.
  TrimTrailingNewlines(PAnsiChar(FormatResult.Output), Length(FormatResult.Output));

  FileSizeKiB := Length(EditorContent) div 1024;
  if FileSizeKiB > MaxFileKiBWithUndoHistory then begin
    Log.Warn(
        'Losing undo history for "%s" (file size %d KiB is above threshold %d KiB)',
        [Buffer.FileName, FileSizeKiB, MaxFileKiBWithUndoHistory]
    );
    SourceEditor.Content := TStreamAdapter.Create(TStringStream.Create(FormatResult.Output), soOwned) as IStream;
  end
  else begin
    Writer := Buffer.CreateUndoableWriter;
    Writer.DeleteTo(MaxInt);
    Writer.Insert(PAnsiChar(FormatResult.Output));
  end;

  Cursors.Deserialize(FormatResult.Cursors);
  Cursors.UpdateBuffer(Buffer);

  Log.Debug('Formatted "%s", %d cursors updated', [Buffer.FileName, Length(FormatResult.Cursors)]);
  SetBufferViewMessages(Buffer, CSuccessMsg);
end;

//______________________________________________________________________________________________________________________

end.
