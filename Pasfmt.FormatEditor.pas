unit Pasfmt.FormatEditor;

interface

uses ToolsAPI, Pasfmt.FormatCore;

type
  TEditBufferFormatter = record
    Core: TFormatter;
    MaxFileKiBWithUndoHistory: Integer;

    procedure Format(Buffer: IOTAEditBuffer);
  end;

implementation

uses System.SysUtils, System.Classes, Winapi.ActiveX, Vcl.AxCtrls, Pasfmt.Log, System.StrUtils;

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

type
  TCursors = record
    Offsets: TArray<Integer>;
    RowsFromTop: TArray<Integer>;
  end;

function GetBufferViewCursors(Buffer: IOTAEditBuffer): TCursors;
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
begin
  SetLength(Result.Offsets, Buffer.EditViewCount);
  SetLength(Result.RowsFromTop, Buffer.EditViewCount);
  for I := 0 to Buffer.EditViewCount - 1 do begin
    EditView := Buffer.EditViews[I];

    EditPos := EditView.CursorPos;
    EditView.ConvertPos(True, EditPos, CharPos);
    Result.Offsets[I] := EditView.CharPosToPos(CharPos);
    Result.RowsFromTop[I] := EditView.Position.Row - EditView.TopRow;
  end;
end;

//______________________________________________________________________________________________________________________

procedure SetBufferViewCursors(Buffer: IOTAEditBuffer; Cursors: TCursors);
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
begin
  for I := 0 to Buffer.EditViewCount - 1 do begin
    if (I >= Length(Cursors.Offsets)) or (Cursors.Offsets[I] < 0) then begin
      Continue;
    end;

    EditView := Buffer.EditViews[I];

    CharPos := EditView.PosToCharPos(Cursors.Offsets[I]);
    EditView.ConvertPos(False, EditPos, CharPos);
    EditView.CursorPos := EditPos;
    EditView.Scroll((EditView.Position.Row - EditView.TopRow) - Cursors.RowsFromTop[I], 0);
    EditView.Paint;
  end;
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

procedure TEditBufferFormatter.Format(Buffer: IOTAEditBuffer);
const
  CSuccessMsg = 'Formatted ✓';
  CErrMsg = 'Format error';
var
  SourceEditor: IOTAEditorContent;
  EditorContent: UTF8String;
  FormatResult: TFormatResult;
  Writer: IOTAEditWriter;
  Cursors: TCursors;
  FileSizeKiB: Integer;
begin
  if not Supports(Buffer, IOTAEditorContent, SourceEditor) then begin
    Log.Debug('Format request ignored: the editor is not formattable', [Buffer.FileName]);
    Exit;
  end
  else if Buffer.IsReadOnly then begin
    Log.Debug('Format request ignored: "%s" is read-only', [Buffer.FileName]);
    Exit;
  end;

  SetBufferViewMessages(Buffer, 'Formatting...');

  EditorContent := StreamToUTF8(SourceEditor.Content);
  Cursors := GetBufferViewCursors(Buffer);

  try
    FormatResult := Core.Format(EditorContent, Cursors.Offsets);
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

  Cursors.Offsets := FormatResult.Cursors;
  SetBufferViewCursors(Buffer, Cursors);

  Log.Debug('Formatted "%s", %d cursors updated', [Buffer.FileName, Length(FormatResult.Cursors)]);
  SetBufferViewMessages(Buffer, CSuccessMsg);
end;

//______________________________________________________________________________________________________________________

end.
