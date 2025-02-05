unit Pasfmt.FormatEditor;

interface

uses ToolsAPI, Pasfmt.FormatCore;

type
  TEditViewFormatter = record
    Formatter: TFormatter;

    procedure Format(Buffer: IOTAEditBuffer);
  end;

implementation

uses
    System.SysUtils,
    System.Classes,
    Winapi.Windows,
    Winapi.ActiveX,
    Vcl.AxCtrls,
    Pasfmt.Log,
    Vcl.Dialogs,
    System.StrUtils;

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
  StrEnd := Data + Length;
  while (StrEnd > Data) and ((StrEnd - 1)^ in [#$0A, #$0D]) do
    Dec(StrEnd);
  StrEnd^ := #0;
end;

//______________________________________________________________________________________________________________________

function GetBufferViewCursors(Buffer: IOTAEditBuffer): TArray<Integer>;
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
begin
  SetLength(Result, Buffer.EditViewCount);
  for I := 0 to Buffer.EditViewCount - 1 do begin
    EditView := Buffer.EditViews[I];

    EditPos := EditView.CursorPos;
    EditView.ConvertPos(True, EditPos, CharPos);
    Result[I] := EditView.CharPosToPos(CharPos);
  end;
end;

//______________________________________________________________________________________________________________________

procedure SetBufferViewCursors(Buffer: IOTAEditBuffer; Cursors: TArray<Integer>);
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
begin
  for I := 0 to Buffer.EditViewCount - 1 do begin
    if (I >= Length(Cursors)) or (Cursors[I] < 0) then begin
      Continue;
    end;

    EditView := Buffer.EditViews[I];

    CharPos := EditView.PosToCharPos(Cursors[I]);
    EditView.ConvertPos(False, EditPos, CharPos);
    EditView.CursorPos := EditPos;
    EditView.Paint;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TEditViewFormatter.Format(Buffer: IOTAEditBuffer);
var
  SourceEditor: IOTAEditorContent;
  EditorContent: UTF8String;
  FormatResult: TFormatResult;
  Writer: IOTAEditWriter;
begin
  if not Supports(Buffer, IOTAEditorContent, SourceEditor) then begin
    Log.Debug('Format request ignored: the editor is not formattable', [Buffer.FileName]);
    Exit;
  end
  else if Buffer.IsReadOnly then begin
    Log.Debug('Format request ignored: "%s" is read-only', [Buffer.FileName]);
    Exit;
  end;

  EditorContent := StreamToUTF8(SourceEditor.Content);
  FormatResult := Formatter.Format(EditorContent, GetBufferViewCursors(Buffer));

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
    Exit;
  end;
  if FormatResult.Output = EditorContent then begin
    Log.Debug('"%s" is already formatted, skipping buffer update', [Buffer.FileName]);
    Exit;
  end;

  Writer := Buffer.CreateUndoableWriter;
  Writer.DeleteTo(MaxInt);
  // the IDE always inserts a line ending after whatever we insert, so we have to trim the trailing line ending
  // that pasfmt creates.
  TrimTrailingNewlines(PAnsiChar(FormatResult.Output), Length(FormatResult.Output));
  // While it would possible to insert with this Writer incrementally as stdout is consumed from the subprocess
  // (avoiding collecting the entire output into a string), using this method from a thread other than the main thread
  // either hangs or breaks things. I think this is the fault of the VCL components.
  // Also, if you call this method more than once than the scroll position of the editor is ruined.
  Writer.Insert(PAnsiChar(FormatResult.Output));

  SetBufferViewCursors(Buffer, FormatResult.Cursors);

  Log.Debug('Formatted "%s", %d cursors updated', [Buffer.FileName, Length(FormatResult.Cursors)]);
end;

//______________________________________________________________________________________________________________________

end.
