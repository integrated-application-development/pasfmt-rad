unit Pasfmt.Cursors;

interface

uses
  ToolsAPI,
  System.Generics.Collections;

type
  TBreakpointData = record
  private
    // IOTABreakpoint40
    FEnabled: Boolean;
    FExpression: string;
    FFileName: string;
    FLineNumber: Integer;
    FPassCount: Integer;

    // IOTABreakpoint50
    FGroupName: string;
    FDoBreak: Boolean;
    FLogMessage: string;
    FEvalExpression: string;
    FLogResult: Boolean;
    FEnableGroup: string;
    FDisableGroup: string;

    // IOTABreakpoint80
    FDoHandleExceptions: Boolean;
    FDoIgnoreExceptions: Boolean;

    // IOTABreakpoint120
    FStackFramesToLog: Integer;

    // IOTABreakpoint
    FThreadCondition: string;

    class function From(SourceBreakpoint: IOTASourceBreakpoint): TBreakpointData; static;
    procedure CopyTo(SourceBreakpoint: IOTABreakpoint);
  end;

  TCursors = class
  private
    FOffsets: TArray<Integer>;
    FRowsFromTop: TArray<Integer>;

    FBookmarkOffsets: TList<Integer>;
    FBookmarkIds: TList<Integer>;

    FBreakpointOffsets: TList<Integer>;
    FBreakpointData: TList<TBreakpointData>;

    procedure UpdateBookmarks(Buffer: IOTAEditBuffer);
    procedure UpdateBreakpoints(Buffer: IOTAEditBuffer);
    procedure UpdateCursors(Buffer: IOTAEditBuffer);

  public
    constructor Create(Buffer: IOTAEditBuffer);
    destructor Destroy; override;

    function Serialize: TArray<Integer>;
    procedure Deserialize(Offsets: TArray<Integer>);

    procedure UpdateBuffer(Buffer: IOTAEditBuffer);
  end;

implementation

uses
  Pasfmt.Log,
  System.SysUtils;

const
  // While the user interface only lets you create bookmarks 0 to 9, the ToolsAPI also lets plugins create and use
  // bookmarks 10 to 19. I don't know if this is documented anywhere.
  CMaxBookmark = 19;

//______________________________________________________________________________________________________________________

class function TBreakpointData.From(SourceBreakpoint: IOTASourceBreakpoint): TBreakpointData;
begin
  Result := Default(TBreakpointData);

  // IOTABreakpoint40
  Result.FEnabled := SourceBreakpoint.Enabled;
  Result.FExpression := SourceBreakpoint.Expression;
  Result.FFileName := SourceBreakpoint.FileName;
  Result.FLineNumber := SourceBreakpoint.LineNumber;
  Result.FPassCount := SourceBreakpoint.PassCount;

  // IOTABreakpoint50
  Result.FGroupName := SourceBreakpoint.GroupName;
  Result.FDoBreak := SourceBreakpoint.DoBreak;
  Result.FLogMessage := SourceBreakpoint.LogMessage;
  Result.FEvalExpression := SourceBreakpoint.EvalExpression;
  Result.FLogResult := SourceBreakpoint.LogResult;
  Result.FEnableGroup := SourceBreakpoint.EnableGroup;
  Result.FDisableGroup := SourceBreakpoint.DisableGroup;

  // IOTABreakpoint80
  Result.FDoHandleExceptions := SourceBreakpoint.DoHandleExceptions;
  Result.FDoIgnoreExceptions := SourceBreakpoint.DoIgnoreExceptions;

  // IOTABreakpoint120
  Result.FStackFramesToLog := SourceBreakpoint.StackFramesToLog;

  // IOTABreakpoint
  Result.FThreadCondition := SourceBreakpoint.ThreadCondition;
end;

//______________________________________________________________________________________________________________________

procedure TBreakpointData.CopyTo(SourceBreakpoint: IOTABreakpoint);
begin
  // IOTABreakpoint40
  SourceBreakpoint.Enabled := Self.FEnabled;
  SourceBreakpoint.Expression := Self.FExpression;
  SourceBreakpoint.FileName := Self.FFileName;
  SourceBreakpoint.LineNumber := Self.FLineNumber;
  SourceBreakpoint.PassCount := Self.FPassCount;

  // IOTABreakpoint50
  SourceBreakpoint.GroupName := Self.FGroupName;
  SourceBreakpoint.DoBreak := Self.FDoBreak;
  SourceBreakpoint.LogMessage := Self.FLogMessage;
  SourceBreakpoint.EvalExpression := Self.FEvalExpression;
  SourceBreakpoint.LogResult := Self.FLogResult;
  SourceBreakpoint.EnableGroup := Self.FEnableGroup;
  SourceBreakpoint.DisableGroup := Self.FDisableGroup;

  // IOTABreakpoint80
  SourceBreakpoint.DoHandleExceptions := Self.FDoHandleExceptions;
  SourceBreakpoint.DoIgnoreExceptions := Self.FDoIgnoreExceptions;

  // IOTABreakpoint120
  SourceBreakpoint.StackFramesToLog := Self.FStackFramesToLog;

  // IOTABreakpoint
  SourceBreakpoint.ThreadCondition := Self.FThreadCondition;
end;

//______________________________________________________________________________________________________________________

destructor TCursors.Destroy;
begin
  FreeAndNil(FBookmarkOffsets);
  FreeAndNil(FBookmarkIds);
  FreeAndNil(FBreakpointOffsets);
  FreeAndNil(FBreakpointData);
  inherited;
end;

//______________________________________________________________________________________________________________________

constructor TCursors.Create(Buffer: IOTAEditBuffer);
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
  Bookmark: Integer;
  DebuggerServices: IOTADebuggerServices;
  Breakpoint: IOTASourceBreakpoint;
begin
  SetLength(FOffsets, Buffer.EditViewCount);
  SetLength(FRowsFromTop, Buffer.EditViewCount);

  FBookmarkOffsets := TList<Integer>.Create;
  FBookmarkIds := TList<Integer>.Create;
  FBreakpointOffsets := TList<Integer>.Create;
  FBreakpointData := TList<TBreakpointData>.Create;

  for I := 0 to Buffer.EditViewCount - 1 do begin
    EditView := Buffer.EditViews[I];

    EditPos := EditView.CursorPos;
    EditView.ConvertPos(True, EditPos, CharPos);
    FOffsets[I] := EditView.CharPosToPos(CharPos);
    FRowsFromTop[I] := EditView.Position.Row - EditView.TopRow;
  end;

  if Buffer.EditViewCount <= 0 then begin
    Log.Debug('Buffer has no edit views');
    Exit;
  end;

  // bookmarks are shared between all edit views of a buffer
  EditView := Buffer.EditViews[0];

  for Bookmark := 0 to CMaxBookmark do begin
    CharPos := EditView.BookmarkPos[Bookmark];
    if CharPos.Line <> 0 then begin
      FBookmarkOffsets.Add(EditView.CharPosToPos(CharPos));
      FBookmarkIds.Add(Bookmark);
    end;
  end;

  if Supports(BorlandIDEServices, IOTADebuggerServices, DebuggerServices) then begin
    for I := 0 to DebuggerServices.SourceBkptCount - 1 do begin
      Breakpoint := DebuggerServices.SourceBkpts[I];
      if not SameText(Breakpoint.FileName, Buffer.FileName) then
        Continue;

      CharPos.Line := Breakpoint.LineNumber;
      CharPos.CharIndex := 0;
      FBreakpointOffsets.Add(EditView.CharPosToPos(CharPos));
      FBreakpointData.Add(TBreakpointData.From(Breakpoint));
    end;
  end;
end;

//______________________________________________________________________________________________________________________

function TCursors.Serialize: TArray<Integer>;
var
  Copied: Integer;
  List: TList<Integer>;
begin
  SetLength(Result, Length(FOffsets) + FBookmarkOffsets.Count + FBreakpointOffsets.Count);

  Copied := 0;

  if Length(FOffsets) > 0 then
    Move(FOffsets[0], Result[Copied], Length(FOffsets) * SizeOf(Integer));
  Inc(Copied, Length(FOffsets));

  for List in [FBookmarkOffsets, FBreakpointOffsets] do begin
    if List.Count > 0 then
      Move(List.List[0], Result[Copied], List.Count * SizeOf(Integer));
    Inc(Copied, List.Count);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TCursors.Deserialize(Offsets: TArray<Integer>);
var
  ExpectedCount: Integer;
  Copied: Integer;
  List: TList<Integer>;
begin
  ExpectedCount := Length(FOffsets) + FBookmarkOffsets.Count + FBreakpointOffsets.Count;
  if Length(Offsets) <> ExpectedCount then begin
    Log.Error(
        'Expected %d cursors, found %d. Editor cursors, breakpoints, and bookmarks could not be updated',
        [ExpectedCount, Length(Offsets)]
    );
    Exit;
  end;

  Copied := 0;

  if Length(FOffsets) > 0 then
    Move(Offsets[Copied], FOffsets[0], Length(FOffsets) * SizeOf(Integer));
  Inc(Copied, Length(FOffsets));

  for List in [FBookmarkOffsets, FBreakpointOffsets] do begin
    if List.Count > 0 then
      Move(Offsets[Copied], List.List[0], List.Count * SizeOf(Integer));
    Inc(Copied, List.Count);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TCursors.UpdateBookmarks(Buffer: IOTAEditBuffer);
var
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;

  BookmarkIdx: Integer;
begin
  if Buffer.EditViewCount <= 0 then begin
    Log.Debug('Skipping updating bookmarks because the buffer has no edit views');
    Exit;
  end;

  // bookmarks are shared between all edit views of a buffer
  EditView := Buffer.EditViews[0];

  for BookmarkIdx := 0 to FBookmarkIds.Count - 1 do begin
    CharPos := EditView.PosToCharPos(FBookmarkOffsets[BookmarkIdx]);
    EditView.ConvertPos(False, EditPos, CharPos);
    EditView.CursorPos := EditPos;

    EditView.BookmarkToggle(FBookmarkIds[BookmarkIdx]);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TCursors.UpdateBreakpoints(Buffer: IOTAEditBuffer);
var
  I: Integer;
  CharPos: TOTACharPos;
  BreakpointData: ^TBreakpointData;
  Breakpoint: IOTABreakpoint;
  DebuggerServices: IOTADebuggerServices;
begin
  if Buffer.EditViewCount <= 0 then begin
    Log.Debug('Skipping updating breakpoints because the buffer has no edit views');
    Exit;
  end;

  if not Supports(BorlandIDEServices, IOTADebuggerServices, DebuggerServices) then begin
    Log.Debug('Skipping updating breakpoints because BorlandIDEServices does not implement IOTADebuggerServices');
    Exit;
  end;

  // The old breakpoints (sometimes) stick around after a rewrite of the editor, but their positions are wrong and
  // they become invisible until manually disabled and re-enabled, so it's better to just recreate them.
  for I := DebuggerServices.SourceBkptCount - 1 downto 0 do begin
    Breakpoint := DebuggerServices.SourceBkpts[I];
    if not SameText(Breakpoint.FileName, Buffer.FileName) then
      Continue;

    DebuggerServices.RemoveBreakpoint(Breakpoint);
  end;

  for I := 0 to FBreakpointData.Count - 1 do begin
    CharPos := Buffer.EditViews[0].PosToCharPos(FBreakpointOffsets[I]);
    BreakpointData := @FBreakpointData.List[I];
    BreakpointData^.FLineNumber := CharPos.Line;

    Breakpoint :=
        DebuggerServices.NewSourceBreakpoint(
            BreakpointData^.FFileName,
            BreakpointData^.FLineNumber,
            DebuggerServices.CurrentProcess
        );
    BreakpointData^.CopyTo(Breakpoint);
  end;
end;

//______________________________________________________________________________________________________________________

procedure TCursors.UpdateCursors(Buffer: IOTAEditBuffer);
var
  I: Integer;
  EditView: IOTAEditView;
  EditPos: TOTAEditPos;
  CharPos: TOTACharPos;
begin
  for I := 0 to Buffer.EditViewCount - 1 do begin
    if (I >= Length(FOffsets)) or (FOffsets[I] < 0) then begin
      Continue;
    end;

    EditView := Buffer.EditViews[I];

    CharPos := EditView.PosToCharPos(FOffsets[I]);
    EditView.ConvertPos(False, EditPos, CharPos);
    EditView.CursorPos := EditPos;
    EditView.Scroll((EditView.Position.Row - EditView.TopRow) - FRowsFromTop[I], 0);
    EditView.Paint;
  end;
end;

//______________________________________________________________________________________________________________________

procedure TCursors.UpdateBuffer(Buffer: IOTAEditBuffer);
begin
  UpdateBookmarks(Buffer);
  UpdateBreakpoints(Buffer);

  // Only update editor cursors after setting bookmarks and breakpoints, because setting the bookmarks involves moving
  // the cursor around, and we should only repaint the EditView after all changes are complete.
  UpdateCursors(Buffer);
end;

end.
