{
  Examples:
    ./testpassrc --suite=TTestResolver.TestEmpty
}
(*
  CheckReferenceDirectives:
    {#a} label "a", labels all elements at the following token
    {@a} reference "a", search at next token for an element e with
           TResolvedReference(e.CustomData).Declaration points to an element
           labeled "a".
    {=a} is "a", search at next token for a TPasAliasType t with t.DestType
           points to an element labeled "a"
*)
unit tcresolver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, strutils, fpcunit, testregistry,
  PasTree, PScanner, PParser, PasResolver,
  tcbaseparser;

type
  TSrcMarkerKind = (
    mkLabel,
    mkResolverReference,
    mkDirectReference
    );
  PSrcMarker = ^TSrcMarker;
  TSrcMarker = record
    Kind: TSrcMarkerKind;
    Filename: string;
    Row: integer;
    StartCol, EndCol: integer; // token start, end column
    Identifier: string;
    Next: PSrcMarker;
  end;

const
  SrcMarker: array[TSrcMarkerKind] of char = (
    '#', // mkLabel
    '@', // mkResolverReference
    '='  // mkDirectReference
    );
type
  TOnFindUnit = function(const aUnitName: String): TPasModule of object;

  { TTestEnginePasResolver }

  TTestEnginePasResolver = class(TPasResolver)
  private
    FFilename: string;
    FModule: TPasModule;
    FOnFindUnit: TOnFindUnit;
    FParser: TPasParser;
    FResolver: TStreamResolver;
    FScanner: TPascalScanner;
    FSource: string;
    procedure SetModule(AValue: TPasModule);
  public
    constructor Create;
    destructor Destroy; override;
    function FindModule(const AName: String): TPasModule; override;
    property OnFindUnit: TOnFindUnit read FOnFindUnit write FOnFindUnit;
    property Filename: string read FFilename write FFilename;
    property Resolver: TStreamResolver read FResolver write FResolver;
    property Scanner: TPascalScanner read FScanner write FScanner;
    property Parser: TPasParser read FParser write FParser;
    property Source: string read FSource write FSource;
    property Module: TPasModule read FModule write SetModule;
  end;

  TTestResolverReferenceData = record
    Filename: string;
    Row: integer;
    StartCol: integer;
    EndCol: integer;
    Found: TFPList; // list of TPasElement at this token
  end;
  PTestResolverReferenceData = ^TTestResolverReferenceData;

  TSystemUnitPart = (
    supTObject
    );
  TSystemUnitParts = set of TSystemUnitPart;

  { TCustomTestResolver }

  TCustomTestResolver = Class(TTestParser)
  Private
    FFirstStatement: TPasImplBlock;
    FModules: TObjectList;// list of TTestEnginePasResolver
    FResolverEngine: TTestEnginePasResolver;
    function GetModuleCount: integer;
    function GetModules(Index: integer): TTestEnginePasResolver;
    function OnPasResolverFindUnit(const aUnitName: String): TPasModule;
    procedure OnFindReference(El: TPasElement; FindData: pointer);
    procedure OnCheckElementParent(El: TPasElement; arg: pointer);
    procedure FreeSrcMarkers;
  Protected
    FirstSrcMarker, LastSrcMarker: PSrcMarker;
    Procedure SetUp; override;
    Procedure TearDown; override;
    procedure CreateEngine(var TheEngine: TPasTreeContainer); override;
    procedure ParseProgram; virtual;
    procedure ParseUnit; virtual;
    procedure CheckReferenceDirectives; virtual;
    procedure CheckResolverException(Msg: string; MsgNumber: integer);
    procedure CheckParserException(Msg: string; MsgNumber: integer);
    procedure CheckAccessMarkers; virtual;
    procedure GetSrc(Index: integer; out SrcLines: TStringList; out aFilename: string);
    function FindElementsAt(aFilename: string; aLine, aStartCol, aEndCol: integer): TFPList;// list of TPasElement
    function FindElementsAt(aMarker: PSrcMarker; ErrorOnNoElements: boolean = true): TFPList;// list of TPasElement
    function FindSrcLabel(const Identifier: string): PSrcMarker;
    function FindElementsAtSrcLabel(const Identifier: string; ErrorOnNoElements: boolean = true): TFPList;// list of TPasElement
    procedure WriteSources(const aFilename: string; aRow, aCol: integer);
    procedure RaiseErrorAtSrc(Msg: string; const aFilename: string; aRow, aCol: integer);
    procedure RaiseErrorAtSrcMarker(Msg: string; aMarker: PSrcMarker);
  Public
    function FindModuleWithFilename(aFilename: string): TTestEnginePasResolver;
    function AddModule(aFilename: string): TTestEnginePasResolver;
    function AddModuleWithSrc(aFilename, Src: string): TTestEnginePasResolver;
    function AddModuleWithIntfImplSrc(aFilename, InterfaceSrc,
      ImplementationSrc: string): TTestEnginePasResolver;
    procedure AddSystemUnit(Parts: TSystemUnitParts = []);
    procedure StartProgram(NeedSystemUnit: boolean; SystemUnitParts: TSystemUnitParts = []);
    procedure StartUnit(NeedSystemUnit: boolean);
    property Modules[Index: integer]: TTestEnginePasResolver read GetModules;
    property ModuleCount: integer read GetModuleCount;
    property ResolverEngine: TTestEnginePasResolver read FResolverEngine;
  end;

  { TTestResolver }

  TTestResolver = Class(TCustomTestResolver)
  Published
    Procedure TestEmpty;

    // alias
    Procedure TestAliasType;
    Procedure TestAlias2Type;
    Procedure TestAliasTypeRefs;
    Procedure TestAliasOfVarFail;
    Procedure TestTypeAliasType; // ToDo

    // var, const
    Procedure TestVarLongint;
    Procedure TestVarInteger;
    Procedure TestConstInteger;
    Procedure TestDuplicateVar;
    Procedure TestVarInitConst;
    Procedure TestVarOfVarFail;
    Procedure TestConstOfVarFail;
    Procedure TestTypedConstWrongExprFail;
    Procedure TestVarWrongExprFail;
    Procedure TestArgWrongExprFail;
    Procedure TestIncDec;
    Procedure TestIncStringFail;
    Procedure TestVarExternal;

    // strings
    Procedure TestString_SetLength;
    Procedure TestString_Element;
    Procedure TestStringElement_MissingArgFail;
    Procedure TestStringElement_IndexNonIntFail;
    Procedure TestStringElement_AsVarArgFail;
    Procedure TestString_DoubleQuotesFail;

    // enums
    Procedure TestEnums;
    Procedure TestSets;
    Procedure TestSetOperators;
    Procedure TestEnumParams;
    Procedure TestSetParams;
    Procedure TestSetFunctions;
    Procedure TestEnumHighLow;
    Procedure TestEnumOrd;
    Procedure TestEnumPredSucc;
    Procedure TestEnum_CastIntegerToEnum;

    // operators
    Procedure TestPrgAssignment;
    Procedure TestPrgProcVar;
    Procedure TestUnitProcVar;
    Procedure TestAssignIntegers;
    Procedure TestAssignString;
    Procedure TestAssignIntToStringFail;
    Procedure TestAssignStringToIntFail;
    Procedure TestIntegerOperators;
    Procedure TestBooleanOperators;
    Procedure TestStringOperators;
    Procedure TestFloatOperators;
    Procedure TestCAssignments;
    Procedure TestTypeCastBaseTypes;
    Procedure TestTypeCastStrToIntFail;
    Procedure TestTypeCastIntToStrFail;
    Procedure TestTypeCastDoubleToStrFail;
    Procedure TestTypeCastDoubleToIntFail;
    Procedure TestHighLow;
    Procedure TestAssign_Access;

    // statements
    Procedure TestForLoop;
    Procedure TestStatements;
    Procedure TestCaseStatement;
    Procedure TestTryStatement;
    Procedure TestTryExceptOnNonTypeFail;
    Procedure TestTryExceptOnNonClassFail;
    Procedure TestRaiseNonVarFail;
    Procedure TestRaiseNonClassFail;
    Procedure TestRaiseDescendant;
    Procedure TestStatementsRefs;
    Procedure TestRepeatUntilNonBoolFail;
    Procedure TestWhileDoNonBoolFail;
    Procedure TestIfThenNonBoolFail;
    Procedure TestForLoopVarNonVarFail;
    Procedure TestForLoopStartIncompFail;
    Procedure TestForLoopEndIncompFail;
    Procedure TestCaseOf;
    Procedure TestCaseExprNonOrdFail;
    Procedure TestCaseIncompatibleValueFail;
    Procedure TestSimpleStatement_VarFail;

    // units
    Procedure TestUnitOverloads;
    Procedure TestUnitIntfInitalization;
    Procedure TestUnitUseIntf;
    Procedure TestUnitUseImplFail;

    // procs
    Procedure TestProcParam;
    Procedure TestProcParamAccess;
    Procedure TestFunctionResult;
    Procedure TestProcOverload;
    Procedure TestProcOverloadWithBaseTypes;
    Procedure TestProcOverloadWithClassTypes;
    Procedure TestProcOverloadWithInhClassTypes;
    Procedure TestProcOverloadWithInhAliasClassTypes;
    Procedure TestProcDuplicate;
    Procedure TestNestedProc;
    Procedure TestForwardProc;
    Procedure TestForwardProcUnresolved;
    Procedure TestNestedForwardProc;
    Procedure TestNestedForwardProcUnresolved;
    Procedure TestForwardProcFuncMismatch;
    Procedure TestForwardFuncResultMismatch;
    Procedure TestUnitIntfProc;
    Procedure TestUnitIntfProcUnresolved;
    Procedure TestUnitIntfMismatchArgName;
    Procedure TestProcOverloadIsNotFunc;
    Procedure TestProcCallMissingParams;
    Procedure TestProcArgDefaultValueTypeMismatch;
    Procedure TestProcPassConstToVar;
    Procedure TestBuiltInProcCallMissingParams;
    Procedure TestAssignFunctionResult;
    Procedure TestAssignProcResultFail;
    Procedure TestFunctionResultInCondition;
    Procedure TestExit;
    Procedure TestBreak;
    Procedure TestContinue;
    Procedure TestProcedureExternal;
    Procedure TestProc_UntypedParam_Forward;
    Procedure TestProc_Varargs;
    Procedure TestProc_ParameterExprAccess;
    // ToDo: fail builtin functions in constant with non const param

    // record
    Procedure TestRecord;
    Procedure TestRecordVariant;
    Procedure TestRecordVariantNested;

    // class
    Procedure TestClass;
    Procedure TestClassDefaultInheritance;
    Procedure TestClassTripleInheritance;
    Procedure TestClassForward;
    Procedure TestClassForwardNotResolved;
    Procedure TestClass_Method;
    Procedure TestClass_MethodWithParams;
    Procedure TestClass_MethodUnresolved;
    Procedure TestClass_MethodAbstract;
    Procedure TestClass_MethodAbstractWithoutVirtualFail;
    Procedure TestClass_MethodAbstractHasBodyFail;
    Procedure TestClass_MethodUnresolvedWithAncestor;
    Procedure TestClass_ProcFuncMismatch;
    Procedure TestClass_MethodOverload;
    Procedure TestClass_MethodInvalidOverload;
    Procedure TestClass_MethodOverride;
    Procedure TestClass_MethodOverride2;
    Procedure TestClass_MethodOverrideFixCase;
    Procedure TestClass_MethodOverrideSameResultType;
    Procedure TestClass_MethodOverrideDiffResultTypeFail;
    Procedure TestClass_MethodOverloadAncestor;
    Procedure TestClass_MethodScope;
    Procedure TestClass_IdentifierSelf;
    Procedure TestClassCallInherited;
    Procedure TestClassCallInheritedNoParamsAbstractFail;
    Procedure TestClassCallInheritedWithParamsAbstractFail;
    Procedure TestClassCallInheritedConstructor;
    Procedure TestClassAssignNil;
    Procedure TestClassAssign;
    Procedure TestClassNilAsParam;
    Procedure TestClass_Operators_Is_As;
    Procedure TestClass_OperatorIsOnNonDescendantFail;
    Procedure TestClass_OperatorIsOnNonTypeFail;
    Procedure TestClass_OperatorAsOnNonDescendantFail;
    Procedure TestClass_OperatorAsOnNonTypeFail;
    Procedure TestClassAsFuncResult;
    Procedure TestClassTypeCast;
    Procedure TestClassTypeCastUnrelatedFail;
    Procedure TestClass_TypeCastSelf;
    Procedure TestClass_TypeCaseMultipleParamsFail;
    Procedure TestClass_TypeCastAssign;
    Procedure TestClass_AccessMemberViaClassFail;
    Procedure TestClass_FuncReturningObjectMember;
    Procedure TestClass_StaticWithoutClassFail;
    Procedure TestClass_SelfInStaticFail;
    Procedure TestClass_PrivateProtectedInSameUnit;
    Procedure TestClass_PrivateInMainBeginFail;
    Procedure TestClass_PrivateInDescendantFail;
    Procedure TestClass_ProtectedInDescendant;
    Procedure TestClass_StrictPrivateInMainBeginFail;
    Procedure TestClass_StrictProtectedInMainBeginFail;
    Procedure TestClass_Constructor_NewInstance;
    Procedure TestClass_Constructor_InstanceCallResultFail;
    Procedure TestClass_Destructor_FreeInstance;
    Procedure TestClass_ConDestructor_CallInherited;
    Procedure TestClass_Constructor_Inherited;
    Procedure TestClass_SubObject;
    Procedure TestClass_WithClassInstance;
    Procedure TestClass_ProcedureExternal;
    Procedure TestClass_ReintroducePublicVarFail;
    Procedure TestClass_ReintroducePrivateVar;
    Procedure TestClass_ReintroduceProc;
    Procedure TestClass_UntypedParam_TypeCast;
    // Todo: Fail to use class.method in constant or type, e.g. const p = @o.doit;

    // class of
    Procedure TestClassOf;
    Procedure TestClassOfNonClassFail;
    Procedure TestClassOfIsOperatorFail;
    Procedure TestClassOfAsOperatorFail;
    Procedure TestClass_ClassVar;
    Procedure TestClassOfDotClassVar;
    Procedure TestClassOfDotVarFail;
    Procedure TestClassOfDotClassProc;
    Procedure TestClassOfDotProcFail;
    Procedure TestClassOfDotClassProperty;
    Procedure TestClassOfDotPropertyFail;
    Procedure TestClass_ClassProcSelf;
    Procedure TestClass_ClassProcSelfTypeCastFail;
    Procedure TestClass_ClassMembers;
    Procedure TestClassOf_AsFail;
    Procedure TestClassOf_MemberAsFail;
    Procedure TestClassOf_IsFail;
    Procedure TestClass_TypeCast;
    Procedure TestClassOf_AlwaysForward;

    // property
    Procedure TestProperty1;
    Procedure TestPropertyAccessorNotInFront;
    Procedure TestPropertyReadAccessorVarWrongType;
    Procedure TestPropertyReadAccessorProcNotFunc;
    Procedure TestPropertyReadAccessorFuncWrongResult;
    Procedure TestPropertyReadAccessorFuncWrongArgCount;
    Procedure TestPropertyReadAccessorFunc;
    Procedure TestPropertyWriteAccessorVarWrongType;
    Procedure TestPropertyWriteAccessorFuncNotProc;
    Procedure TestPropertyWriteAccessorProcWrongArgCount;
    Procedure TestPropertyWriteAccessorProcWrongArg;
    Procedure TestPropertyWriteAccessorProcWrongArgType;
    Procedure TestPropertyWriteAccessorProc;
    Procedure TestPropertyTypeless;
    Procedure TestPropertyTypelessNoAncestorFail;
    Procedure TestPropertyStoredAccessorProcNotFunc;
    Procedure TestPropertyStoredAccessorFuncWrongResult;
    Procedure TestPropertyStoredAccessorFuncWrongArgCount;
    Procedure TestPropertyAssign;
    Procedure TestPropertyAssignReadOnlyFail;
    Procedure TestProperty_PassAsParam;
    Procedure TestPropertyReadNonReadableFail;
    Procedure TestPropertyArgs1;
    Procedure TestPropertyArgs2;
    Procedure TestPropertyArgsWithDefaultsFail;
    Procedure TestProperty_Index;
    Procedure TestProperty_WrongTypeAsIndexFail;
    Procedure TestProperty_Option_ClassPropertyNonStatic;
    Procedure TestDefaultProperty;
    Procedure TestMissingDefaultProperty;

    // with
    Procedure TestWithBlock1;
    Procedure TestWithBlock2;
    Procedure TestWithBlockFuncResult;
    Procedure TestWithBlockConstructor;

    // arrays
    Procedure TestDynArrayOfLongint;
    Procedure TestStaticArray;
    Procedure TestArrayOfArray;
    Procedure TestFunctionReturningArray;
    Procedure TestLowHighArray;
    Procedure TestPropertyOfTypeArray;
    Procedure TestArrayElementFromFuncResult_AsParams;
    Procedure TestArrayEnumTypeRange;
    Procedure TestArrayEnumTypeConstNotEnoughValuesFail1;
    Procedure TestArrayEnumTypeConstNotEnoughValuesFail2;
    Procedure TestArrayEnumTypeConstWrongTypeFail;
    Procedure TestArrayEnumTypeConstNonConstFail;
    Procedure TestArrayEnumTypeSetLengthFail;
    Procedure TestArray_AssignNilToStaticArrayFail1;
    Procedure TestArray_SetLengthProperty;
    Procedure TestArray_PassArrayElementToVarParam;

    // procedure types
    Procedure TestProcTypesAssignObjFPC;
    Procedure TestMethodTypesAssignObjFPC;
    Procedure TestProcTypeCall;
    Procedure TestProcType_FunctionFPC;
    Procedure TestProcType_FunctionDelphi;
    Procedure TestProcType_MethodFPC;
    Procedure TestProcType_MethodDelphi;
    Procedure TestAssignProcToMethodFail;
    Procedure TestAssignMethodToProcFail;
    Procedure TestAssignProcToFunctionFail;
    Procedure TestAssignProcWrongArgsFail;
    Procedure TestArrayOfProc;
    Procedure TestProcType_Assigned;
    Procedure TestProcType_TNotifyEvent;
    Procedure TestProcType_TNotifyEvent_NoAtFPC_Fail1;
    Procedure TestProcType_TNotifyEvent_NoAtFPC_Fail2;
    Procedure TestProcType_TNotifyEvent_NoAtFPC_Fail3;
  end;

function LinesToStr(Args: array of const): string;

implementation

function LinesToStr(Args: array of const): string;
var
  s: String;
  i: Integer;
begin
  s:='';
  for i:=Low(Args) to High(Args) do
    case Args[i].VType of
      vtChar:         s += Args[i].VChar+LineEnding;
      vtString:       s += Args[i].VString^+LineEnding;
      vtPChar:        s += Args[i].VPChar+LineEnding;
      vtWideChar:     s += AnsiString(Args[i].VWideChar)+LineEnding;
      vtPWideChar:    s += AnsiString(Args[i].VPWideChar)+LineEnding;
      vtAnsiString:   s += AnsiString(Args[i].VAnsiString)+LineEnding;
      vtWidestring:   s += AnsiString(WideString(Args[i].VWideString))+LineEnding;
      vtUnicodeString:s += AnsiString(UnicodeString(Args[i].VUnicodeString))+LineEnding;
    end;
  Result:=s;
end;

{ TTestEnginePasResolver }

procedure TTestEnginePasResolver.SetModule(AValue: TPasModule);
begin
  if FModule=AValue then Exit;
  if Module<>nil then
    Module.Release;
  FModule:=AValue;
  if Module<>nil then
    Module.AddRef;
end;

constructor TTestEnginePasResolver.Create;
begin
  inherited Create;
  StoreSrcColumns:=true;
end;

destructor TTestEnginePasResolver.Destroy;
begin
  FResolver:=nil;
  Module:=nil;
  FreeAndNil(FParser);
  FreeAndNil(FScanner);
  inherited Destroy;
end;

function TTestEnginePasResolver.FindModule(const AName: String): TPasModule;
begin
  Result:=nil;
  if Assigned(OnFindUnit) then
    Result:=OnFindUnit(AName);
end;

{ TCustomTestResolver }

procedure TCustomTestResolver.SetUp;
begin
  FirstSrcMarker:=nil;
  LastSrcMarker:=nil;
  FModules:=TObjectList.Create(true);
  inherited SetUp;
  Parser.Options:=Parser.Options+[po_ResolveStandardTypes];
end;

procedure TCustomTestResolver.TearDown;
begin
  {$IFDEF VerbosePasResolverMem}
  writeln('TTestResolver.TearDown START FreeSrcMarkers');
  {$ENDIF}
  FreeSrcMarkers;
  {$IFDEF VerbosePasResolverMem}
  writeln('TTestResolver.TearDown ResolverEngine.Clear');
  {$ENDIF}
  ResolverEngine.Clear;
  if FModules<>nil then
    begin
    {$IFDEF VerbosePasResolverMem}
    writeln('TTestResolver.TearDown FModules');
    {$ENDIF}
    FModules.OwnsObjects:=false;
    FModules.Remove(ResolverEngine); // remove reference
    FModules.OwnsObjects:=true;
    FreeAndNil(FModules);// free all other modules
    end;
  {$IFDEF VerbosePasResolverMem}
  writeln('TTestResolver.TearDown inherited');
  {$ENDIF}
  inherited TearDown;
  FResolverEngine:=nil;
  {$IFDEF VerbosePasResolverMem}
  writeln('TTestResolver.TearDown END');
  {$ENDIF}
end;

procedure TCustomTestResolver.CreateEngine(var TheEngine: TPasTreeContainer);
begin
  FResolverEngine:=AddModule(MainFilename);
  TheEngine:=ResolverEngine;
end;

procedure TCustomTestResolver.ParseProgram;
var
  aFilename: String;
  aRow, aCol: Integer;
begin
  FFirstStatement:=nil;
  try
    ParseModule;
  except
    on E: EParserError do
      begin
      aFilename:=E.Filename;
      aRow:=E.Row;
      aCol:=E.Column;
      WriteSources(aFilename,aRow,aCol);
      writeln('ERROR: TTestResolver.ParseProgram Parser: '+E.ClassName+':'+E.Message
        +' Scanner at'
        +' at '+aFilename+'('+IntToStr(aRow)+','+IntToStr(aCol)+')'
        +' Line="'+Scanner.CurLine+'"');
      raise E;
      end;
    on E: EPasResolve do
      begin
      aFilename:=Scanner.CurFilename;
      aRow:=Scanner.CurRow;
      aCol:=Scanner.CurColumn;
      if E.PasElement<>nil then
        begin
        aFilename:=E.PasElement.SourceFilename;
        ResolverEngine.UnmangleSourceLineNumber(E.PasElement.SourceLinenumber,aRow,aCol);
        end;
      WriteSources(aFilename,aRow,aCol);
      writeln('ERROR: TTestResolver.ParseProgram PasResolver: '+E.ClassName+':'+E.Message
        +' at '+aFilename+'('+IntToStr(aRow)+','+IntToStr(aCol)+')');
      raise E;
      end;
    on E: Exception do
      begin
      writeln('ERROR: TTestResolver.ParseProgram Exception: '+E.ClassName+':'+E.Message);
      raise E;
      end;
  end;
  TAssert.AssertSame('Has resolver',ResolverEngine,Parser.Engine);
  AssertEquals('Has program',TPasProgram,Module.ClassType);
  AssertNotNull('Has program section',PasProgram.ProgramSection);
  AssertNotNull('Has initialization section',PasProgram.InitializationSection);
  if (PasProgram.InitializationSection.Elements.Count>0) then
    if TObject(PasProgram.InitializationSection.Elements[0]) is TPasImplBlock then
      FFirstStatement:=TPasImplBlock(PasProgram.InitializationSection.Elements[0]);
  CheckReferenceDirectives;
end;

procedure TCustomTestResolver.ParseUnit;
begin
  FFirstStatement:=nil;
  try
    ParseModule;
  except
    on E: EParserError do
      begin
      writeln('ERROR: TTestResolver.ParseUnit Parser: '+E.ClassName+':'+E.Message
        +' File='+Scanner.CurFilename
        +' LineNo='+IntToStr(Scanner.CurRow)
        +' Col='+IntToStr(Scanner.CurColumn)
        +' Line="'+Scanner.CurLine+'"'
        );
      raise E;
      end;
    on E: EPasResolve do
      begin
      writeln('ERROR: TTestResolver.ParseUnit PasResolver: '+E.ClassName+':'+E.Message
        +' File='+Scanner.CurFilename
        +' LineNo='+IntToStr(Scanner.CurRow)
        +' Col='+IntToStr(Scanner.CurColumn)
        +' Line="'+Scanner.CurLine+'"'
        );
      raise E;
      end;
    on E: Exception do
      begin
      writeln('ERROR: TTestResolver.ParseUnit Exception: '+E.ClassName+':'+E.Message);
      raise E;
      end;
  end;
  TAssert.AssertSame('Has resolver',ResolverEngine,Parser.Engine);
  AssertEquals('Has unit',TPasModule,Module.ClassType);
  AssertNotNull('Has interface section',Module.InterfaceSection);
  AssertNotNull('Has implementation section',Module.ImplementationSection);
  if (Module.InitializationSection<>nil)
  and (Module.InitializationSection.Elements.Count>0) then
    if TObject(Module.InitializationSection.Elements[0]) is TPasImplBlock then
      FFirstStatement:=TPasImplBlock(Module.InitializationSection.Elements[0]);
  CheckReferenceDirectives;
end;

procedure TCustomTestResolver.CheckReferenceDirectives;
var
  Filename: string;
  LineNumber: Integer;
  SrcLine: String;
  CommentStartP, CommentEndP: PChar;

  procedure RaiseError(Msg: string; p: PChar);
  begin
    RaiseErrorAtSrc(Msg,Filename,LineNumber,p-PChar(SrcLine)+1);
  end;

  procedure AddMarker(Marker: PSrcMarker);
  begin
    if LastSrcMarker<>nil then
      LastSrcMarker^.Next:=Marker
    else
      FirstSrcMarker:=Marker;
    LastSrcMarker:=Marker;
  end;

  function AddMarker(Kind: TSrcMarkerKind; const aFilename: string;
    aLine, aStartCol, aEndCol: integer; const Identifier: string): PSrcMarker;
  begin
    New(Result);
    Result^.Kind:=Kind;
    Result^.Filename:=aFilename;
    Result^.Row:=aLine;
    Result^.StartCol:=aStartCol;
    Result^.EndCol:=aEndCol;
    Result^.Identifier:=Identifier;
    Result^.Next:=nil;
    //writeln('AddMarker Line="',SrcLine,'" Identifier=',Identifier,' Col=',aStartCol,'-',aEndCol,' "',copy(SrcLine,aStartCol,aEndCol-aStartCol),'"');
    AddMarker(Result);
  end;

  function AddMarkerForTokenBehindComment(Kind: TSrcMarkerKind;
    const Identifer: string): PSrcMarker;
  var
    TokenStart, p: PChar;
  begin
    p:=CommentEndP;
    ReadNextPascalToken(p,TokenStart,false,false);
    Result:=AddMarker(Kind,Filename,LineNumber,
      CommentEndP-PChar(SrcLine)+1,p-PChar(SrcLine)+1,Identifer);
  end;

  function ReadIdentifier(var p: PChar): string;
  var
    StartP: PChar;
  begin
    if not (p^ in ['a'..'z','A'..'Z','_']) then
      RaiseError('identifier expected',p);
    StartP:=p;
    inc(p);
    while p^ in ['a'..'z','A'..'Z','_','0'..'9'] do inc(p);
    SetLength(Result,p-StartP);
    Move(StartP^,Result[1],length(Result));
  end;

  procedure AddLabel;
  var
    Identifier: String;
    p: PChar;
  begin
    p:=CommentStartP+2;
    Identifier:=ReadIdentifier(p);
    //writeln('TTestResolver.CheckReferenceDirectives.AddLabel ',Identifier);
    if FindSrcLabel(Identifier)<>nil then
      RaiseError('duplicate label "'+Identifier+'"',p);
    AddMarkerForTokenBehindComment(mkLabel,Identifier);
  end;

  procedure AddResolverReference;
  var
    Identifier: String;
    p: PChar;
  begin
    p:=CommentStartP+2;
    Identifier:=ReadIdentifier(p);
    //writeln('TTestResolver.CheckReferenceDirectives.AddReference ',Identifier);
    AddMarkerForTokenBehindComment(mkResolverReference,Identifier);
  end;

  procedure AddDirectReference;
  var
    Identifier: String;
    p: PChar;
  begin
    p:=CommentStartP+2;
    Identifier:=ReadIdentifier(p);
    //writeln('TTestResolver.CheckReferenceDirectives.AddDirectReference ',Identifier);
    AddMarkerForTokenBehindComment(mkDirectReference,Identifier);
  end;

  procedure ParseCode(SrcLines: TStringList; aFilename: string);
  var
    p: PChar;
    IsDirective: Boolean;
  begin
    //writeln('TTestResolver.CheckReferenceDirectives.ParseCode File=',aFilename);
    Filename:=aFilename;
    // parse code, find all labels
    LineNumber:=0;
    while LineNumber<SrcLines.Count do
      begin
      inc(LineNumber);
      SrcLine:=SrcLines[LineNumber-1];
      if SrcLine='' then continue;
      //writeln('TTestResolver.CheckReferenceDirectives Line=',SrcLine);
      p:=PChar(SrcLine);
      repeat
        case p^ of
          #0: if (p-PChar(SrcLine)=length(SrcLine)) then break;
          '{':
            begin
            CommentStartP:=p;
            inc(p);
            IsDirective:=p^ in ['#','@','='];

            // skip to end of comment
            repeat
              case p^ of
              #0:
                if (p-PChar(SrcLine)=length(SrcLine)) then
                  begin
                  // multi line comment
                  if IsDirective then
                    RaiseError('directive missing closing bracket',CommentStartP);
                  repeat
                    inc(LineNumber);
                    if LineNumber>SrcLines.Count then exit;
                    SrcLine:=SrcLines[LineNumber-1];
                    //writeln('TTestResolver.CheckReferenceDirectives Comment Line=',SrcLine);
                  until SrcLine<>'';
                  p:=PChar(SrcLine);
                  continue;
                  end;
              '}':
                begin
                inc(p);
                break;
                end;
              end;
              inc(p);
            until false;

            CommentEndP:=p;
            case CommentStartP[1] of
            '#': AddLabel;
            '@': AddResolverReference;
            '=': AddDirectReference;
            end;
            p:=CommentEndP;
            continue;

            end;
          '/':
            if p[1]='/' then
              break; // rest of line is comment -> skip
        end;
        inc(p);
      until false;
      end;
  end;

  procedure CheckResolverReference(aMarker: PSrcMarker);
  // check if one element at {@a} has a TResolvedReference to an element labeled {#a}
  var
    aLabel: PSrcMarker;
    ReferenceElements, LabelElements: TFPList;
    i, j, aLine, aCol: Integer;
    El, Ref, LabelEl: TPasElement;
  begin
    //writeln('CheckResolverReference searching reference: ',aMarker^.Filename,' Line=',aMarker^.Row,' Col=',aMarker^.StartCol,'-',aMarker^.EndCol,' Label="',aMarker^.Identifier,'"');
    aLabel:=FindSrcLabel(aMarker^.Identifier);
    if aLabel=nil then
      RaiseErrorAtSrc('label "'+aMarker^.Identifier+'" not found',aMarker^.Filename,aMarker^.Row,aMarker^.StartCol);

    LabelElements:=nil;
    ReferenceElements:=nil;
    try
      LabelElements:=FindElementsAt(aLabel);
      ReferenceElements:=FindElementsAt(aMarker);

      for i:=0 to ReferenceElements.Count-1 do
        begin
        El:=TPasElement(ReferenceElements[i]);
        Ref:=nil;
        if El.CustomData is TResolvedReference then
          Ref:=TResolvedReference(El.CustomData).Declaration
        else if El.CustomData is TPasPropertyScope then
          Ref:=TPasPropertyScope(El.CustomData).AncestorProp;
        if Ref<>nil then
          for j:=0 to LabelElements.Count-1 do
            begin
            LabelEl:=TPasElement(LabelElements[j]);
            if Ref=LabelEl then
              exit; // success
            end;
        end;

      // failure write candidates
      for i:=0 to ReferenceElements.Count-1 do
        begin
        El:=TPasElement(ReferenceElements[i]);
        write('Reference candidate for "',aMarker^.Identifier,'" at reference ',aMarker^.Filename,'(',aMarker^.Row,',',aMarker^.StartCol,'-',aMarker^.EndCol,')');
        write(' El=',GetObjName(El));
        Ref:=nil;
        if El.CustomData is TResolvedReference then
          Ref:=TResolvedReference(El.CustomData).Declaration
        else if El.CustomData is TPasPropertyScope then
          Ref:=TPasPropertyScope(El.CustomData).AncestorProp;
        if Ref<>nil then
          begin
          write(' Decl=',GetObjName(Ref));
          ResolverEngine.UnmangleSourceLineNumber(Ref.SourceLinenumber,aLine,aCol);
          write(',',Ref.SourceFilename,'(',aLine,',',aCol,')');
          end
        else
          write(' has no TResolvedReference');
        writeln;
        end;
      for i:=0 to LabelElements.Count-1 do
        begin
        El:=TPasElement(LabelElements[i]);
        write('Label candidate for "',aLabel^.Identifier,'" at reference ',aLabel^.Filename,'(',aLabel^.Row,',',aLabel^.StartCol,'-',aLabel^.EndCol,')');
        write(' El=',GetObjName(El));
        writeln;
        end;

      RaiseErrorAtSrcMarker('wrong resolved reference "'+aMarker^.Identifier+'"',aMarker);
    finally
      LabelElements.Free;
      ReferenceElements.Free;
    end;
  end;

  procedure CheckDirectReference(aMarker: PSrcMarker);
  // check if one element at {=a} is a TPasAliasType pointing to an element labeled {#a}
  var
    aLabel: PSrcMarker;
    ReferenceElements, LabelElements: TFPList;
    i, LabelLine, LabelCol, j: Integer;
    El, LabelEl: TPasElement;
    DeclEl, TypeEl: TPasType;
  begin
    //writeln('CheckDirectReference searching pointer: ',aMarker^.Filename,' Line=',aMarker^.Row,' Col=',aMarker^.StartCol,'-',aMarker^.EndCol,' Label="',aMarker^.Identifier,'"');
    aLabel:=FindSrcLabel(aMarker^.Identifier);
    if aLabel=nil then
      RaiseErrorAtSrcMarker('label "'+aMarker^.Identifier+'" not found',aMarker);

    LabelElements:=nil;
    ReferenceElements:=nil;
    try
      //writeln('CheckDirectReference finding elements at label ...');
      LabelElements:=FindElementsAt(aLabel);
      //writeln('CheckDirectReference finding elements at reference ...');
      ReferenceElements:=FindElementsAt(aMarker);

      for i:=0 to ReferenceElements.Count-1 do
        begin
        El:=TPasElement(ReferenceElements[i]);
        //writeln('CheckDirectReference ',i,'/',ReferenceElements.Count,' ',GetTreeDesc(El,2));
        if El.ClassType=TPasVariable then
          begin
          if TPasVariable(El).VarType=nil then
            begin
            //writeln('CheckDirectReference Var without Type: ',GetObjName(El),' El.Parent=',GetObjName(El.Parent));
            AssertNotNull('TPasVariable(El='+El.Name+').VarType',TPasVariable(El).VarType);
            end;
          TypeEl:=TPasVariable(El).VarType;
          for j:=0 to LabelElements.Count-1 do
            begin
            LabelEl:=TPasElement(LabelElements[j]);
            if TypeEl=LabelEl then
              exit; // success
            end;
          end
        else if El is TPasAliasType then
          begin
          DeclEl:=TPasAliasType(El).DestType;
          ResolverEngine.UnmangleSourceLineNumber(DeclEl.SourceLinenumber,LabelLine,LabelCol);
          if (aLabel^.Filename=DeclEl.SourceFilename)
          and (aLabel^.Row=LabelLine)
          and (aLabel^.StartCol<=LabelCol)
          and (aLabel^.EndCol>=LabelCol) then
            exit; // success
          end
        else if El.ClassType=TPasArgument then
          begin
          TypeEl:=TPasArgument(El).ArgType;
          for j:=0 to LabelElements.Count-1 do
            begin
            LabelEl:=TPasElement(LabelElements[j]);
            if TypeEl=LabelEl then
              exit; // success
            end;
          end;
        end;
      // failed -> show candidates
      writeln('CheckDirectReference failed: Labels:');
      for j:=0 to LabelElements.Count-1 do
        begin
        LabelEl:=TPasElement(LabelElements[j]);
        writeln('  Label ',GetObjName(LabelEl),' at ',ResolverEngine.GetElementSourcePosStr(LabelEl));
        end;
      writeln('CheckDirectReference failed: References:');
      for i:=0 to ReferenceElements.Count-1 do
        begin
        El:=TPasElement(ReferenceElements[i]);
        writeln('  Reference ',GetObjName(El),' at ',ResolverEngine.GetElementSourcePosStr(El));
        end;
      RaiseErrorAtSrcMarker('wrong direct reference "'+aMarker^.Identifier+'"',aMarker);
    finally
      LabelElements.Free;
      ReferenceElements.Free;
    end;
  end;

var
  aMarker: PSrcMarker;
  i: Integer;
  SrcLines: TStringList;
begin
  Module.ForEachCall(@OnCheckElementParent,nil);
  //writeln('TTestResolver.CheckReferenceDirectives find all markers');
  // find all markers
  for i:=0 to Resolver.Streams.Count-1 do
    begin
    GetSrc(i,SrcLines,Filename);
    ParseCode(SrcLines,Filename);
    SrcLines.Free;
    end;

  //writeln('TTestResolver.CheckReferenceDirectives check references');
  // check references
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    case aMarker^.Kind of
    mkResolverReference: CheckResolverReference(aMarker);
    mkDirectReference: CheckDirectReference(aMarker);
    end;
    aMarker:=aMarker^.Next;
    end;
  //writeln('TTestResolver.CheckReferenceDirectives COMPLETE');
end;

procedure TCustomTestResolver.CheckResolverException(Msg: string; MsgNumber: integer);
var
  ok: Boolean;
begin
  ok:=false;
  try
    ParseModule;
  except
    on E: EPasResolve do
      begin
      AssertEquals('Expected {'+Msg+'}, but got msg {'+E.Message+'} number',
        MsgNumber,E.MsgNumber);
      ok:=true;
      end;
  end;
  AssertEquals('Missing resolver error {'+Msg+'} ('+IntToStr(MsgNumber)+')',true,ok);
end;

procedure TCustomTestResolver.CheckParserException(Msg: string; MsgNumber: integer);
var
  ok: Boolean;
begin
  ok:=false;
  try
    ParseModule;
  except
    on E: EParserError do
      begin
      AssertEquals('Expected {'+Msg+'}, but got msg {'+E.Message+'} number',
        MsgNumber,Parser.LastMsgNumber);
      ok:=true;
      end;
  end;
  AssertEquals('Missing parser error '+Msg+' ('+IntToStr(MsgNumber)+')',true,ok);
end;

procedure TCustomTestResolver.CheckAccessMarkers;
const
  AccessNames: array[TResolvedRefAccess] of string = (
    'none',
    'read',
    'assign',
    'readandassign',
    'var',
    'out',
    'paramtest'
    );
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  ActualAccess, ExpectedAccess: TResolvedRefAccess;
  i, j: Integer;
  El, El2: TPasElement;
  Ref: TResolvedReference;
  p: SizeInt;
  AccessPostfix: String;
begin
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.CheckAccessMarkers ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    p:=RPos('_',aMarker^.Identifier);
    if p>1 then
      begin
      AccessPostfix:=copy(aMarker^.Identifier,p+1);
      ExpectedAccess:=High(TResolvedRefAccess);
      repeat
        if CompareText(AccessPostfix,AccessNames[ExpectedAccess])=0 then break;
        if ExpectedAccess=Low(TResolvedRefAccess) then
          RaiseErrorAtSrcMarker('unknown access postfix of reference at "#'+aMarker^.Identifier+'"',aMarker);
        ExpectedAccess:=Pred(ExpectedAccess);
      until false;

      Elements:=FindElementsAt(aMarker);
      try
        ActualAccess:=rraNone;
        for i:=0 to Elements.Count-1 do
          begin
          El:=TPasElement(Elements[i]);
          //writeln('TTestResolver.CheckAccessMarkers ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
          if not (El.CustomData is TResolvedReference) then continue;
          Ref:=TResolvedReference(El.CustomData);
          if ActualAccess<>rraNone then
            begin
            writeln('TTestResolver.CheckAccessMarkers multiple references at "#'+aMarker^.Identifier+'":');
            for j:=0 to Elements.Count-1 do
              begin
              El2:=TPasElement(Elements[i]);
              if not (El2.CustomData is TResolvedReference) then continue;
              //writeln('TTestResolver.CheckAccessMarkers ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
              Ref:=TResolvedReference(El.CustomData);
              writeln('  ',j,'/',Elements.Count,' Element=',GetObjName(El2),' ',AccessNames[Ref.Access],' Declaration="',El2.GetDeclaration(true),'"');
              end;
            RaiseErrorAtSrcMarker('multiple references at "#'+aMarker^.Identifier+'"',aMarker);
            end;
          ActualAccess:=Ref.Access;
          if ActualAccess=rraNone then
            RaiseErrorAtSrcMarker('missing Access in reference at "#'+aMarker^.Identifier+'"',aMarker);
          end;
        if ActualAccess<>ExpectedAccess then
          RaiseErrorAtSrcMarker('expected "'+AccessNames[ExpectedAccess]+'" at "#'+aMarker^.Identifier+'", but got "'+AccessNames[ActualAccess]+'"',aMarker);
      finally
        Elements.Free;
      end;
      end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TCustomTestResolver.GetSrc(Index: integer; out SrcLines: TStringList; out
  aFilename: string);
var
  aStream: TStream;
begin
  SrcLines:=TStringList.Create;
  aStream:=Resolver.Streams.Objects[Index] as TStream;
  aStream.Position:=0;
  SrcLines.LoadFromStream(aStream);
  aFilename:=Resolver.Streams[Index];
end;

function TCustomTestResolver.FindElementsAt(aFilename: string; aLine, aStartCol,
  aEndCol: integer): TFPList;
var
  ok: Boolean;
  FoundRefs: TTestResolverReferenceData;
begin
  FoundRefs:=Default(TTestResolverReferenceData);
  FoundRefs.Filename:=aFilename;
  FoundRefs.Row:=aLine;
  FoundRefs.StartCol:=aStartCol;
  FoundRefs.EndCol:=aEndCol;
  FoundRefs.Found:=TFPList.Create;
  ok:=false;
  try
    Module.ForEachCall(@OnFindReference,@FoundRefs);
    ok:=true;
  finally
    if not ok then
      FreeAndNil(FoundRefs.Found);
  end;
  Result:=FoundRefs.Found;
  FoundRefs.Found:=nil;
end;

function TCustomTestResolver.FindElementsAt(aMarker: PSrcMarker;
  ErrorOnNoElements: boolean): TFPList;
begin
  Result:=FindElementsAt(aMarker^.Filename,aMarker^.Row,aMarker^.StartCol,aMarker^.EndCol);
  if ErrorOnNoElements and ((Result=nil) or (Result.Count=0)) then
    RaiseErrorAtSrcMarker('marker '+SrcMarker[aMarker^.Kind]+aMarker^.Identifier+' has no elements',aMarker);
end;

function TCustomTestResolver.FindSrcLabel(const Identifier: string): PSrcMarker;
begin
  Result:=FirstSrcMarker;
  while Result<>nil do
    begin
    if (Result^.Kind=mkLabel)
    and (CompareText(Result^.Identifier,Identifier)=0) then
      exit;
    Result:=Result^.Next;
    end;
end;

function TCustomTestResolver.FindElementsAtSrcLabel(const Identifier: string;
  ErrorOnNoElements: boolean): TFPList;
var
  SrcLabel: PSrcMarker;
begin
  SrcLabel:=FindSrcLabel(Identifier);
  if SrcLabel=nil then
    Fail('missing label "'+Identifier+'"');
  Result:=FindElementsAt(SrcLabel,ErrorOnNoElements);
end;

procedure TCustomTestResolver.WriteSources(const aFilename: string; aRow,
  aCol: integer);
var
  IsSrc: Boolean;
  i, j: Integer;
  SrcLines: TStringList;
  SrcFilename, Line: string;
begin
  for i:=0 to Resolver.Streams.Count-1 do
    begin
    GetSrc(i,SrcLines,SrcFilename);
    IsSrc:=ExtractFilename(aFilename)=ExtractFileName(aFilename);
    writeln('Testcode:-File="',SrcFilename,'"----------------------------------:');
    for j:=1 to SrcLines.Count do
      begin
      Line:=SrcLines[j-1];
      if IsSrc and (j=aRow) then
        begin
        write('*');
        Line:=LeftStr(Line,aCol-1)+'|'+copy(Line,aCol,length(Line));
        end;
      writeln(Format('%:4d: ',[j]),Line);
      end;
    SrcLines.Free;
    end;
end;

procedure TCustomTestResolver.RaiseErrorAtSrc(Msg: string; const aFilename: string;
  aRow, aCol: integer);
var
  s: String;
begin
  WriteSources(aFilename,aRow,aCol);
  s:='[TTestResolver.RaiseErrorAtSrc] '+aFilename+'('+IntToStr(aRow)+','+IntToStr(aCol)+') Error: '+Msg;
  writeln('ERROR: ',s);
  raise EAssertionFailedError.Create(s);
end;

procedure TCustomTestResolver.RaiseErrorAtSrcMarker(Msg: string; aMarker: PSrcMarker);
begin
  RaiseErrorAtSrc(Msg,aMarker^.Filename,aMarker^.Row,aMarker^.StartCol);
end;

function TCustomTestResolver.FindModuleWithFilename(aFilename: string
  ): TTestEnginePasResolver;
var
  i: Integer;
begin
  for i:=0 to ModuleCount-1 do
    if CompareText(Modules[i].Filename,aFilename)=0 then
      exit(Modules[i]);
  Result:=nil;
end;

function TCustomTestResolver.AddModule(aFilename: string): TTestEnginePasResolver;
begin
  //writeln('TTestResolver.AddModule ',aFilename);
  if FindModuleWithFilename(aFilename)<>nil then
    raise EAssertionFailedError.Create('TTestResolver.AddModule: file "'+aFilename+'" already exists');
  Result:=TTestEnginePasResolver.Create;
  Result.Filename:=aFilename;
  Result.AddObjFPCBuiltInIdentifiers;
  Result.OnFindUnit:=@OnPasResolverFindUnit;
  FModules.Add(Result);
end;

function TCustomTestResolver.AddModuleWithSrc(aFilename, Src: string
  ): TTestEnginePasResolver;
begin
  Result:=AddModule(aFilename);
  Result.Source:=Src;
end;

function TCustomTestResolver.AddModuleWithIntfImplSrc(aFilename, InterfaceSrc,
  ImplementationSrc: string): TTestEnginePasResolver;
var
  Src: String;
begin
  Src:='unit '+ExtractFileUnitName(aFilename)+';'+LineEnding;
  Src+=LineEnding;
  Src+='interface'+LineEnding;
  Src+=LineEnding;
  Src+=InterfaceSrc;
  Src+='implementation'+LineEnding;
  Src+=LineEnding;
  Src+=ImplementationSrc;
  Src+='end.'+LineEnding;
  Result:=AddModuleWithSrc(aFilename,Src);
end;

procedure TCustomTestResolver.AddSystemUnit(Parts: TSystemUnitParts);
var
  Intf, Impl: TStringList;
begin
  Intf:=TStringList.Create;
  // interface
  Intf.Add('type');
  Intf.Add('  integer=longint;');
  Intf.Add('  sizeint=int64;');
    //'const',
    //'  LineEnding = #10;',
    //'  DirectorySeparator = ''/'';',
    //'  DriveSeparator = '''';',
    //'  AllowDirectorySeparators : set of char = [''\'',''/''];',
    //'  AllowDriveSeparators : set of char = [];',
  if supTObject in Parts then
    begin
    Intf.AddStrings([
    'type',
    '  TClass = class of TObject;',
    '  TObject = class',
    '    constructor Create;',
    '    destructor Destroy; virtual;',
    '    class function ClassType: TClass; assembler;',
    '    class function ClassName: String; assembler;',
    '    class function ClassNameIs(const Name: string): boolean;',
    '    class function ClassParent: TClass; assembler;',
    '    class function InheritsFrom(aClass: TClass): boolean; assembler;',
    '    class function UnitName: String; assembler;',
    '    procedure AfterConstruction; virtual;',
    '    procedure BeforeDestruction;virtual;',
    '    function Equals(Obj: TObject): boolean; virtual;',
    '    function ToString: String; virtual;',
    '  end;']);
    end;
  Intf.Add('var');
  Intf.Add('  ExitCode: Longint = 0;');

  // implementation
  Impl:=TStringList.Create;
  if supTObject in Parts then
    begin
    Impl.AddStrings([
      '// needed by ClassNameIs, the real SameText is in SysUtils',
      'function SameText(const s1, s2: String): Boolean; assembler;',
      'asm',
      'end;',
      'constructor TObject.Create; begin end;',
      'destructor TObject.Destroy; begin end;',
      'class function TObject.ClassType: TClass; assembler;',
      'asm',
      'end;',
      'class function TObject.ClassName: String; assembler;',
      'asm',
      'end;',
      'class function TObject.ClassNameIs(const Name: string): boolean;',
      'begin',
      '  Result:=SameText(Name,ClassName);',
      'end;',
      'class function TObject.ClassParent: TClass; assembler;',
      'asm',
      'end;',
      'class function TObject.InheritsFrom(aClass: TClass): boolean; assembler;',
      'asm',
      'end;',
      'class function TObject.UnitName: String; assembler;',
      'asm',
      'end;',
      'procedure TObject.AfterConstruction; begin end;',
      'procedure TObject.BeforeDestruction; begin end;',
      'function TObject.Equals(Obj: TObject): boolean;',
      'begin',
      '  Result:=Obj=Self;',
      'end;',
      'function TObject.ToString: String;',
      'begin',
      '  Result:=ClassName;',
      'end;'
      ]);
    end;

  try
    AddModuleWithIntfImplSrc('system.pp',Intf.Text,Impl.Text);
  finally
    Intf.Free;
    Impl.Free;
  end;
end;

procedure TCustomTestResolver.StartProgram(NeedSystemUnit: boolean;
  SystemUnitParts: TSystemUnitParts);
begin
  if NeedSystemUnit then
    AddSystemUnit(SystemUnitParts)
  else
    Parser.ImplicitUses.Clear;
  Add('program '+ExtractFileUnitName(MainFilename)+';');
end;

procedure TCustomTestResolver.StartUnit(NeedSystemUnit: boolean);
begin
  if NeedSystemUnit then
    AddSystemUnit
  else
    Parser.ImplicitUses.Clear;
  Add('unit '+ExtractFileUnitName(MainFilename)+';');
end;

function TCustomTestResolver.OnPasResolverFindUnit(const aUnitName: String
  ): TPasModule;
var
  i, ErrRow, ErrCol: Integer;
  CurEngine: TTestEnginePasResolver;
  CurUnitName, ErrFilename: String;
begin
  //writeln('TTestResolver.OnPasResolverFindUnit START Unit="',aUnitName,'"');
  Result:=nil;
  for i:=0 to ModuleCount-1 do
    begin
    CurEngine:=Modules[i];
    CurUnitName:=ExtractFileUnitName(CurEngine.Filename);
    //writeln('TTestResolver.OnPasResolverFindUnit Checking ',i,'/',ModuleCount,' ',CurEngine.Filename,' ',CurUnitName);
    if CompareText(aUnitName,CurUnitName)=0 then
      begin
      Result:=CurEngine.Module;
      if Result<>nil then exit;
      //writeln('TTestResolver.OnPasResolverFindUnit PARSING unit "',CurEngine.Filename,'"');
      //Resolver.FindSourceFile(aUnitName);

      CurEngine.Resolver:=Resolver;
      //CurEngine.Resolver:=TStreamResolver.Create;
      //CurEngine.Resolver.OwnsStreams:=True;
      //writeln('TTestResolver.OnPasResolverFindUnit SOURCE=',CurEngine.Source);
      CurEngine.Resolver.AddStream(CurEngine.FileName,TStringStream.Create(CurEngine.Source));
      CurEngine.Scanner:=TPascalScanner.Create(CurEngine.Resolver);
      CurEngine.Parser:=TPasParser.Create(CurEngine.Scanner,CurEngine.Resolver,CurEngine);
      if CompareText(CurUnitName,'System')=0 then
        CurEngine.Parser.ImplicitUses.Clear;
      CurEngine.Scanner.OpenFile(CurEngine.Filename);
      try
        CurEngine.Parser.NextToken;
        CurEngine.Parser.ParseUnit(CurEngine.FModule);
      except
        on E: Exception do
          begin
          ErrFilename:=CurEngine.Scanner.CurFilename;
          ErrRow:=CurEngine.Scanner.CurRow;
          ErrCol:=CurEngine.Scanner.CurColumn;
          writeln('ERROR: TTestResolver.OnPasResolverFindUnit during parsing: '+E.ClassName+':'+E.Message
            +' File='+ErrFilename
            +' LineNo='+IntToStr(ErrRow)
            +' Col='+IntToStr(ErrCol)
            +' Line="'+CurEngine.Scanner.CurLine+'"'
            );
          WriteSources(ErrFilename,ErrRow,ErrCol);
          raise E;
          end;
      end;
      //writeln('TTestResolver.OnPasResolverFindUnit END ',CurUnitName);
      Result:=CurEngine.Module;
      exit;
      end;
    end;
  writeln('TTestResolver.OnPasResolverFindUnit missing unit "',aUnitName,'"');
  raise EAssertionFailedError.Create('can''t find unit "'+aUnitName+'"');
end;

procedure TCustomTestResolver.OnFindReference(El: TPasElement; FindData: pointer);
var
  Data: PTestResolverReferenceData absolute FindData;
  Line, Col: integer;
begin
  ResolverEngine.UnmangleSourceLineNumber(El.SourceLinenumber,Line,Col);
  //writeln('TTestResolver.OnFindReference ',El.SourceFilename,' Line=',Line,',Col=',Col,' ',GetObjName(El),' SearchFile=',Data^.Filename,',Line=',Data^.Row,',Col=',Data^.StartCol,'-',Data^.EndCol);
  if (Data^.Filename=El.SourceFilename)
  and (Data^.Row=Line)
  and (Data^.StartCol<=Col)
  and (Data^.EndCol>=Col)
  then
    Data^.Found.Add(El);
end;

procedure TCustomTestResolver.OnCheckElementParent(El: TPasElement; arg: pointer);
var
  SubEl: TPasElement;
  i: Integer;

  procedure E(Msg: string);
  var
    s: String;
  begin
    s:='TTestResolver.OnCheckElementParent El='+GetTreeDesc(El)+' '+
      ResolverEngine.GetElementSourcePosStr(El)+' '+Msg;
    writeln('ERROR: ',s);
    raise EAssertionFailedError.Create(s);
  end;

begin
  if arg=nil then ;
  //writeln('TTestResolver.OnCheckElementParent ',GetObjName(El));
  if El=nil then exit;
  if El.Parent=El then
    E('El.Parent=El='+GetObjName(El));
  if El is TBinaryExpr then
    begin
    if (TBinaryExpr(El).left<>nil) and (TBinaryExpr(El).left.Parent<>El) then
      E('TBinaryExpr(El).left.Parent='+GetObjName(TBinaryExpr(El).left.Parent)+'<>El');
    if (TBinaryExpr(El).right<>nil) and (TBinaryExpr(El).right.Parent<>El) then
      E('TBinaryExpr(El).right.Parent='+GetObjName(TBinaryExpr(El).right.Parent)+'<>El');
    end
  else if El is TParamsExpr then
    begin
    if (TParamsExpr(El).Value<>nil) and (TParamsExpr(El).Value.Parent<>El) then
      E('TParamsExpr(El).Value.Parent='+GetObjName(TParamsExpr(El).Value.Parent)+'<>El');
    for i:=0 to length(TParamsExpr(El).Params)-1 do
      if TParamsExpr(El).Params[i].Parent<>El then
        E('TParamsExpr(El).Params[i].Parent='+GetObjName(TParamsExpr(El).Params[i].Parent)+'<>El');
    end
  else if El is TPasDeclarations then
    begin
    for i:=0 to TPasDeclarations(El).Declarations.Count-1 do
      begin
      SubEl:=TPasElement(TPasDeclarations(El).Declarations[i]);
      if SubEl.Parent<>El then
        E('SubEl=TPasElement(TPasDeclarations(El).Declarations[i])='+GetObjName(SubEl)+' SubEl.Parent='+GetObjName(SubEl.Parent)+'<>El');
      end;
    end
  else if El is TPasImplBlock then
    begin
    for i:=0 to TPasImplBlock(El).Elements.Count-1 do
      begin
      SubEl:=TPasElement(TPasImplBlock(El).Elements[i]);
      if SubEl.Parent<>El then
        E('TPasElement(TPasImplBlock(El).Elements[i]).Parent='+GetObjName(SubEl.Parent)+'<>El');
      end;
    end
  else if El is TPasImplWithDo then
    begin
    for i:=0 to TPasImplWithDo(El).Expressions.Count-1 do
      begin
      SubEl:=TPasExpr(TPasImplWithDo(El).Expressions[i]);
      if SubEl.Parent<>El then
        E('TPasExpr(TPasImplWithDo(El).Expressions[i]).Parent='+GetObjName(SubEl.Parent)+'<>El');
      end;
    end
  else if El is TPasProcedure then
    begin
    if TPasProcedure(El).ProcType.Parent<>El then
      E('TPasProcedure(El).ProcType.Parent='+GetObjName(TPasProcedure(El).ProcType.Parent)+'<>El');
    end
  else if El is TPasProcedureType then
    begin
    for i:=0 to TPasProcedureType(El).Args.Count-1 do
      if TPasArgument(TPasProcedureType(El).Args[i]).Parent<>El then
        E('TPasArgument(TPasProcedureType(El).Args[i]).Parent='+GetObjName(TPasArgument(TPasProcedureType(El).Args[i]).Parent)+'<>El');
    end;
end;

procedure TCustomTestResolver.FreeSrcMarkers;
var
  aMarker, Last: PSrcMarker;
begin
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    Last:=aMarker;
    aMarker:=aMarker^.Next;
    Dispose(Last);
    end;
end;

function TCustomTestResolver.GetModules(Index: integer): TTestEnginePasResolver;
begin
  Result:=TTestEnginePasResolver(FModules[Index]);
end;

function TCustomTestResolver.GetModuleCount: integer;
begin
  Result:=FModules.Count;
end;

{ TTestResolver }

procedure TTestResolver.TestEmpty;
begin
  StartProgram(false);
  Add('begin');
  ParseProgram;
  AssertEquals('No statements',0,PasProgram.InitializationSection.Elements.Count);
end;

procedure TTestResolver.TestAliasType;
var
  El: TPasElement;
  T: TPasAliasType;
begin
  StartProgram(false);
  Add('type');
  Add('  tint=longint;');
  Add('begin');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);
  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('Type',TPasAliasType,El.ClassType);
  T:=TPasAliasType(El);
  AssertEquals('Type tint','tint',T.Name);
  AssertEquals('Type built-in',TPasUnresolvedSymbolRef,T.DestType.ClassType);
  AssertEquals('longint type','longint',lowercase(T.DestType.Name));
end;

procedure TTestResolver.TestAlias2Type;
var
  El: TPasElement;
  T1, T2: TPasAliasType;
  DestT1, DestT2: TPasType;
begin
  StartProgram(false);
  Add('type');
  Add('  tint1=longint;');
  Add('  tint2=tint1;');
  Add('begin');
  ParseProgram;
  AssertEquals('2 declaration',2,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('Type',TPasAliasType,El.ClassType);
  T1:=TPasAliasType(El);
  AssertEquals('Type tint1','tint1',T1.Name);
  DestT1:=T1.DestType;
  AssertEquals('built-in',TPasUnresolvedSymbolRef,DestT1.ClassType);
  AssertEquals('built-in longint','longint',lowercase(DestT1.Name));

  El:=TPasElement(PasProgram.ProgramSection.Declarations[1]);
  AssertEquals('Type',TPasAliasType,El.ClassType);
  T2:=TPasAliasType(El);
  AssertEquals('Type tint2','tint2',T2.Name);
  DestT2:=T2.DestType;
  AssertEquals('points to alias type',TPasAliasType,DestT2.ClassType);
  AssertEquals('points to tint1','tint1',DestT2.Name);
end;

procedure TTestResolver.TestAliasTypeRefs;
begin
  StartProgram(false);
  Add('type');
  Add('  {#a}a=longint;');
  Add('  {#b}{=a}b=a;');
  Add('var');
  Add('  {=a}c: a;');
  Add('  {=b}d: b;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestAliasOfVarFail;
begin
  StartProgram(false);
  Add('var');
  Add('  a: char;');
  Add('type');
  Add('  t=a;');
  Add('begin');
  CheckParserException('Expected type, but got variable',PParser.nParserExpectedTypeButGot);
end;

procedure TTestResolver.TestTypeAliasType;
begin
  // ToDo
  StartProgram(false);
  Add('type');
  Add('  {#integer}integer = longint;');
  Add('  {#tcolor}TColor = type integer;');
  Add('var');
  Add('  {=integer}i: integer;');
  Add('  {=tcolor}c: TColor;');
  Add('begin');
  Add('  c:=i;');
  Add('  i:=c;');
  Add('  i:=integer(c);');
  Add('  c:=TColor(i);');
  // ParseProgram;
end;

procedure TTestResolver.TestVarLongint;
var
  El: TPasElement;
  V1: TPasVariable;
  DestT1: TPasType;
begin
  StartProgram(false);
  Add('var');
  Add('  v1:longint;');
  Add('begin');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('var',TPasVariable,El.ClassType);
  V1:=TPasVariable(El);
  AssertEquals('var v1','v1',V1.Name);
  DestT1:=V1.VarType;
  AssertEquals('built-in',TPasUnresolvedSymbolRef,DestT1.ClassType);
  AssertEquals('built-in longint','longint',lowercase(DestT1.Name));
end;

procedure TTestResolver.TestVarInteger;
var
  El: TPasElement;
  V1: TPasVariable;
  DestT1: TPasType;
begin
  StartProgram(true);
  Add('var');
  Add('  v1:integer;'); // defined in system.pp
  Add('begin');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('var',TPasVariable,El.ClassType);
  V1:=TPasVariable(El);
  AssertEquals('var v1','v1',V1.Name);
  DestT1:=V1.VarType;
  AssertNotNull('v1 type',DestT1);
  AssertEquals('built-in',TPasAliasType,DestT1.ClassType);
  AssertEquals('built-in integer','integer',DestT1.Name);
  AssertNull('v1 no expr',V1.Expr);
end;

procedure TTestResolver.TestConstInteger;
var
  El: TPasElement;
  C1: TPasConst;
  DestT1: TPasType;
  ExprC1: TPrimitiveExpr;
begin
  StartProgram(true);
  Add('const');
  Add('  c1:integer=3;'); // defined in system.pp
  Add('begin');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('const',TPasConst,El.ClassType);
  C1:=TPasConst(El);
  AssertEquals('const c1','c1',C1.Name);
  DestT1:=C1.VarType;
  AssertNotNull('c1 type',DestT1);
  AssertEquals('built-in',TPasAliasType,DestT1.ClassType);
  AssertEquals('built-in integer','integer',DestT1.Name);
  ExprC1:=TPrimitiveExpr(C1.Expr);
  AssertNotNull('c1 expr',ExprC1);
  AssertEquals('c1 expr primitive',TPrimitiveExpr,ExprC1.ClassType);
  AssertEquals('c1 expr value','3',ExprC1.Value);
end;

procedure TTestResolver.TestDuplicateVar;
begin
  StartProgram(false);
  Add('var a: longint;');
  Add('var a: string;');
  Add('begin');
  CheckResolverException('duplicate identifier',PasResolver.nDuplicateIdentifier);
end;

procedure TTestResolver.TestVarInitConst;
begin
  StartProgram(false);
  Add('const {#c}c=1;');
  Add('var a: longint = {@c}c;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestVarOfVarFail;
begin
  StartProgram(false);
  Add('var');
  Add('  a: char;');
  Add('  b: a;');
  Add('begin');
  CheckParserException('Expected type, but got variable',PParser.nParserExpectedTypeButGot);
end;

procedure TTestResolver.TestConstOfVarFail;
begin
  StartProgram(false);
  Add('var');
  Add('  a: longint;');
  Add('const');
  Add('  b: a = 1;');
  Add('begin');
  CheckParserException('Expected type, but got variable',PParser.nParserExpectedTypeButGot);
end;

procedure TTestResolver.TestTypedConstWrongExprFail;
begin
  StartProgram(false);
  Add('const');
  Add('  a: string = 1;');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestVarWrongExprFail;
begin
  StartProgram(false);
  Add('var');
  Add('  a: string = 1;');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestArgWrongExprFail;
begin
  StartProgram(false);
  Add('procedure ProcA(a: string = 1);');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestIncDec;
begin
  StartProgram(false);
  Add('var');
  Add('  i: longint;');
  Add('begin');
  Add('  inc({#a_var}i);');
  Add('  inc({#b_var}i,2);');
  Add('  dec({#c_var}i);');
  Add('  dec({#d_var}i,3);');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestIncStringFail;
begin
  StartProgram(false);
  Add('var');
  Add('  i: string;');
  Add('begin');
  Add('  inc(i);');
  CheckResolverException('Incompatible type arg no. 1: Got "String", expected "Longint"',PasResolver.nIncompatibleTypeArgNo);
end;

procedure TTestResolver.TestVarExternal;
begin
  StartProgram(false);
  Add('var');
  Add('  NaN: double; external name ''Global.Nan'';');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestString_SetLength;
begin
  StartProgram(false);
  Add('var');
  Add('  s: string;');
  Add('begin');
  Add('  SetLength({#a_var}s,3);');
  Add('  SetLength({#b_var}s,length({#c_read}s));');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestString_Element;
begin
  StartProgram(false);
  Add('var');
  Add('  s: string;');
  Add('  c: char;');
  Add('begin');
  Add('  if s[1]=s then ;');
  Add('  if s=s[2] then ;');
  Add('  if s[3+4]=c then ;');
  Add('  if c=s[5] then ;');
  Add('  c:=s[6];');
  Add('  s[7]:=c;');
  Add('  s[8]:=''a'';');
  ParseProgram;
end;

procedure TTestResolver.TestStringElement_MissingArgFail;
begin
  StartProgram(false);
  Add('var s: string;');
  Add('begin');
  Add('  if s[]=s then ;');
  CheckResolverException('Missing parameter character index',PasResolver.nMissingParameterX);
end;

procedure TTestResolver.TestStringElement_IndexNonIntFail;
begin
  StartProgram(false);
  Add('var s: string;');
  Add('begin');
  Add('  if s[true]=s then ;');
  CheckResolverException('Incompatible types: got "Boolean" expected "Char"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestStringElement_AsVarArgFail;
begin
  StartProgram(false);
  Add('procedure DoIt(var c: char);');
  Add('begin');
  Add('end;');
  Add('var s: string;');
  Add('begin');
  Add('  DoIt(s[1]);');
  CheckResolverException('Variable identifier expected',
    PasResolver.nVariableIdentifierExpected);
end;

procedure TTestResolver.TestString_DoubleQuotesFail;
begin
  StartProgram(false);
  Add('var s: string;');
  Add('begin');
  Add('  s:="abc" + "def";');
  CheckParserException('Invalid character ''"''',PScanner.nErrInvalidCharacter);
end;

procedure TTestResolver.TestEnums;
begin
  StartProgram(false);
  Add('type {#TFlag}TFlag = ({#Red}Red, {#Green}Green, {#Blue}Blue);');
  Add('var');
  Add('  {#f}{=TFlag}f: TFlag;');
  Add('  {#v}{=TFlag}v: TFlag = Green;');
  Add('begin');
  Add('  {@f}f:={@Red}Red;');
  Add('  {@f}f:={@v}v;');
  Add('  if {@f}f={@Red}Red then ;');
  Add('  if {@f}f={@v}v then ;');
  Add('  if {@f}f>{@v}v then ;');
  Add('  if {@f}f<{@v}v then ;');
  Add('  if {@f}f>={@v}v then ;');
  Add('  if {@f}f<={@v}v then ;');
  Add('  if {@f}f<>{@v}v then ;');
  Add('  if ord({@f}f)<>ord({@Red}Red) then ;');
  Add('  {@f}f:={@TFlag}TFlag.{@Red}Red;');
  ParseProgram;
end;

procedure TTestResolver.TestSets;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TFlag}TFlag = ({#Red}Red, {#Green}Green, {#Blue}Blue, {#Gray}Gray, {#Black}Black, {#White}White);');
  Add('  {#TFlags}TFlags = set of TFlag;');
  Add('  {#TChars}TChars = set of Char;');
  Add('  {#TMyInt}TMyInt = 0..17;');
  Add('  {#TMyInts}TMyInts = set of TMyInt;');
  Add('  {#TMyBools}TMyBools = set of boolean;');
  Add('const');
  Add('  {#Colors}Colors = [{@Red}Red..{@Blue}Blue];');
  Add('  {#ExtColors}ExtColors = {@Colors}Colors+[{@White}White,{@Black}Black];');
  Add('var');
  Add('  {#f}{=TFlag}f: TFlag;');
  Add('  {#s}{=TFlags}s: TFlags;');
  Add('  {#t}{=TFlags}t: TFlags = [Green,Gray];');
  Add('  {#Chars}{=TChars}Chars: TChars;');
  Add('  {#MyInts}{=TMyInts}MyInts: TMyInts;');
  Add('  {#MyBools}{=TMyBools}MyBools: TMyBools;');
  Add('begin');
  Add('  {@s}s:=[];');
  Add('  {@s}s:={@t}t;');
  Add('  {@s}s:=[{@Red}Red];');
  Add('  {@s}s:=[{@Red}Red,{@Blue}Blue];');
  Add('  {@s}s:=[{@Gray}Gray..{@White}White];');
  Add('  {@MyInts}MyInts:=[1];');
  Add('  {@MyInts}MyInts:=[1,2];');
  Add('  {@MyInts}MyInts:=[1..2];');
  Add('  {@MyInts}MyInts:=[1..2,3];');
  Add('  {@MyInts}MyInts:=[1..2,3..4];');
  Add('  {@MyInts}MyInts:=[1,2..3];');
  Add('  {@MyBools}MyBools:=[false];');
  Add('  {@MyBools}MyBools:=[false,true];');
  Add('  {@MyBools}MyBools:=[true..false];');
  ParseProgram;
end;

procedure TTestResolver.TestSetOperators;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TFlag}TFlag = ({#Red}Red, {#Green}Green, {#Blue}Blue, {#Gray}Gray, {#Black}Black, {#White}White);');
  Add('  {#TFlags}TFlags = set of TFlag;');
  Add('  {#TChars}TChars = set of Char;');
  Add('  {#TMyInt}TMyInt = 0..17;');
  Add('  {#TMyInts}TMyInts = set of TMyInt;');
  Add('  {#TMyBools}TMyBools = set of boolean;');
  Add('const');
  Add('  {#Colors}Colors = [{@Red}Red..{@Blue}Blue];');
  Add('  {#ExtColors}ExtColors = {@Colors}Colors+[{@White}White,{@Black}Black];');
  Add('var');
  Add('  {#f}{=TFlag}f: TFlag;');
  Add('  {#s}{=TFlags}s: TFlags;');
  Add('  {#t}{=TFlags}t: TFlags = [Green,Gray];');
  Add('  {#Chars}{=TChars}Chars: TChars;');
  Add('  {#MyInts}{=TMyInts}MyInts: TMyInts;');
  Add('  {#MyBools}{=TMyBools}MyBools: TMyBools;');
  Add('begin');
  Add('  {@s}s:=[];');
  Add('  {@s}s:=[{@Red}Red]+[{@Blue}Blue,{@Gray}Gray];');
  Add('  {@s}s:=[{@Blue}Blue,{@Gray}Gray]-[{@Blue}Blue];');
  Add('  {@s}s:={@t}t+[];');
  Add('  {@s}s:=[{@Red}Red]+{@s}s;');
  Add('  {@s}s:={@s}s+[{@Red}Red];');
  Add('  {@s}s:=[{@Red}Red]-{@s}s;');
  Add('  {@s}s:={@s}s-[{@Red}Red];');
  Add('  Include({@s}s,{@Blue}Blue);');
  Add('  Include({@s}s,{@f}f);');
  Add('  Exclude({@s}s,{@Blue}Blue);');
  Add('  Exclude({@s}s,{@f}f);');
  Add('  {@s}s:={@s}s+[{@f}f];');
  Add('  if {@Green}Green in {@s}s then ;');
  Add('  if {@Blue}Blue in {@Colors}Colors then ;');
  Add('  if {@f}f in {@ExtColors}ExtColors then ;');
  Add('  {@s}s:={@s}s * {@Colors}Colors;');
  Add('  {@s}s:={@Colors}Colors * {@s}s;');
  Add('  {@s}s:={@ExtColors}ExtColors * {@Colors}Colors;');
  Add('  {@s}s:=Colors >< {@ExtColors}ExtColors;');
  Add('  {@s}s:={@s}s >< {@ExtColors}ExtColors;');
  Add('  {@s}s:={@ExtColors}ExtColors >< s;');
  Add('  {@s}s:={@s}s >< {@s}s;');
  Add('  if ''p'' in [''a''..''z''] then ; ');
  Add('  if ''p'' in [''a''..''z'',''A''..''Z'',''0''..''9'',''_''] then ; ');
  Add('  if ''p'' in {@Chars}Chars then ; ');
  Add('  if 7 in {@MyInts}MyInts then ; ');
  Add('  if 7 in [1+2,(3*4)+5,(-2+6)..(8-3)] then ; ');
  Add('  if [red,blue]*s=[red,blue] then ;');
  Add('  if {@s}s = t then;');
  Add('  if {@s}s = {@Colors}Colors then;');
  Add('  if {@Colors}Colors = s then;');
  Add('  if {@s}s <> t then;');
  Add('  if {@s}s <> {@Colors}Colors then;');
  Add('  if {@Colors}Colors <> s then;');
  Add('  if {@s}s <= t then;');
  Add('  if {@s}s <= {@Colors}Colors then;');
  Add('  if {@Colors}Colors <= s then;');
  Add('  if {@s}s >= t then;');
  Add('  if {@s}s >= {@Colors}Colors then;');
  Add('  if {@Colors}Colors >= {@s}s then;');
  ParseProgram;
end;

procedure TTestResolver.TestEnumParams;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('function {#A1}FuncA: TFlag;');
  Add('begin');
  Add('  Result:=red;');
  Add('end;');
  Add('function {#A2}FuncA(f: TFlag): TFlag;');
  Add('begin');
  Add('  Result:=f;');
  Add('end;');
  Add('var');
  Add('  f: TFlag;');
  Add('begin');
  Add('  f:={@A1}FuncA;');
  Add('  f:={@A1}FuncA();');
  Add('  f:={@A2}FuncA(f);');
  ParseProgram;
end;

procedure TTestResolver.TestSetParams;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('  TFlags = set of TFlag;');
  Add('function {#A1}FuncA: TFlags;');
  Add('begin');
  Add('  Result:=[red];');
  Add('end;');
  Add('function {#A2}FuncA(f: TFlags): TFlags;');
  Add('begin');
  Add('  Result:=f;');
  Add('end;');
  Add('var');
  Add('  f: TFlags;');
  Add('begin');
  Add('  f:={@A1}FuncA;');
  Add('  f:={@A1}FuncA();');
  Add('  f:={@A2}FuncA(f);');
  Add('  f:={@A2}FuncA([green]);');
  ParseProgram;
end;

procedure TTestResolver.TestSetFunctions;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('  TFlags = set of TFlag;');
  Add('var');
  Add('  e: TFlag;');
  Add('  s: TFlags;');
  Add('begin');
  Add('  e:=Low(TFlags);');
  Add('  e:=Low(s);');
  Add('  e:=High(TFlags);');
  Add('  e:=High(s);');
  ParseProgram;
end;

procedure TTestResolver.TestEnumHighLow;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('var f: TFlag;');
  Add('begin');
  Add('  for f:=low(TFlag) to high(TFlag) do ;');
  ParseProgram;
end;

procedure TTestResolver.TestEnumOrd;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('var');
  Add('  f: TFlag;');
  Add('  i: longint;');
  Add('begin');
  Add('  i:=ord(f);');
  Add('  i:=ord(green);');
  Add('  if i=ord(f) then ;');
  Add('  if ord(f)=i then ;');
  ParseProgram;
end;

procedure TTestResolver.TestEnumPredSucc;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('var');
  Add('  f: TFlag;');
  Add('begin');
  Add('  f:=Pred(f);');
  Add('  if Pred(green)=Pred(TFlag.Blue) then;');
  Add('  f:=Succ(f);');
  Add('  if Succ(green)=Succ(TFlag.Blue) then;');
  ParseProgram;
end;

procedure TTestResolver.TestEnum_CastIntegerToEnum;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red, green, blue);');
  Add('var');
  Add('  f: TFlag;');
  Add('  i: longint;');
  Add('begin');
  Add('  f:=TFlag(1);');
  Add('  f:=TFlag({#a_read}i);');
  Add('  if TFlag({#b_read}i)=TFlag(1) then;');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestPrgAssignment;
var
  El: TPasElement;
  V1: TPasVariable;
  ImplAssign: TPasImplAssign;
  Ref1: TPrimitiveExpr;
  Resolver1: TResolvedReference;
begin
  StartProgram(false);
  Add('var');
  Add('  v1:longint;');
  Add('begin');
  Add('  v1:=3;');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('var',TPasVariable,El.ClassType);
  V1:=TPasVariable(El);
  AssertEquals('var v1','v1',V1.Name);

  AssertEquals('1 statement',1,PasProgram.InitializationSection.Elements.Count);
  AssertEquals('Assignment statement',TPasImplAssign,FFirstStatement.ClassType);
  ImplAssign:=FFirstStatement as TPasImplAssign;
  AssertEquals('Normal assignment',akDefault,ImplAssign.Kind);
  AssertExpression('Right side is constant',ImplAssign.Right,pekNumber,'3');
  AssertExpression('Left side is variable',ImplAssign.Left,pekIdent,'v1');
  AssertEquals('Left side is variable, primitive',TPrimitiveExpr,ImplAssign.Left.ClassType);
  Ref1:=TPrimitiveExpr(ImplAssign.Left);
  AssertNotNull('variable has customdata',Ref1.CustomData);
  AssertEquals('variable has resolver',TResolvedReference,Ref1.CustomData.ClassType);
  Resolver1:=TResolvedReference(Ref1.CustomData);
  AssertSame('variable resolver element',Resolver1.Element,Ref1);
  AssertSame('variable resolver declaration v1',Resolver1.Declaration,V1);
end;

procedure TTestResolver.TestPrgProcVar;
begin
  StartProgram(false);
  Add('procedure Proc1;');
  Add('type');
  Add('  t1=longint;');
  Add('var');
  Add('  v1:t1;');
  Add('begin');
  Add('end;');
  Add('begin');
  ParseProgram;
  AssertEquals('1 declaration',1,PasProgram.ProgramSection.Declarations.Count);
end;

procedure TTestResolver.TestUnitProcVar;
var
  El: TPasElement;
  IntfProc1, ImplProc1: TPasProcedure;
  IntfType1, ProcSubType1: TPasAliasType;
  ImplVar1, ProcSubVar1: TPasVariable;
  ImplVar1Type, ProcSubVar1Type: TPasType;
begin
  StartUnit(false);
  Add('interface');
  Add('');
  Add('type t1=string; // unit scope');
  Add('procedure Proc1;');
  Add('');
  Add('implementation');
  Add('');
  Add('procedure Proc1;');
  Add('type t1=longint; // local proc scope');
  Add('var  v1:t1; // using local t1');
  Add('begin');
  Add('end;');
  Add('var  v2:t1; // using interface t1');
  ParseUnit;

  // interface
  AssertEquals('2 intf declarations',2,Module.InterfaceSection.Declarations.Count);
  El:=TPasElement(Module.InterfaceSection.Declarations[0]);
  AssertEquals('intf type',TPasAliasType,El.ClassType);
  IntfType1:=TPasAliasType(El);
  AssertEquals('intf type t1','t1',IntfType1.Name);

  El:=TPasElement(Module.InterfaceSection.Declarations[1]);
  AssertEquals('intf proc',TPasProcedure,El.ClassType);
  IntfProc1:=TPasProcedure(El);
  AssertEquals('intf proc Proc1','Proc1',IntfProc1.Name);

  // implementation
  AssertEquals('2 impl declarations',2,Module.ImplementationSection.Declarations.Count);
  El:=TPasElement(Module.ImplementationSection.Declarations[0]);
  AssertEquals('impl proc',TPasProcedure,El.ClassType);
  ImplProc1:=TPasProcedure(El);
  AssertEquals('impl proc Proc1','Proc1',ImplProc1.Name);

  El:=TPasElement(Module.ImplementationSection.Declarations[1]);
  AssertEquals('impl var',TPasVariable,El.ClassType);
  ImplVar1:=TPasVariable(El);
  AssertEquals('impl var v2','v2',ImplVar1.Name);
  ImplVar1Type:=TPasType(ImplVar1.VarType);
  AssertSame('impl var type is intf t1',IntfType1,ImplVar1Type);

  // proc
  AssertEquals('2 proc sub declarations',2,ImplProc1.Body.Declarations.Count);

  // proc sub type t1
  El:=TPasElement(ImplProc1.Body.Declarations[0]);
  AssertEquals('proc sub type',TPasAliasType,El.ClassType);
  ProcSubType1:=TPasAliasType(El);
  AssertEquals('proc sub type t1','t1',ProcSubType1.Name);

  // proc sub var v1
  El:=TPasElement(ImplProc1.Body.Declarations[1]);
  AssertEquals('proc sub var',TPasVariable,El.ClassType);
  ProcSubVar1:=TPasVariable(El);
  AssertEquals('proc sub var v1','v1',ProcSubVar1.Name);
  ProcSubVar1Type:=TPasType(ProcSubVar1.VarType);
  AssertSame('proc sub var type is proc sub t1',ProcSubType1,ProcSubVar1Type);
end;

procedure TTestResolver.TestAssignIntegers;
begin
  StartProgram(false);
  Add('var');
  Add('  {#vbyte}vbyte:byte;');
  Add('  {#vshortint}vshortint:shortint;');
  Add('  {#vword}vword:word;');
  Add('  {#vsmallint}vsmallint:smallint;');
  Add('  {#vcardinal}vcardinal:cardinal;');
  Add('  {#vlongint}vlongint:longint;');
  Add('  {#vint64}vint64:int64;');
  Add('  {#vcomp}vcomp:comp;');
  Add('begin');
  Add('  {@vbyte}vbyte:=0;');
  Add('  {@vbyte}vbyte:=255;');
  Add('  {@vshortint}vshortint:=0;');
  Add('  {@vshortint}vshortint:=-128;');
  Add('  {@vshortint}vshortint:= 127;');
  Add('  {@vword}vword:=0;');
  Add('  {@vword}vword:=+$ffff;');
  Add('  {@vsmallint}vsmallint:=0;');
  Add('  {@vsmallint}vsmallint:=-$8000;');
  Add('  {@vsmallint}vsmallint:= $7fff;');
  Add('  {@vcardinal}vcardinal:=0;');
  Add('  {@vcardinal}vcardinal:=$ffffffff;');
  Add('  {@vlongint}vlongint:=0;');
  Add('  {@vlongint}vlongint:=-$80000000;');
  Add('  {@vlongint}vlongint:= $7fffffff;');
  Add('  {@vlongint}vlongint:={@vbyte}vbyte;');
  Add('  {@vlongint}vlongint:={@vshortint}vshortint;');
  Add('  {@vlongint}vlongint:={@vword}vword;');
  Add('  {@vlongint}vlongint:={@vsmallint}vsmallint;');
  Add('  {@vlongint}vlongint:={@vlongint}vlongint;');
  Add('  {@vcomp}vcomp:=0;');
  Add('  {@vcomp}vcomp:=$ffffffffffffffff;');
  Add('  {@vint64}vint64:=0;');
  Add('  {@vint64}vint64:=-$8000000000000000;');
  Add('  {@vint64}vint64:= $7fffffffffffffff;');
  ParseProgram;
end;

procedure TTestResolver.TestAssignString;
begin
  StartProgram(false);
  Add('var');
  Add('  vstring:string;');
  Add('  vchar:char;');
  Add('begin');
  Add('  vstring:='''';');
  Add('  vstring:=''abc'';');
  Add('  vstring:=''a'';');
  Add('  vchar:=''c'';');
  Add('  vchar:=vstring[1];');
  ParseProgram;
end;

procedure TTestResolver.TestAssignIntToStringFail;
begin
  StartProgram(false);
  Add('var');
  Add('  vstring:string;');
  Add('begin');
  Add('  vstring:=2;');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestAssignStringToIntFail;
begin
  StartProgram(false);
  Add('var');
  Add('  v:longint;');
  Add('begin');
  Add('  v:=''A'';');
  CheckResolverException('Incompatible types: got "String" expected "Longint"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestIntegerOperators;
begin
  StartProgram(false);
  Add('var');
  Add('  i,j,k:longint;');
  Add('begin');
  Add('  i:=1;');
  Add('  i:=1+2;');
  Add('  i:=1+2+3;');
  Add('  i:=1-2;');
  Add('  i:=j;');
  Add('  i:=j+1;');
  Add('  i:=-j+1;');
  Add('  i:=j+k;');
  Add('  i:=-j+k;');
  Add('  i:=j*k;');
  Add('  i:=j**k;');
  Add('  i:=j div k;');
  Add('  i:=j mod k;');
  Add('  i:=j shl k;');
  Add('  i:=j shr k;');
  Add('  i:=j and k;');
  Add('  i:=j or k;');
  Add('  i:=j and not k;');
  Add('  i:=(j+k) div 3;');
  Add('  if i=j then;');
  Add('  if i<>j then;');
  Add('  if i>j then;');
  Add('  if i>=j then;');
  Add('  if i<j then;');
  Add('  if i<=j then;');
  ParseProgram;
end;

procedure TTestResolver.TestBooleanOperators;
begin
  StartProgram(false);
  Add('var');
  Add('  i,j,k:boolean;');
  Add('begin');
  Add('  i:=false;');
  Add('  i:=true;');
  Add('  i:=j and k;');
  Add('  i:=j or k;');
  Add('  i:=j or not k;');
  Add('  i:=(not j) or k;');
  Add('  i:=j or false;');
  Add('  i:=j and true;');
  Add('  i:=j xor k;');
  Add('  i:=j=k;');
  Add('  i:=j<>k;');
  ParseProgram;
end;

procedure TTestResolver.TestStringOperators;
begin
  StartProgram(false);
  Add('var');
  Add('  i,j:string;');
  Add('  k:char;');
  Add('begin');
  Add('  i:='''';');
  Add('  i:=''''+'''';');
  Add('  i:=k+'''';');
  Add('  i:=''''+k;');
  Add('  i:=''a''+j;');
  Add('  i:=''abc''+j;');
  Add('  k:=j;');
  Add('  k:=''a'';');
  ParseProgram;
end;

procedure TTestResolver.TestFloatOperators;
begin
  StartProgram(false);
  Add('var');
  Add('  i,j,k:double;');
  Add('begin');
  Add('  i:=1;');
  Add('  i:=1+2;');
  Add('  i:=1+2+3;');
  Add('  i:=1-2;');
  Add('  i:=j;');
  Add('  i:=j+1;');
  Add('  i:=-j+1;');
  Add('  i:=j+k;');
  Add('  i:=-j+k;');
  Add('  i:=j*k;');
  Add('  i:=j/k;');
  Add('  i:=j**k;');
  Add('  i:=(j+k)/3;');
  ParseProgram;
end;

procedure TTestResolver.TestCAssignments;
begin
  StartProgram(false);
  Parser.Options:=Parser.Options+[po_cassignments];
  Scanner.Options:=Scanner.Options+[po_cassignments];
  Add('Type');
  Add('  TFlag = (Flag1,Flag2);');
  Add('  TFlags = set of TFlag;');
  Add('var');
  Add('  i: longint;');
  Add('  c: char;');
  Add('  s: string;');
  Add('  d: double;');
  Add('  f: TFlag;');
  Add('  fs: TFlags;');
  Add('begin');
  Add('  i+=1;');
  Add('  i-=2;');
  Add('  i*=3;');
  Add('  s+=''A'';');
  Add('  s:=c;');
  Add('  d+=4;');
  Add('  d-=5;');
  Add('  d*=6;');
  Add('  d/=7;');
  Add('  d+=8.5;');
  Add('  d-=9.5;');
  Add('  d*=10.5;');
  Add('  d/=11.5;');
  Add('  fs+=[f];');
  Add('  fs-=[f];');
  Add('  fs*=[f];');
  Add('  fs+=[Flag1];');
  Add('  fs-=[Flag1];');
  Add('  fs*=[Flag1];');
  Add('  fs+=[Flag1,Flag2];');
  Add('  fs-=[Flag1,Flag2];');
  Add('  fs*=[Flag1,Flag2];');
  ParseProgram;
end;

procedure TTestResolver.TestTypeCastBaseTypes;
begin
  StartProgram(false);
  Add('var');
  Add('  si: smallint;');
  Add('  i: longint;');
  Add('  fs: single;');
  Add('  d: double;');
  Add('  b: boolean;');
  Add('begin');
  Add('  d:=double({#a_read}i);');
  Add('  i:=shortint({#b_read}i);');
  Add('  i:=longint({#c_read}si);');
  Add('  d:=double({#d_read}d);');
  Add('  fs:=single({#e_read}d);');
  Add('  d:=single({#f_read}d);');
  Add('  b:=longbool({#g_read}b);');
  Add('  b:=bytebool({#i_read}longbool({#h_read}b));');
  Add('  d:=double({#j_read}i)/2.5;');
  Add('  b:=boolean({#k_read}i);');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestTypeCastStrToIntFail;
begin
  StartProgram(false);
  Add('var');
  Add('  s: string;');
  Add('  i: longint;');
  Add('begin');
  Add('  i:=longint(s);');
  CheckResolverException('illegal type conversion: string to longint',PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestTypeCastIntToStrFail;
begin
  StartProgram(false);
  Add('var');
  Add('  s: string;');
  Add('  i: longint;');
  Add('begin');
  Add('  s:=string(i);');
  CheckResolverException('illegal type conversion: longint to string',PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestTypeCastDoubleToStrFail;
begin
  StartProgram(false);
  Add('var');
  Add('  s: string;');
  Add('  d: double;');
  Add('begin');
  Add('  s:=string(d);');
  CheckResolverException('illegal type conversion: double to string',PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestTypeCastDoubleToIntFail;
begin
  StartProgram(false);
  Add('var');
  Add('  i: longint;');
  Add('  d: double;');
  Add('begin');
  Add('  i:=longint(d);');
  CheckResolverException('illegal type conversion: double to longint',PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestHighLow;
begin
  StartProgram(false);
  Add('var');
  Add('  bo: boolean;');
  Add('  by: byte;');
  Add('  ch: char;');
  Add('begin');
  Add('  for bo:=low(boolean) to high(boolean) do;');
  Add('  for by:=low(byte) to high(byte) do;');
  Add('  for ch:=low(char) to high(char) do;');
  ParseProgram;
end;

procedure TTestResolver.TestAssign_Access;
begin
  StartProgram(false);
  Parser.Options:=Parser.Options+[po_cassignments];
  Scanner.Options:=Scanner.Options+[po_cassignments];
  Add('var i: longint;');
  Add('begin');
  Add('  {#a1_assign}i:={#a2_read}i;');
  Add('  {#b1_readandassign}i+={#b2_read}i;');
  Add('  {#c1_readandassign}i-={#c2_read}i;');
  Add('  {#d1_readandassign}i*={#d2_read}i;');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestForLoop;
begin
  StartProgram(false);
  Add('var');
  Add('  {#v1}v1,{#v2}v2,{#v3}v3:longint;');
  Add('begin');
  Add('  for {@v1}v1:=');
  Add('    {@v2}v2');
  Add('    to {@v3}v3 do ;');
  ParseProgram;
end;

procedure TTestResolver.TestStatements;
begin
  StartProgram(false);
  Add('var');
  Add('  v1,v2,v3:longint;');
  Add('begin');
  Add('  v1:=1;');
  Add('  v2:=v1+v1*v1+v1 div v1;');
  Add('  v3:=-v1;');
  Add('  repeat');
  Add('    v1:=v1+1;');
  Add('  until v1>=5;');
  Add('  while v1>=0 do');
  Add('    v1:=v1-v2;');
  Add('  for v1:=v2 to v3 do v2:=v1;');
  Add('  if v1<v2 then v3:=v1 else v3:=v2;');
  ParseProgram;
  AssertEquals('3 declarations',3,PasProgram.ProgramSection.Declarations.Count);
end;

procedure TTestResolver.TestCaseStatement;
begin
  StartProgram(false);
  Add('const');
  Add('  {#c1}c1=1;');
  Add('  {#c2}c2=1;');
  Add('var');
  Add('  {#v1}v1,{#v2}v2,{#v3}v3:longint;');
  Add('begin');
  Add('  Case {@v1}v1+{@v2}v2 of');
  Add('  {@c1}c1:');
  Add('    {@v2}v2:={@v3}v3;');
  Add('  {@c1}c1,{@c2}c2: ;');
  Add('  {@c1}c1..{@c2}c2: ;');
  Add('  {@c1}c1+{@c2}c2: ;');
  Add('  else');
  Add('    {@v1}v1:=3;');
  Add('  end;');
  ParseProgram;
end;

procedure TTestResolver.TestTryStatement;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('  {#Exec}Exception = class end;');
  Add('var');
  Add('  {#v1}v1,{#e1}e:longint;');
  Add('begin');
  Add('  try');
  Add('    {@v1}v1:={@e1}e;');
  Add('  finally');
  Add('    {@v1}v1:={@e1}e;');
  Add('  end');
  Add('  try');
  Add('    {@v1}v1:={@e1}e;');
  Add('  except');
  Add('    {@v1}v1:={@e1}e;');
  Add('    raise;');
  Add('  end');
  Add('  try');
  Add('    {@v1}v1:={@e1}e;');
  Add('  except');
  Add('    on {#e2}{=Exec}E: Exception do');
  Add('      if {@e2}e=nil then raise;');
  Add('    on {#e3}{=Exec}E: Exception do');
  Add('      raise {@e3}e;');
  Add('    else');
  Add('      {@v1}v1:={@e1}e;');
  Add('  end');
  ParseProgram;
end;

procedure TTestResolver.TestTryExceptOnNonTypeFail;
begin
  StartProgram(false);
  Add('type TObject = class end;');
  Add('var E: TObject;');
  Add('begin');
  Add('  try');
  Add('  except');
  Add('    on E do ;');
  Add('  end;');
  CheckParserException('Expected type, but got variable',PParser.nParserExpectedTypeButGot);
end;

procedure TTestResolver.TestTryExceptOnNonClassFail;
begin
  StartProgram(false);
  Add('begin');
  Add('  try');
  Add('  except');
  Add('    on longint do ;');
  Add('  end;');
  CheckResolverException('class expected but longint found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestRaiseNonVarFail;
begin
  StartProgram(false);
  Add('type TObject = class end;');
  Add('begin');
  Add('  raise TObject;');
  CheckResolverException('var expected but type found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestRaiseNonClassFail;
begin
  StartProgram(false);
  Add('var');
  Add('  E: longint;');
  Add('begin');
  Add('  raise E;');
  CheckResolverException('class expected but longint found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestRaiseDescendant;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  ActualNewInstance: Boolean;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor Create(Msg: string); external name ''ext'';');
  Add('  end;');
  Add('  Exception = class end;');
  Add('  EConvertError = class(Exception) end;');
  Add('begin');
  Add('  raise Exception.{#a}Create(''foo'');');
  Add('  raise EConvertError.{#b}Create(''bar'');');
  ParseProgram;
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestRaiseDescendant ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualNewInstance:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestRaiseDescendant ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if not (Ref.Declaration is TPasProcedure) then continue;
        //writeln('TTestResolver.TestRaiseDescendant ',GetObjName(Ref.Declaration),' rrfNewInstance=',rrfNewInstance in Ref.Flags);
        if (Ref.Declaration is TPasConstructor) then
          ActualNewInstance:=rrfNewInstance in Ref.Flags;
        break;
        end;
      if not ActualNewInstance then
        RaiseErrorAtSrcMarker('expected newinstance at "#'+aMarker^.Identifier+', but got normal call"',aMarker);
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestStatementsRefs;
begin
  StartProgram(false);
  Add('var');
  Add('  {#v1}v1,{#v2}v2,{#v3}v3:longint;');
  Add('begin');
  Add('  {@v1}v1:=1;');
  Add('  {@v2}v2:=');
  Add('    {@v1}v1+');
  Add('    {@v1}v1*{@v1}v1');
  Add('    +{@v1}v1 div {@v1}v1;');
  Add('  {@v3}v3:=');
  Add('    -{@v1}v1;');
  Add('  repeat');
  Add('    {@v1}v1:=');
  Add('      {@v1}v1+1;');
  Add('  until {@v1}v1>=5;');
  Add('  while {@v1}v1>=0 do');
  Add('    {@v1}v1');
  Add('    :={@v1}v1-{@v2}v2;');
  Add('  if {@v1}v1<{@v2}v2 then');
  Add('    {@v3}v3:={@v1}v1');
  Add('  else {@v3}v3:=');
  Add('    {@v2}v2;');
  ParseProgram;
  AssertEquals('3 declarations',3,PasProgram.ProgramSection.Declarations.Count);
end;

procedure TTestResolver.TestRepeatUntilNonBoolFail;
begin
  StartProgram(false);
  Add('begin');
  Add('  repeat');
  Add('  until 3;');
  CheckResolverException('boolean expected but longint found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestWhileDoNonBoolFail;
begin
  StartProgram(false);
  Add('begin');
  Add('  while 3 do ;');
  CheckResolverException('boolean expected but longint found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestIfThenNonBoolFail;
begin
  StartProgram(false);
  Add('begin');
  Add('  if 3 then ;');
  CheckResolverException('boolean expected but longint found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestForLoopVarNonVarFail;
begin
  StartProgram(false);
  Add('const i = 3;');
  Add('begin');
  Add('  for i:=1 to 2 do ;');
  CheckResolverException('variable identifier expected',nVariableIdentifierExpected);
end;

procedure TTestResolver.TestForLoopStartIncompFail;
begin
  StartProgram(false);
  Add('var i: char;');
  Add('begin');
  Add('  for i:=1 to 2 do ;');
  CheckResolverException('Incompatible types: got "Longint" expected "Char"',
    nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestForLoopEndIncompFail;
begin
  StartProgram(false);
  Add('var i: longint;');
  Add('begin');
  Add('  for i:=1 to ''2'' do ;');
  CheckResolverException('Incompatible types: got "Char" expected "Longint"',
    nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestCaseOf;
begin
  StartProgram(false);
  Add('type');
  Add('  TFlag = (red,green,blue);');
  Add('var');
  Add('  i: longint;');
  Add('  f: TFlag;');
  Add('  b: boolean;');
  Add('  c: char;');
  Add('  s: string;');
  Add('begin');
  Add('  case i of');
  Add('  1: ;');
  Add('  2..3: ;');
  Add('  4,5..6,7: ;');
  Add('  else');
  Add('  end;');
  Add('  case f of');
  Add('  red: ;');
  Add('  red..green: ;');
  Add('  end;');
  Add('  case b of');
  Add('  true: ;');
  Add('  false: ;');
  Add('  end;');
  Add('  case c of');
  Add('  #0: ;');
  Add('  #10,#13: ;');
  Add('  ''0''..''9'',''a''..''z'': ;');
  Add('  end;');
  Add('  case s of');
  Add('  #10: ;');
  Add('  ''abc'': ;');
  Add('  end;');
  ParseProgram;
end;

procedure TTestResolver.TestCaseExprNonOrdFail;
begin
  StartProgram(false);
  Add('begin');
  Add('  case longint of');
  Add('  1: ;');
  Add('  end;');
  CheckResolverException('const expression expected, but Longint found',
    nXExpectedButYFound);
end;

procedure TTestResolver.TestCaseIncompatibleValueFail;
begin
  StartProgram(false);
  Add('var i: longint;');
  Add('begin');
  Add('  case i of');
  Add('  ''1'': ;');
  Add('  end;');
  CheckResolverException('Incompatible types: got "Longint" expected "Char"',
    nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestSimpleStatement_VarFail;
begin
  StartProgram(false);
  Add('var i: longint;');
  Add('begin');
  Add('  i;');
  CheckResolverException('Illegal expression',nIllegalExpression);
end;

procedure TTestResolver.TestUnitOverloads;
begin
  StartUnit(false);
  Add('interface');
  Add('procedure {#ADecl}DoIt(vI: longint);');
  Add('procedure {#BDecl}DoIt(vI, vJ: longint);');
  Add('implementation');
  Add('procedure {#EDecl}DoIt(vI, vJ, vK, vL, vM: longint); forward;');
  Add('procedure {#C}DoIt(vI, vJ, vK: longint); begin end;');
  Add('procedure {#AImpl}DoIt(vi: longint); begin end;');
  Add('procedure {#D}DoIt(vI, vJ, vK, vL: longint); begin end;');
  Add('procedure {#BImpl}DoIt(vi, vj: longint); begin end;');
  Add('procedure {#EImpl}DoIt(vi, vj, vk, vl, vm: longint); begin end;');
  Add('begin');
  Add('  {@ADecl}DoIt(1);');
  Add('  {@BDecl}DoIt(2,3);');
  Add('  {@C}DoIt(4,5,6);');
  Add('  {@D}DoIt(7,8,9,10);');
  Add('  {@EDecl}DoIt(11,12,13,14,15);');
  ParseUnit;
end;

procedure TTestResolver.TestUnitIntfInitalization;
var
  El, DeclEl, OtherUnit: TPasElement;
  LocalVar: TPasVariable;
  Assign1, Assign2, Assign3: TPasImplAssign;
  Prim1, Prim2: TPrimitiveExpr;
  BinExp: TBinaryExpr;
begin
  StartUnit(true);
  Add('interface');
  Add('var exitCOde: string;');
  Add('implementation');
  Add('initialization');
  Add('  ExitcodE:=''1'';');
  Add('  afile.eXitCode:=''2'';');
  Add('  System.exiTCode:=3;');
  ParseUnit;

  // interface
  AssertEquals('1 intf declaration',1,Module.InterfaceSection.Declarations.Count);
  El:=TPasElement(Module.InterfaceSection.Declarations[0]);
  AssertEquals('local var',TPasVariable,El.ClassType);
  LocalVar:=TPasVariable(El);
  AssertEquals('local var exitcode','exitCOde',LocalVar.Name);

  // initialization
  AssertEquals('3 initialization statements',3,Module.InitializationSection.Elements.Count);

  // check direct assignment to local var
  El:=TPasElement(Module.InitializationSection.Elements[0]);
  AssertEquals('direct assign',TPasImplAssign,El.ClassType);
  Assign1:=TPasImplAssign(El);
  AssertEquals('direct assign left',TPrimitiveExpr,Assign1.left.ClassType);
  Prim1:=TPrimitiveExpr(Assign1.left);
  AssertNotNull(Prim1.CustomData);
  AssertEquals('direct assign left ref',TResolvedReference,Prim1.CustomData.ClassType);
  DeclEl:=TResolvedReference(Prim1.CustomData).Declaration;
  AssertSame('direct assign local var',LocalVar,DeclEl);

  // check indirect assignment to local var: "afile.eXitCode"
  El:=TPasElement(Module.InitializationSection.Elements[1]);
  AssertEquals('indirect assign',TPasImplAssign,El.ClassType);
  Assign2:=TPasImplAssign(El);
  AssertEquals('indirect assign left',TBinaryExpr,Assign2.left.ClassType);
  BinExp:=TBinaryExpr(Assign2.left);
  AssertEquals('indirect assign first token',TPrimitiveExpr,BinExp.left.ClassType);
  Prim1:=TPrimitiveExpr(BinExp.left);
  AssertEquals('indirect assign first token','afile',Prim1.Value);
  AssertNotNull(Prim1.CustomData);
  AssertEquals('indirect assign unit ref resolved',TResolvedReference,Prim1.CustomData.ClassType);
  DeclEl:=TResolvedReference(Prim1.CustomData).Declaration;
  AssertSame('indirect assign unit ref',Module,DeclEl);

  AssertEquals('indirect assign dot',eopSubIdent,BinExp.OpCode);

  AssertEquals('indirect assign second token',TPrimitiveExpr,BinExp.right.ClassType);
  Prim2:=TPrimitiveExpr(BinExp.right);
  AssertEquals('indirect assign second token','eXitCode',Prim2.Value);
  AssertNotNull(Prim2.CustomData);
  AssertEquals('indirect assign var ref resolved',TResolvedReference,Prim2.CustomData.ClassType);
  AssertEquals('indirect assign left ref',TResolvedReference,Prim2.CustomData.ClassType);
  DeclEl:=TResolvedReference(Prim2.CustomData).Declaration;
  AssertSame('indirect assign local var',LocalVar,DeclEl);

  // check assignment to "system.ExitCode"
  El:=TPasElement(Module.InitializationSection.Elements[2]);
  AssertEquals('other unit assign',TPasImplAssign,El.ClassType);
  Assign3:=TPasImplAssign(El);
  AssertEquals('other unit assign left',TBinaryExpr,Assign3.left.ClassType);
  BinExp:=TBinaryExpr(Assign3.left);
  AssertEquals('othe unit assign first token',TPrimitiveExpr,BinExp.left.ClassType);
  Prim1:=TPrimitiveExpr(BinExp.left);
  AssertEquals('other unit assign first token','System',Prim1.Value);
  AssertNotNull(Prim1.CustomData);
  AssertEquals('other unit assign unit ref resolved',TResolvedReference,Prim1.CustomData.ClassType);
  DeclEl:=TResolvedReference(Prim1.CustomData).Declaration;
  OtherUnit:=DeclEl;
  AssertEquals('other unit assign unit ref',TPasModule,DeclEl.ClassType);
  AssertEquals('other unit assign unit ref system','system',lowercase(DeclEl.Name));

  AssertEquals('other unit assign dot',eopSubIdent,BinExp.OpCode);

  AssertEquals('other unit assign second token',TPrimitiveExpr,BinExp.right.ClassType);
  Prim2:=TPrimitiveExpr(BinExp.right);
  AssertEquals('other unit assign second token','exiTCode',Prim2.Value);
  AssertNotNull(Prim2.CustomData);
  AssertEquals('other unit assign var ref resolved',TResolvedReference,Prim2.CustomData.ClassType);
  AssertEquals('other unit assign left ref',TResolvedReference,Prim2.CustomData.ClassType);
  DeclEl:=TResolvedReference(Prim2.CustomData).Declaration;
  AssertEquals('other unit assign var',TPasVariable,DeclEl.ClassType);
  AssertEquals('other unit assign var exitcode','exitcode',lowercase(DeclEl.Name));
  AssertSame('other unit assign var exitcode',OtherUnit,DeclEl.GetModule);
end;

procedure TTestResolver.TestUnitUseIntf;
begin
  AddModuleWithIntfImplSrc('unit2.pp',
    LinesToStr([
    'var i: longint;',
    'procedure DoIt;',
    '']),
    LinesToStr([
    'procedure DoIt; begin end;']));

  StartProgram(true);
  Add('uses unit2;');
  Add('begin');
  Add('  if i=2 then');
  Add('    DoIt;');
  ParseProgram;
end;

procedure TTestResolver.TestUnitUseImplFail;
begin
  AddModuleWithIntfImplSrc('unit2.pp',
    LinesToStr([
    '']),
    LinesToStr([
    'procedure DoIt; begin end;']));

  StartProgram(true);
  Add('uses unit2;');
  Add('begin');
  Add('  DoIt;');
  CheckResolverException('identifier not found "DoIt"',nIdentifierNotFound);
end;

procedure TTestResolver.TestProcParam;
begin
  StartProgram(false);
  Add('procedure Proc1(a: longint);');
  Add('begin');
  Add('  a:=3;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestProcParamAccess;
begin
  StartProgram(false);
  Add('procedure DoIt(vI: longint; const vJ: longint; var vK: longint);');
  Add('var vL: longint;');
  Add('begin');
  Add('  vi:=vi+1;');
  Add('  vl:=vj+1;');
  Add('  vk:=vk+1;');
  Add('  vl:=vl+1;');
  Add('  DoIt(vi,vi,vi);');
  Add('  DoIt(vj,vj,vl);');
  Add('  DoIt(vk,vk,vk);');
  Add('  DoIt(vl,vl,vl);');
  Add('end;');
  Add('var i: longint;');
  Add('begin');
  Add('  DoIt(i,i,i);');
  ParseProgram;
end;

procedure TTestResolver.TestFunctionResult;
begin
  StartProgram(false);
  Add('function Func1: longint;');
  Add('begin');
  Add('  Result:=3;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestProcOverload;
var
  El: TPasElement;
begin
  StartProgram(false);
  Add('function Func1(i: longint; j: longint = 0): longint; overload;');
  Add('begin');
  Add('  Result:=1;');
  Add('end;');
  Add('function Func1(s: string): longint; overload;');
  Add('begin');
  Add('  Result:=2;');
  Add('end;');
  Add('begin');
  Add('  Func1(3);');
  ParseProgram;
  AssertEquals('2 declarations',2,PasProgram.ProgramSection.Declarations.Count);

  El:=TPasElement(PasProgram.ProgramSection.Declarations[0]);
  AssertEquals('is function',TPasFunction,El.ClassType);

  AssertEquals('1 statement',1,PasProgram.InitializationSection.Elements.Count);
end;

procedure TTestResolver.TestProcOverloadWithBaseTypes;
begin
  StartProgram(false);
  Add('function {#A}Func1(i: longint; j: longint = 0): longint; overload;');
  Add('begin');
  Add('  Result:=1;');
  Add('end;');
  Add('function {#B}Func1(s: string): longint; overload;');
  Add('begin');
  Add('  Result:=2;');
  Add('end;');
  Add('begin');
  Add('  {@A}Func1(3);');
  ParseProgram;
end;

procedure TTestResolver.TestProcOverloadWithClassTypes;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class end;');
  Add('  {#TA}TClassA = class end;');
  Add('  {#TB}TClassB = class end;');
  Add('procedure {#DoA}DoIt({=TA}p: TClassA); overload;');
  Add('begin');
  Add('end;');
  Add('procedure {#DoB}DoIt({=TB}p: TClassB); overload;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#A}{=TA}A: TClassA;');
  Add('  {#B}{=TB}B: TClassB;');
  Add('begin');
  Add('  {@DoA}DoIt({@A}A)');
  Add('  {@DoB}DoIt({@B}B)');
  ParseProgram;
end;

procedure TTestResolver.TestProcOverloadWithInhClassTypes;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class end;');
  Add('  {#TA}TClassA = class end;');
  Add('  {#TB}TClassB = class(TClassA) end;');
  Add('  {#TC}TClassC = class(TClassB) end;');
  Add('procedure {#DoA}DoIt({=TA}p: TClassA); overload;');
  Add('begin');
  Add('end;');
  Add('procedure {#DoB}DoIt({=TB}p: TClassB); overload;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#A}{=TA}A: TClassA;');
  Add('  {#B}{=TB}B: TClassB;');
  Add('  {#C}{=TC}C: TClassC;');
  Add('begin');
  Add('  {@DoA}DoIt({@A}A)');
  Add('  {@DoB}DoIt({@B}B)');
  Add('  {@DoB}DoIt({@C}C)');
  ParseProgram;
end;

procedure TTestResolver.TestProcOverloadWithInhAliasClassTypes;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class end;');
  Add('  {#TA}TClassA = class end;');
  Add('  {#TB}{=TA}TClassB = TClassA;');
  Add('  {#TC}TClassC = class(TClassB) end;');
  Add('procedure {#DoA}DoIt({=TA}p: TClassA); overload;');
  Add('begin');
  Add('end;');
  Add('procedure {#DoC}DoIt({=TC}p: TClassC); overload;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#A}{=TA}A: TClassA;');
  Add('  {#B}{=TB}B: TClassB;');
  Add('  {#C}{=TC}C: TClassC;');
  Add('begin');
  Add('  {@DoA}DoIt({@A}A)');
  Add('  {@DoA}DoIt({@B}B)');
  Add('  {@DoC}DoIt({@C}C)');
  ParseProgram;
end;

procedure TTestResolver.TestProcDuplicate;
begin
  StartProgram(false);
  Add('procedure ProcA(i: longint);');
  Add('begin');
  Add('end;');
  Add('procedure ProcA(i: longint);');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('duplicate identifier',PasResolver.nDuplicateIdentifier);
end;

procedure TTestResolver.TestNestedProc;
begin
  StartProgram(false);
  Add('function DoIt({#a1}a,{#d1}d: longint): longint;');
  Add('var');
  Add('  {#b1}b: longint;');
  Add('  {#c1}c: longint;');
  Add('  function {#Nesty1}Nesty({#a2}a: longint): longint; ');
  Add('  var {#b2}b: longint;');
  Add('  begin');
  Add('    Result:={@a2}a');
  Add('      +{@b2}b');
  Add('      +{@c1}c');
  Add('      +{@d1}d;');
  Add('  end;');
  Add('begin');
  Add('  Result:={@a1}a');
  Add('      +{@b1}b');
  Add('      +{@c1}c;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestForwardProc;
begin
  StartProgram(false);
  Add('procedure {#A_forward}FuncA(i: longint); forward;');
  Add('procedure {#B}FuncB(i: longint);');
  Add('begin');
  Add('  {@A_forward}FuncA(i);');
  Add('end;');
  Add('procedure {#A}FuncA(i: longint);');
  Add('begin');
  Add('end;');
  Add('begin');
  Add('  {@A_forward}FuncA(3);');
  Add('  {@B}FuncB(3);');
  ParseProgram;
end;

procedure TTestResolver.TestForwardProcUnresolved;
begin
  StartProgram(false);
  Add('procedure FuncA(i: longint); forward;');
  Add('begin');
  CheckResolverException('forward proc not resolved',PasResolver.nForwardProcNotResolved);
end;

procedure TTestResolver.TestNestedForwardProc;
begin
  StartProgram(false);
  Add('procedure {#A}FuncA;');
  Add('  procedure {#B_forward}ProcB(i: longint); forward;');
  Add('  procedure {#C}ProcC(i: longint);');
  Add('  begin');
  Add('    {@B_forward}ProcB(i);');
  Add('  end;');
  Add('  procedure {#B}ProcB(i: longint);');
  Add('  begin');
  Add('  end;');
  Add('begin');
  Add('  {@B_forward}ProcB(3);');
  Add('  {@C}ProcC(3);');
  Add('end;');
  Add('begin');
  Add('  {@A}FuncA;');
  ParseProgram;
end;

procedure TTestResolver.TestNestedForwardProcUnresolved;
begin
  StartProgram(false);
  Add('procedure FuncA;');
  Add('  procedure ProcB(i: longint); forward;');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('forward proc not resolved',PasResolver.nForwardProcNotResolved);
end;

procedure TTestResolver.TestForwardProcFuncMismatch;
begin
  StartProgram(false);
  Add('procedure DoIt; forward;');
  Add('function DoIt: longint;');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('procedure expected, but function found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestForwardFuncResultMismatch;
begin
  StartProgram(false);
  Add('function DoIt: longint; forward;');
  Add('function DoIt: string;');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('Result type mismatch',PasResolver.nResultTypeMismatchExpectedButFound);
end;

procedure TTestResolver.TestUnitIntfProc;
begin
  StartUnit(false);
  Add('interface');
  Add('procedure {#A_forward}FuncA({#Bar}Bar: longint);');
  Add('implementation');
  Add('procedure {#A}FuncA(bar: longint);');
  Add('begin');
  Add('  if {@Bar}bar=3 then ;');
  Add('end;');
  Add('initialization');
  Add('  {@A_forward}FuncA(3);');
  ParseUnit;
end;

procedure TTestResolver.TestUnitIntfProcUnresolved;
begin
  StartUnit(false);
  Add('interface');
  Add('procedure {#A_forward}FuncA(i: longint);');
  Add('implementation');
  Add('initialization');
  CheckResolverException('forward proc not resolved',PasResolver.nForwardProcNotResolved);
end;

procedure TTestResolver.TestUnitIntfMismatchArgName;
begin
  StartUnit(false);
  Add('interface');
  Add('procedure {#A_forward}ProcA(i: longint);');
  Add('implementation');
  Add('procedure {#A}ProcA(j: longint);');
  Add('begin');
  Add('end;');
  CheckResolverException('function header "ProcA" doesn''t match forward : var name changes',
    PasResolver.nFunctionHeaderMismatchForwardVarName);
end;

procedure TTestResolver.TestProcOverloadIsNotFunc;
begin
  StartUnit(false);
  Add('interface');
  Add('var ProcA: longint;');
  Add('procedure {#A_Decl}ProcA(i: longint);');
  Add('implementation');
  Add('procedure {#A_Impl}ProcA(i: longint);');
  Add('begin');
  Add('end;');
  CheckResolverException('Duplicate identifier',PasResolver.nDuplicateIdentifier);
end;

procedure TTestResolver.TestProcCallMissingParams;
begin
  StartProgram(false);
  Add('procedure Proc1(a: longint);');
  Add('begin');
  Add('end;');
  Add('begin');
  Add('  Proc1;');
  CheckResolverException('Wrong number of parameters for call to "Proc1"',
    PasResolver.nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestProcArgDefaultValueTypeMismatch;
begin
  StartProgram(false);
  Add('procedure Proc1(a: string = 3);');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestProcPassConstToVar;
begin
  StartProgram(false);
  Add('procedure DoSome(var i: longint); begin end;');
  Add('procedure DoIt(const i: longint);');
  Add('begin');
  Add('  DoSome(i);');
  Add('end;');
  Add('begin');
  CheckResolverException('Variable identifier expected',
    PasResolver.nVariableIdentifierExpected);
end;

procedure TTestResolver.TestBuiltInProcCallMissingParams;
begin
  StartProgram(false);
  Add('begin');
  Add('  length;');
  CheckResolverException('Wrong number of parameters for call to "length"',
    PasResolver.nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestAssignFunctionResult;
begin
  StartProgram(false);
  Add('function {#F1}F1: longint;');
  Add('begin');
  Add('end;');
  Add('function {#F2}F2: longint;');
  Add('begin');
  Add('end;');
  Add('var {#i}i: longint;');
  Add('begin');
  Add('  {@i}i:={@F1}F1();');
  Add('  {@i}i:={@F1}F1()+{@F2}F2();');
  Add('  {@i}i:={@F1}F1;');
  Add('  {@i}i:={@F1}F1+{@F2}F2;');
  ParseProgram;
end;

procedure TTestResolver.TestAssignProcResultFail;
begin
  StartProgram(false);
  Add('procedure {#P}P;');
  Add('begin');
  Add('end;');
  Add('var {#i}i: longint;');
  Add('begin');
  Add('  {@i}i:={@P}P();');
  CheckResolverException('{Incompatible types: got "Procedure/Function" expected "Longint"',PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestFunctionResultInCondition;
begin
  StartProgram(false);
  Add('function {#F1}F1: longint;');
  Add('begin');
  Add('end;');
  Add('function {#F2}F2: boolean;');
  Add('begin');
  Add('end;');
  Add('var {#i}i: longint;');
  Add('begin');
  Add('  if {@F2}F2 then ;');
  Add('  if {@i}i={@F1}F1() then ;');
  ParseProgram;
end;

procedure TTestResolver.TestExit;
begin
  StartProgram(false);
  Add('procedure ProcA;');
  Add('begin');
  Add('  exit;');
  Add('end;');
  Add('function FuncB: longint;');
  Add('begin');
  Add('  exit;');
  Add('  exit(3);');
  Add('end;');
  Add('function FuncC: string;');
  Add('begin');
  Add('  exit;');
  Add('  exit(''a'');');
  Add('  exit(''abc'');');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestBreak;
begin
  StartProgram(false);
  Add('var i: longint;');
  Add('begin');
  Add('  repeat');
  Add('    break;');
  Add('  until false;');
  Add('  while true do');
  Add('    break;');
  Add('  for i:=0 to 1 do');
  Add('    break;');
  ParseProgram;
end;

procedure TTestResolver.TestContinue;
begin
  StartProgram(false);
  Add('var i: longint;');
  Add('begin');
  Add('  repeat');
  Add('    continue;');
  Add('  until false;');
  Add('  while true do');
  Add('    continue;');
  Add('  for i:=0 to 1 do');
  Add('    continue;');
  ParseProgram;
end;

procedure TTestResolver.TestProcedureExternal;
begin
  StartProgram(false);
  Add('procedure {#ProcA}ProcA; external ''ExtProcA'';');
  Add('function {#FuncB}FuncB: longint; external ''ExtFuncB'';');
  Add('function {#FuncC}FuncC(d: double): string; external ''ExtFuncC'';');
  Add('var');
  Add('  i: longint;');
  Add('  s: string;');
  Add('begin');
  Add('  {@ProcA}ProcA;');
  Add('  i:={@FuncB}FuncB;');
  Add('  i:={@FuncB}FuncB();');
  Add('  s:={@FuncC}FuncC(1.2);');
  ParseProgram;
end;

procedure TTestResolver.TestProc_UntypedParam_Forward;
begin
  StartProgram(false);
  Add('procedure {#ProcA}ProcA(var {#A}A); forward;');
  Add('procedure {#ProcB}ProcB(const {#B}B); forward;');
  Add('procedure {#ProcC}ProcC(out {#C}C); forward;');
  Add('procedure {#ProcD}ProcD(constref {#D}D); forward;');
  Add('procedure ProcA(var A);');
  Add('begin');
  Add('end;');
  Add('procedure ProcB(const B);');
  Add('begin');
  Add('end;');
  Add('procedure ProcC(out C);');
  Add('begin');
  Add('end;');
  Add('procedure ProcD(constref D);');
  Add('begin');
  Add('end;');
  Add('var i: longint;');
  Add('begin');
  Add('  {@ProcA}ProcA(i);');
  Add('  {@ProcB}ProcB(i);');
  Add('  {@ProcC}ProcC(i);');
  Add('  {@ProcD}ProcD(i);');
  ParseProgram;
end;

procedure TTestResolver.TestProc_Varargs;
begin
  StartProgram(false);
  Add('procedure ProcA(i:longint); varargs; external;');
  Add('procedure ProcB; varargs; external;');
  Add('procedure ProcC(i: longint = 17); varargs; external;');
  Add('begin');
  Add('  ProcA(1);');
  Add('  ProcA(1,2);');
  Add('  ProcA(1,2.0);');
  Add('  ProcA(1,2,3);');
  Add('  ProcA(1,''2'');');
  Add('  ProcA(2,'''');');
  Add('  ProcA(3,false);');
  Add('  ProcB;');
  Add('  ProcB();');
  Add('  ProcB(4);');
  Add('  ProcB(''foo'');');
  Add('  ProcC;');
  Add('  ProcC();');
  Add('  ProcC(4);');
  Add('  ProcC(5,''foo'');');
  ParseProgram;
end;

procedure TTestResolver.TestProc_ParameterExprAccess;
begin
  StartProgram(false);
  Add('type');
  Add('  TRec = record');
  Add('    a: longint;');
  Add('  end;');
  Add('procedure DoIt(i: longint; const j: longint; var k: longint; out l: longint);');
  Add('begin');
  Add('  DoIt({#loc1_read}i,{#loc2_read}i,{#loc3_var}i,{#loc4_out}i);');
  Add('end;');
  Add('var');
  Add('  r: TRec;');
  Add('begin');
  Add('  DoIt({#r1_read}r.{#r_a1_read}a,');
  Add('    {#r2_read}r.{#r_a2_read}a,');
  Add('    {#r3_read}r.{#r_a3_var}a,');
  Add('    {#r4_read}r.{#r_a4_out}a);');
  Add('  with r do');
  Add('    DoIt({#w_a1_read}a,');
  Add('      {#w_a2_read}a,');
  Add('      {#w_a3_var}a,');
  Add('      {#w_a4_out}a);');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestRecord;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TRec}TRec = record');
  Add('    {#Size}Size: longint;');
  Add('  end;');
  Add('var');
  Add('  {#r}{=TRec}r: TRec;');
  Add('begin');
  Add('  {@r}r.{@Size}Size:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestRecordVariant;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TRec}TRec = record');
  Add('    {#Size}Size: longint;');
  Add('    case {#vari}vari: longint of');
  Add('    0: ({#b}b: longint)');
  Add('  end;');
  Add('var');
  Add('  {#r}{=TRec}r: TRec;');
  Add('begin');
  Add('  {@r}r.{@Size}Size:=3;');
  Add('  {@r}r.{@vari}vari:=4;');
  Add('  {@r}r.{@b}b:=5;');
  ParseProgram;
end;

procedure TTestResolver.TestRecordVariantNested;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TRec}TRec = record');
  Add('    {#Size}Size: longint;');
  Add('    case {#vari}vari: longint of');
  Add('    0: ({#b}b: longint)');
  Add('    1: ({#c}c:');
  Add('          record');
  Add('            {#d}d: longint;');
  Add('            case {#e}e: longint of');
  Add('            0: ({#f}f: longint)');
  Add('          end)');
  Add('  end;');
  Add('var');
  Add('  {#r}{=TRec}r: TRec;');
  Add('begin');
  Add('  {@r}r.{@Size}Size:=3;');
  Add('  {@r}r.{@vari}vari:=4;');
  Add('  {@r}r.{@b}b:=5;');
  Add('  {@r}r.{@c}c.{@d}d:=6;');
  Add('  {@r}r.{@c}c.{@e}e:=7;');
  Add('  {@r}r.{@c}c.{@f}f:=8;');
  ParseProgram;
end;

procedure TTestResolver.TestClass;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#B}b: longint;');
  Add('  end;');
  Add('var');
  Add('  {#C}{=TOBJ}c: TObject;');
  Add('begin');
  Add('  {@C}c.{@b}b:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestClassDefaultInheritance;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#OBJ_b}b: longint;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#A_c}c: longint;');
  Add('  end;');
  Add('var');
  Add('  {#V}{=A}v: TClassA;');
  Add('begin');
  Add('  {@V}v.{@A_c}c:=2;');
  Add('  {@V}v.{@OBJ_b}b:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestClassTripleInheritance;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#OBJ_a}a: longint;');
  Add('    {#OBJ_b}b: longint;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#A_c}c: longint;');
  Add('  end;');
  Add('  {#B}TClassB = class(TClassA)');
  Add('    {#B_d}d: longint;');
  Add('  end;');
  Add('var');
  Add('  {#V}{=B}v: TClassB;');
  Add('begin');
  Add('  {@V}v.{@B_d}d:=1;');
  Add('  {@V}v.{@A_c}c:=2;');
  Add('  {@V}v.{@OBJ_B}b:=3;');
  Add('  {@V}v.{@Obj_a}a:=4;');
  ParseProgram;
end;

procedure TTestResolver.TestClassForward;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  {#B_forward}TClassB = class;');
  Add('  {#A}TClassA = class');
  Add('    {#A_b}{=B_forward}b: TClassB;');
  Add('  end;');
  Add('  {#B}TClassB = class(TClassA)');
  Add('    {#B_a}a: longint;');
  Add('    {#B_d}d: longint;');
  Add('  end;');
  Add('var');
  Add('  {#V}{=B}v: TClassB;');
  Add('begin');
  Add('  {@V}v.{@B_d}d:=1;');
  Add('  {@V}v.{@B_a}a:=2;');
  Add('  {@V}v.{@A_b}b:=nil;');
  Add('  {@V}v.{@A_b}b.{@B_a}a:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestClassForwardNotResolved;
var
  ErrorNo: Integer;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  TClassB = class;');
  Add('var');
  Add('  v: TClassB;');
  Add('begin');
  ErrorNo:=0;
  try
    ParseModule;
  except
    on E: EPasResolve do
      ErrorNo:=E.MsgNumber;
  end;
  AssertEquals('Forward class not resolved raises correct error',nForwardTypeNotResolved,ErrorNo);
end;

procedure TTestResolver.TestClass_Method;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    procedure {#A_ProcA_Decl}ProcA;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#V}{=A}v: TClassA;');
  Add('begin');
  Add('  {@V}v.{@A_ProcA_Decl}ProcA;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodWithParams;
begin
  StartProgram(false);
  Add('type');
  Add('  {#A}TObject = class');
  Add('    procedure {#ProcA_Decl}ProcA({#Bar}Bar: longint);');
  Add('  end;');
  Add('procedure tobject.proca(bar: longint);');
  Add('begin');
  Add('  if {@Bar}bar=3 then ;');
  Add('end;');
  Add('var');
  Add('  {#V}{=A}Obj: TObject;');
  Add('begin');
  Add('  {@V}Obj.{@ProcA_Decl}ProcA(4);');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodUnresolved;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  TClassA = class');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('begin');
  CheckResolverException('forward proc not resolved',PasResolver.nForwardProcNotResolved);
end;

procedure TTestResolver.TestClass_MethodAbstract;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; virtual; abstract;');
  Add('  end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodAbstractWithoutVirtualFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; abstract;');
  Add('  end;');
  Add('begin');
  CheckResolverException('abstract without virtual',PasResolver.nInvalidProcModifiers);
end;

procedure TTestResolver.TestClass_MethodAbstractHasBodyFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; virtual; abstract;');
  Add('  end;');
  Add('procedure TObject.ProcA;');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('abstract must not have implementation',
    PasResolver.nAbstractMethodsMustNotHaveImplementation);
end;

procedure TTestResolver.TestClass_MethodUnresolvedWithAncestor;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; virtual; abstract;');
  Add('  end;');
  Add('  TClassA = class');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('begin');
  CheckResolverException('forward proc not resolved',PasResolver.nForwardProcNotResolved);
end;

procedure TTestResolver.TestClass_ProcFuncMismatch;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure DoIt;');
  Add('  end;');
  Add('function TObject.DoIt: longint;');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('procedure expected, but function found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestClass_MethodOverload;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure DoIt;');
  Add('    procedure DoIt(i: longint);');
  Add('    procedure DoIt(s: string);');
  Add('  end;');
  Add('procedure TObject.DoIt;');
  Add('begin');
  Add('end;');
  Add('procedure TObject.DoIt(i: longint);');
  Add('begin');
  Add('end;');
  Add('procedure TObject.DoIt(s: string);');
  Add('begin');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodInvalidOverload;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure DoIt(i: longint);');
  Add('    procedure DoIt(k: longint);');
  Add('  end;');
  Add('procedure TObject.DoIt(i: longint);');
  Add('begin');
  Add('end;');
  Add('procedure TObject.DoIt(k: longint);');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckResolverException('Duplicate identifier',PasResolver.nDuplicateIdentifier);
end;

procedure TTestResolver.TestClass_MethodOverride;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure {#TOBJ_ProcA}ProcA; virtual; abstract;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    procedure {#A_ProcA}ProcA; override;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#V}{=A}v: TClassA;');
  Add('begin');
  Add('  {@V}v.{@A_ProcA}ProcA;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodOverride2;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure {#TOBJ_ProcA}ProcA; virtual; abstract;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    procedure {#A_ProcA}ProcA; override;');
  Add('  end;');
  Add('  {#B}TClassB = class');
  Add('    procedure {#B_ProcA}ProcA; override;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('end;');
  Add('procedure TClassB.ProcA;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#V}{=B}v: TClassB;');
  Add('begin');
  Add('  {@V}v.{@B_ProcA}ProcA;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodOverrideFixCase;

  procedure CheckOverrideName(aLabel: string);
  var
    Elements: TFPList;
    i: Integer;
    El: TPasElement;
    Scope: TPasProcedureScope;
  begin
    Elements:=FindElementsAtSrcLabel(aLabel);
    try
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        if not (El is TPasProcedure) then continue;
        Scope:=El.CustomData as TPasProcedureScope;
        if Scope.OverriddenProc=nil then
          Fail('Scope.OverriddenProc=nil');
        AssertEquals('Proc Name and Proc.Scope.OverriddenProc.Name',El.Name,Scope.OverriddenProc.Name);
        end;
    finally
      Elements.Free;
    end;
  end;

begin
  ResolverEngine.Options:=ResolverEngine.Options+[proFixCaseOfOverrides];
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure {#TOBJ_ProcA}ProcA; virtual; abstract;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    procedure {#A_ProcA}proca; override;');
  Add('  end;');
  Add('  {#B}TClassB = class');
  Add('    procedure {#B_ProcA}prOca; override;');
  Add('  end;');
  Add('procedure tclassa.proca;');
  Add('begin');
  Add('end;');
  Add('procedure tclassb.proca;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#V}{=B}v: TClassB;');
  Add('begin');
  Add('  {@V}v.{@B_ProcA}ProcA;');
  ParseProgram;
  CheckOverrideName('A_ProcA');
  CheckOverrideName('B_ProcA');
end;

procedure TTestResolver.TestClass_MethodOverrideSameResultType;
begin
  AddModuleWithIntfImplSrc('unit2.pp',
    LinesToStr([
    'type',
    '  TObject = class',
    '  public',
    '    function ProcA(const s: string): string; virtual; abstract;',
    '  end;',
    '']),
    LinesToStr([
    ''])
    );

  StartProgram(true);
  Add('uses unit2;');
  Add('type');
  Add('  TCar = class');
  Add('  public');
  Add('    function ProcA(const s: string): string; override;');
  Add('  end;');
  Add('function TCar.ProcA(const s: string): string; begin end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodOverrideDiffResultTypeFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  public');
  Add('    function ProcA(const s: string): string; virtual; abstract;');
  Add('  end;');
  Add('  TCar = class');
  Add('  public');
  Add('    function ProcA(const s: string): longint; override;');
  Add('  end;');
  Add('function TCar.ProcA(const s: string): longint; begin end;');
  Add('begin');
  CheckResolverException('Result type mismatch, expected String, but found Longint',
    nResultTypeMismatchExpectedButFound);
end;

procedure TTestResolver.TestClass_MethodOverloadAncestor;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure {#A1}DoIt;');
  Add('    procedure {#B1}DoIt(i: longint);');
  Add('  end;');
  Add('  TCar = class');
  Add('    procedure {#A2}DoIt;');
  Add('    procedure {#B2}DoIt(i: longint);');
  Add('  end;');
  Add('procedure TObject.DoIt; begin end;');
  Add('procedure TObject.DoIt(i: longint); begin end;');
  Add('procedure TCar.DoIt;');
  Add('begin');
  Add('  {@A2}DoIt;');
  Add('  {@B2}DoIt(1);');
  Add('  inherited {@A1}DoIt;');
  Add('  inherited {@B1}DoIt(2);');
  Add('end;');
  Add('procedure TCar.DoIt(i: longint); begin end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_MethodScope;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#A_A}A: longint;');
  Add('    procedure {#A_ProcB}ProcB;');
  Add('  end;');
  Add('procedure TClassA.ProcB;');
  Add('begin');
  Add('  {@A_A}A:=3;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_IdentifierSelf;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    {#C}C: longint;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#B}B: longint;');
  Add('    procedure {#A_ProcB}ProcB;');
  Add('  end;');
  Add('procedure TClassA.ProcB;');
  Add('begin');
  Add('  {@B}B:=1;');
  Add('  {@C}C:=2;');
  Add('  Self.{@B}B:=3;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClassCallInherited;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure {#TOBJ_ProcA}ProcA(vI: longint); virtual;');
  Add('    procedure {#TOBJ_ProcB}ProcB(vJ: longint); virtual;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    procedure {#A_ProcA}ProcA({#i1}vI: longint); override;');
  Add('    procedure {#A_ProcB}ProcB(vJ: longint); override;');
  Add('    procedure {#A_ProcC}ProcC; virtual;');
  Add('  end;');
  Add('procedure TObject.ProcA(vi: longint);');
  Add('begin');
  Add('  inherited; // ignore, do not raise error');
  Add('end;');
  Add('procedure TObject.ProcB(vj: longint);');
  Add('begin');
  Add('end;');
  Add('procedure TClassA.ProcA(vi: longint);');
  Add('begin');
  Add('  {@A_ProcA}ProcA({@i1}vI);');
  Add('  {@TOBJ_ProcA}inherited;');
  Add('  inherited {@TOBJ_ProcA}ProcA({@i1}vI);');
  Add('  {@A_ProcB}ProcB({@i1}vI);');
  Add('  inherited {@TOBJ_ProcB}ProcB({@i1}vI);');
  Add('end;');
  Add('procedure TClassA.ProcB(vJ: longint);');
  Add('begin');
  Add('end;');
  Add('procedure TClassA.ProcC;');
  Add('begin');
  Add('  inherited; // ignore, do not raise error');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClassCallInheritedNoParamsAbstractFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; virtual; abstract;');
  Add('  end;');
  Add('  TClassA = class');
  Add('    procedure ProcA; override;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('  inherited;');
  Add('end;');
  Add('begin');
  CheckResolverException('Abstract methods cannot be called directly',
    PasResolver.nAbstractMethodsCannotBeCalledDirectly);
end;

procedure TTestResolver.TestClassCallInheritedWithParamsAbstractFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA(c: char); virtual; abstract;');
  Add('  end;');
  Add('  TClassA = class');
  Add('    procedure ProcA(c: char); override;');
  Add('  end;');
  Add('procedure TClassA.ProcA(c: char);');
  Add('begin');
  Add('  inherited ProcA(c);');
  Add('end;');
  Add('begin');
  CheckResolverException('Abstract methods cannot be called directly',
    PasResolver.nAbstractMethodsCannotBeCalledDirectly);
end;

procedure TTestResolver.TestClassCallInheritedConstructor;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor {#TOBJ_CreateA}Create(vI: longint); virtual;');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    constructor {#A_CreateA}Create({#i1}vI: longint); override;');
  Add('  end;');
  Add('constructor TObject.Create(vI: longint);');
  Add('begin');
  Add('  inherited; // ignore and do not raise error');
  Add('end;');
  Add('constructor TClassA.Create(vI: longint);');
  Add('begin');
  Add('  {@A_CreateA}Create({@i1}vI);');
  Add('  {@TOBJ_CreateA}inherited;');
  Add('  inherited {@TOBJ_CreateA}Create({@i1}vI);');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClassAssignNil;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#FSub}FSub: TClassA;');
  Add('    property {#Sub}Sub: TClassA read {@FSub}FSub write {@FSub}FSub;');
  Add('  end;');
  Add('var');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@v}v:=nil;');
  Add('  if {@v}v=nil then ;');
  Add('  if nil={@v}v then ;');
  Add('  if {@v}v<>nil then ;');
  Add('  if nil<>{@v}v then ;');
  Add('  {@v}v.{@FSub}FSub:=nil;');
  Add('  if {@v}v.{@FSub}FSub=nil then ;');
  Add('  if {@v}v.{@FSub}FSub<>nil then ;');
  Add('  {@v}v.{@Sub}Sub:=nil;');
  Add('  if {@v}v.{@Sub}Sub=nil then ;');
  Add('  if {@v}v.{@Sub}Sub<>nil then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassAssign;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#FSub}FSub: TClassA;');
  Add('    property {#Sub}Sub: TClassA read {@FSub}FSub write {@FSub}FSub;');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('  {#p}{=A}p: TClassA;');
  Add('begin');
  Add('  {@o}o:={@v}v;');
  Add('  {@v}v:={@p}p;');
  Add('  if {@v}v={@p}p then ;');
  Add('  if {@v}v={@o}o then ;');
  Add('  if {@o}o={@o}o then ;');
  Add('  if {@o}o={@v}v then ;');
  Add('  if {@v}v<>{@p}p then ;');
  Add('  if {@v}v<>{@o}o then ;');
  Add('  if {@o}o<>{@o}o then ;');
  Add('  if {@o}o<>{@v}v then ;');
  Add('  {@v}v.{@FSub}FSub:={@p}p;');
  Add('  {@p}p:={@v}v.{@FSub}FSub;');
  Add('  {@o}o:={@v}v.{@FSub}FSub;');
  Add('  {@v}v.{@Sub}Sub:={@p}p;');
  Add('  {@p}p:={@v}v.{@Sub}Sub;');
  Add('  {@o}o:={@v}v.{@Sub}Sub;');
  ParseProgram;
end;

procedure TTestResolver.TestClassNilAsParam;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('procedure ProcP(o: TObject);');
  Add('begin end;');
  Add('begin');
  Add('  ProcP(nil);');
  ParseProgram;
end;

procedure TTestResolver.TestClass_Operators_Is_As;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#Sub}Sub: TClassA;');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  if {@o}o is {@A}TClassA then;');
  Add('  if {@v}v is {@A}TClassA then;');
  Add('  if {@v}v.{@Sub}Sub is {@A}TClassA then;');
  Add('  {@v}v:={@o}o as {@A}TClassA;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_OperatorIsOnNonDescendantFail;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  if {@v}v is {@TObj}TObject then;');
  CheckResolverException('types are not related',PasResolver.nTypesAreNotRelated);
end;

procedure TTestResolver.TestClass_OperatorIsOnNonTypeFail;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  if {@o}o is {@v}v then;');
  CheckResolverException('class type expected, but got variable',
    PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestClass_OperatorAsOnNonDescendantFail;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@o}o:={@v}v as {@TObj}TObject;');
  CheckResolverException('types are not related',PasResolver.nTypesAreNotRelated);
end;

procedure TTestResolver.TestClass_OperatorAsOnNonTypeFail;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@o}o:={@v}v as {@o}o;');
  CheckResolverException('class expected, but o found" number',
    PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestClassAsFuncResult;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('     {#A_i}i: longint;');
  Add('     constructor {#A_CreateA}Create;');
  Add('     constructor {#A_CreateB}Create(i: longint);');
  Add('  end;');
  Add('function {#F}F: TClassA;');
  Add('begin');
  Add('  Result:=nil;');
  Add('end;');
  Add('constructor TClassA.Create;');
  Add('begin');
  Add('end;');
  Add('constructor TClassA.Create(i: longint);');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@o}o:={@F}F;');
  Add('  {@o}o:={@F}F();');
  Add('  {@v}v:={@F}F;');
  Add('  {@v}v:={@F}F();');
  Add('  if {@o}o={@F}F then ;');
  Add('  if {@o}o={@F}F() then ;');
  Add('  if {@v}v={@F}F then ;');
  Add('  if {@v}v={@F}F() then ;');
  Add('  {@v}v:={@A}TClassA.{@A_CreateA}Create;');
  Add('  {@v}v:={@A}TClassA.{@A_CreateA}Create();');
  Add('  {@v}v:={@A}TClassA.{@A_CreateB}Create(3);');
  Add('  {@A}TClassA.{@A_CreateA}Create.{@A_i}i:=3;');
  Add('  {@A}TClassA.{@A_CreateA}Create().{@A_i}i:=3;');
  Add('  {@A}TClassA.{@A_CreateB}Create(3).{@A_i}i:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestClassTypeCast;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    id: longint;');
  Add('  end;');
  Add('procedure ProcA(var a: TClassA);');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@o}o:={@v}v;');
  Add('  {@o}o:=TObject({@o}o);');
  Add('  {@v}v:=TClassA({@o}o);');
  Add('  {@v}v:=TClassA(TObject({@o}o));');
  Add('  {@v}v:=TClassA({@v}v);');
  Add('  {@v}v:=v as TClassA;');
  Add('  {@v}v:=o as TClassA;');
  Add('  ProcA({@v}v);');
  Add('  ProcA(TClassA({@o}o));');
  Add('  if TClassA({@o}o).id=3 then ;');
  Add('  if (o as TClassA).id=3 then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassTypeCastUnrelatedFail;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    id: longint;');
  Add('  end;');
  Add('  {#B}TClassB = class');
  Add('    Name: string;');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#va}{=A}va: TClassA;');
  Add('  {#vb}{=B}vb: TClassB;');
  Add('begin');
  Add('  {@vb}vb:=TClassB({@va}va);');
  CheckResolverException('Illegal type conversion: "class TClassA" to "TClassB"',
    PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestClass_TypeCastSelf;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor Create;');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('  TClassA = class');
  Add('    id: longint;');
  Add('  end;');
  Add('constructor TObject.Create;');
  Add('begin');
  Add('  TClassA(Self).id:=3;');
  Add('  if TClassA(Self).id=4 then;');
  Add('  if 5=TClassA(Self).id then;');
  Add('end;');
  Add('procedure TObject.ProcA;');
  Add('begin');
  Add('  TClassA(Self).id:=3;');
  Add('  if TClassA(Self).id=4 then;');
  Add('  if 5=TClassA(Self).id then;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_TypeCaseMultipleParamsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    i: longint;');
  Add('  end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.i:=TObject(o,o).i;');
  CheckResolverException('wrong number of parameters for type cast to TObject',
    PasResolver.nWrongNumberOfParametersForTypeCast);
end;

procedure TTestResolver.TestClass_TypeCastAssign;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  TCar = class');
  Add('  end;');
  Add('procedure DoIt(a: TCar; const b: TCar; var c: TCar; out d: TCar); begin end;');
  Add('var');
  Add('  o: TObject;');
  Add('  c: TCar;');
  Add('begin');
  Add('  TCar({#a_assign}o):=nil;');
  Add('  TCar({#b_assign}o):=c;');
  Add('  DoIt(TCar({#c1_read}o),TCar({#c2_read}o),TCar({#c3_var}o),TCar({#c4_out}o));');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestClass_AccessMemberViaClassFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    i: longint;');
  Add('  end;');
  Add('begin');
  Add('  if TObject.i=7 then ;');
  CheckResolverException('Only class methods, class properties and class variables can be referred with class references',
    PasResolver.nOnlyClassMembersCanBeReferredWithClassReferences);
end;

procedure TTestResolver.TestClass_FuncReturningObjectMember;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    i: longint;');
  Add('  end;');
  Add('function FuncO: TObject;');
  Add('begin');
  Add('end;');
  Add('begin');
  Add('  FuncO.i:=3;');
  Add('  if FuncO.i=4 then ;');
  Add('  if 5=FuncO.i then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_StaticWithoutClassFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA; static;');
  Add('  end;');
  Add('procedure TObject.ProcA; begin end;');
  Add('begin');
  CheckResolverException('Invalid procedure modifiers static',PasResolver.nInvalidProcModifiers);
end;

procedure TTestResolver.TestClass_SelfInStaticFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class procedure ProcA; static;');
  Add('  end;');
  Add('class procedure TObject.ProcA;');
  Add('begin');
  Add('  if Self=nil then ;');
  Add('end;');
  Add('begin');
  CheckResolverException('identifier not found "Self"',PasResolver.nIdentifierNotFound);
end;

procedure TTestResolver.TestClass_PrivateProtectedInSameUnit;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  strict private {#vstrictprivate}vstrictprivate: longint;');
  Add('  strict protected {#vstrictprotected}vstrictprotected: longint;');
  Add('  private {#vprivate}vprivate: longint;');
  Add('  protected {#vprotected}vprotected: longint;');
  Add('  public {#vpublic}vpublic: longint;');
  Add('    procedure ProcA;');
  Add('  automated {#vautomated}vautomated: longint;');
  Add('  published {#vpublished}vpublished: longint;');
  Add('  end;');
  Add('procedure TObject.ProcA;');
  Add('begin');
  Add('  if {@vstrictprivate}vstrictprivate=1 then ;');
  Add('  if {@vstrictprotected}vstrictprotected=2 then ;');
  Add('  if {@vprivate}vprivate=3 then ;');
  Add('  if {@vprotected}vprotected=4 then ;');
  Add('  if {@vpublic}vpublic=5 then ;');
  Add('  if {@vautomated}vautomated=6 then ;');
  Add('  if {@vpublished}vpublished=7 then ;');
  Add('end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  if o.vprivate=10 then ;');
  Add('  if o.vprotected=11 then ;');
  Add('  if o.vpublic=12 then ;');
  Add('  if o.vautomated=13 then ;');
  Add('  if o.vpublished=14 then ;');
end;

procedure TTestResolver.TestClass_PrivateInMainBeginFail;
begin
  AddModuleWithSrc('unit1.pas',
    LinesToStr([
      'unit unit1;',
      'interface',
      'type',
      '  TObject = class',
      '  private v: longint;',
      '  end;',
      'implementation',
      'end.'
      ]));
  StartProgram(true);
  Add('uses unit1;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  if o.v=3 then ;');
  CheckResolverException('Can''t access private member v',
    PasResolver.nCantAccessPrivateMember);
end;

procedure TTestResolver.TestClass_PrivateInDescendantFail;
begin
  AddModuleWithSrc('unit1.pas',
    LinesToStr([
      'unit unit1;',
      'interface',
      'type',
      '  TObject = class',
      '  private v: longint;',
      '  end;',
      'implementation',
      'end.'
      ]));
  StartProgram(true);
  Add('uses unit1;');
  Add('type');
  Add('  TClassA = class(TObject)');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('  if v=3 then ;');
  Add('end;');
  Add('begin');
  CheckResolverException('Can''t access private member v',
    PasResolver.nCantAccessPrivateMember);
end;

procedure TTestResolver.TestClass_ProtectedInDescendant;
begin
  AddModuleWithSrc('unit1.pas',
    LinesToStr([
      'unit unit1;',
      'interface',
      'type',
      '  TObject = class',
      '  protected vprotected: longint;',
      '  strict protected vstrictprotected: longint;',
      '  end;',
      'implementation',
      'end.'
      ]));
  StartProgram(true);
  Add('uses unit1;');
  Add('type');
  Add('  TClassA = class(TObject)');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('procedure TClassA.ProcA;');
  Add('begin');
  Add('  if vprotected=3 then ;');
  Add('  if vstrictprotected=4 then ;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_StrictPrivateInMainBeginFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  strict private v: longint;');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  if o.v=3 then ;');
  CheckResolverException('Can''t access strict private member v',
    PasResolver.nCantAccessPrivateMember);
end;

procedure TTestResolver.TestClass_StrictProtectedInMainBeginFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  strict protected v: longint;');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  if o.v=3 then ;');
  CheckResolverException('Can''t access strict protected member v',
    PasResolver.nCantAccessPrivateMember);
end;

procedure TTestResolver.TestClass_Constructor_NewInstance;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
  ActualNewInstance, ActualImplicitCallWithoutParams: Boolean;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor Create;');
  Add('    class function DoSome: TObject;');
  Add('  end;');
  Add('constructor TObject.Create;');
  Add('begin');
  Add('  {#a}Create; // normal call');
  Add('  TObject.{#b}Create; // new instance');
  Add('end;');
  Add('class function TObject.DoSome: TObject;');
  Add('begin');
  Add('  Result:={#c}Create; // new instance');
  Add('end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  TObject.{#p}Create; // new object');
  Add('  o:=TObject.{#q}Create; // new object');
  Add('  o.{#r}Create; // normal call');
  ParseProgram;
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestClass_Constructor_NewInstance ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualNewInstance:=false;
      ActualImplicitCallWithoutParams:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestClass_Constructor_NewInstance ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if not (Ref.Declaration is TPasProcedure) then continue;
        //writeln('TTestResolver.TestClass_Constructor_NewInstance ',GetObjName(Ref.Declaration),' rrfNewInstance=',rrfNewInstance in Ref.Flags);
        if (Ref.Declaration is TPasConstructor) then
          ActualNewInstance:=rrfNewInstance in Ref.Flags;
        ActualImplicitCallWithoutParams:=rrfImplicitCallWithoutParams in Ref.Flags;
        break;
        end;
      if not ActualImplicitCallWithoutParams then
        RaiseErrorAtSrcMarker('expected implicit call at "#'+aMarker^.Identifier+', but got function ref"',aMarker);
      case aMarker^.Identifier of
      'a','r':// should be normal call
        if ActualNewInstance then
          RaiseErrorAtSrcMarker('expected normal call at "#'+aMarker^.Identifier+', but got newinstance"',aMarker);
      else // should be newinstance
        if not ActualNewInstance then
          RaiseErrorAtSrcMarker('expected newinstance at "#'+aMarker^.Identifier+', but got normal call"',aMarker);
      end;
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestClass_Constructor_InstanceCallResultFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor Create;');
  Add('  end;');
  Add('constructor TObject.Create;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  o:=o.Create; // normal call has no result -> fail');
  CheckResolverException('Incompatible types: got "Procedure/Function" expected "TObject"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestClass_Destructor_FreeInstance;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
  ActualFreeInstance, ActualImplicitCallWithoutParams: Boolean;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    destructor Destroy; virtual;');
  Add('  end;');
  Add('  TChild = class(TObject)');
  Add('    destructor DestroyOther;');
  Add('  end;');
  Add('destructor TObject.Destroy;');
  Add('begin');
  Add('end;');
  Add('destructor TChild.DestroyOther;');
  Add('begin');
  Add('  {#a}Destroy; // free instance');
  Add('  inherited {#b}Destroy; // normal call');
  Add('end;');
  Add('var');
  Add('  c: TChild;');
  Add('begin');
  Add('  c.{#c}Destroy; // free instance');
  Add('  c.{#d}DestroyOther; // free instance');
  ParseProgram;
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestClass_Destructor_FreeInstance ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualFreeInstance:=false;
      ActualImplicitCallWithoutParams:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestClass_Destructor_FreeInstance ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if not (Ref.Declaration is TPasProcedure) then continue;
        //writeln('TTestResolver.TestClass_Destructor_FreeInstance ',GetObjName(Ref.Declaration),' rrfNewInstance=',rrfNewInstance in Ref.Flags);
        if (Ref.Declaration is TPasDestructor) then
          ActualFreeInstance:=rrfFreeInstance in Ref.Flags;
        ActualImplicitCallWithoutParams:=rrfImplicitCallWithoutParams in Ref.Flags;
        break;
        end;
      if not ActualImplicitCallWithoutParams then
        RaiseErrorAtSrcMarker('expected implicit call at "#'+aMarker^.Identifier+', but got function ref"',aMarker);
      case aMarker^.Identifier of
      'b':// should be normal call
        if ActualFreeInstance then
          RaiseErrorAtSrcMarker('expected normal call at "#'+aMarker^.Identifier+', but got freeinstance"',aMarker);
      else // should be freeinstance
        if not ActualFreeInstance then
          RaiseErrorAtSrcMarker('expected freeinstance at "#'+aMarker^.Identifier+', but got normal call"',aMarker);
      end;
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestClass_ConDestructor_CallInherited;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    constructor Create;');
  Add('    destructor Destroy; virtual;');
  Add('  end;');
  Add('  TChild = class(TObject)');
  Add('    constructor Create;');
  Add('    destructor Destroy; override;');
  Add('  end;');
  Add('constructor TObject.Create;');
  Add('begin');
  Add('end;');
  Add('destructor TObject.Destroy;');
  Add('begin');
  Add('end;');
  Add('constructor TChild.Create;');
  Add('begin');
  Add('  {#c}inherited; // normal call');
  Add('end;');
  Add('destructor TChild.Destroy;');
  Add('begin');
  Add('  {#d}inherited; // normal call');
  Add('end;');
  Add('begin');
  ParseProgram;
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    writeln('TTestResolver.TestClass_ConDestructor_Inherited ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        writeln('TTestResolver.TestClass_ConDestructor_Inherited ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if not (Ref.Declaration is TPasProcedure) then continue;
        writeln('TTestResolver.TestClass_ConDestructor_Inherited ',GetObjName(Ref.Declaration),' rrfNewInstance=',rrfNewInstance in Ref.Flags);
        if rrfNewInstance in Ref.Flags then
          RaiseErrorAtSrcMarker('expected normal call at "#'+aMarker^.Identifier+', but got newinstance"',aMarker);
        if rrfFreeInstance in Ref.Flags then
          RaiseErrorAtSrcMarker('expected normal call at "#'+aMarker^.Identifier+', but got freeinstance"',aMarker);
        break;
        end;
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestClass_Constructor_Inherited;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    constructor Create;');
  Add('    destructor Destroy;');
  Add('    procedure DoIt;');
  Add('  end;');
  Add('  {#TClassA}TClassA = class');
  Add('    Sub: TObject;');
  Add('  end;');
  Add('constructor TObject.Create; begin end;');
  Add('destructor TObject.Destroy; begin end;');
  Add('procedure TObject.DoIt; begin end;');
  Add('var a: TClassA;');
  Add('begin');
  Add('  a:=TClassA.Create;');
  Add('  a.DoIt;');
  Add('  a.Destroy;');
  Add('  if TClassA.Create.Sub=nil then ;');
  Add('  with TClassA.Create do Sub:=nil;');
  Add('  with TClassA do a:=Create;');
  Add('  with TClassA do Create.Sub:=nil;');
  ParseProgram;
end;

procedure TTestResolver.TestClass_SubObject;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#Sub}Sub: TObject;');
  Add('    procedure DoIt(p: longint);');
  Add('    function GetIt(p: longint): TObject;');
  Add('  end;');
  Add('procedure TObject.DoIt(p: longint); begin end;');
  Add('function TObject.GetIt(p: longint): TObject; begin end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.Sub:=nil;');
  Add('  o.Sub.Sub:=nil;');
  Add('  if o.Sub=nil then ;');
  Add('  if o.Sub=o.Sub.Sub then ;');
  Add('  o.Sub.DoIt(3);');
  Add('  o.Sub.GetIt(4);');
  Add('  o.Sub.GetIt(5).DoIt(6);');
  Add('  o.Sub.GetIt(7).Sub.DoIt(8);');
  ParseProgram;
end;

procedure TTestResolver.TestClass_WithClassInstance;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  ActualRefWith: Boolean;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FInt: longint;');
  Add('    FObj: TObject;');
  Add('    FArr: array of longint;');
  Add('    constructor Create;');
  Add('    function GetSize: longint;');
  Add('    procedure SetSize(Value: longint);');
  Add('    function GetItems(Index: longint): longint;');
  Add('    procedure SetItems(Index, Value: longint);');
  Add('    property Size: longint read GetSize write SetSize;');
  Add('    property Items[Index: longint]: longint read GetItems write SetItems;');
  Add('  end;');
  Add('constructor TObject.Create; begin end;');
  Add('function TObject.GetSize: longint; begin end;');
  Add('procedure TObject.SetSize(Value: longint); begin end;');
  Add('function TObject.GetItems(Index: longint): longint; begin end;');
  Add('procedure TObject.SetItems(Index, Value: longint); begin end;');
  Add('var');
  Add('  Obj: TObject;');
  Add('  i: longint;');
  Add('begin');
  Add('  with TObject.Create do begin');
  Add('    {#A}FInt:=3;');
  Add('    i:={#B}FInt;');
  Add('    i:={#C}GetSize;');
  Add('    i:={#D}GetSize();');
  Add('    {#E}SetSize(i);');
  Add('    i:={#F}Size;');
  Add('    {#G}Size:=i;');
  Add('    i:={#H}Items[i];');
  Add('    {#I}Items[i]:=i;');
  Add('    i:={#J}FArr[i];');
  Add('    {#K}FArr[i]:=i;');
  Add('  end;');
  ParseProgram;
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestClass_WithClassInstance ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualRefWith:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestClass_WithClassInstance ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if Ref.WithExprScope=nil then continue;
        ActualRefWith:=true;
        break;
        end;
      if not ActualRefWith then
        RaiseErrorAtSrcMarker('expected Ref.WithExprScope<>nil at "#'+aMarker^.Identifier+', but got nil"',aMarker);
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestClass_ProcedureExternal;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure DoIt; external ''somewhere'';');
  Add('  end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_ReintroducePublicVarFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  public');
  Add('    Some: longint;');
  Add('  end;');
  Add('  TCar = class(tobject)');
  Add('  public');
  Add('    Some: longint;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Duplicate identifier "Some" at afile.pp(5,8)',nDuplicateIdentifier);
end;

procedure TTestResolver.TestClass_ReintroducePrivateVar;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  strict private');
  Add('    Some: longint;');
  Add('  end;');
  Add('  TCar = class(tobject)');
  Add('  public');
  Add('    Some: longint;');
  Add('  end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_ReintroduceProc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  strict private');
  Add('    Some: longint;');
  Add('  end;');
  Add('  TMobile = class');
  Add('  strict private');
  Add('    Some: string;');
  Add('  end;');
  Add('  TCar = class(tmobile)');
  Add('    procedure {#A}Some;');
  Add('    procedure {#B}Some(vA: longint);');
  Add('  end;');
  Add('procedure tcar.some;');
  Add('begin');
  Add('  {@A}Some;');
  Add('  {@B}Some(1);');
  Add('end;');
  Add('procedure tcar.some(va: longint); begin end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_UntypedParam_TypeCast;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('procedure {#ProcA}ProcA(var {#A}A);');
  Add('begin');
  Add('  TObject({@A}A):=TObject({@A}A);');
  Add('  if TObject({@A}A)=nil then ;');
  Add('  if nil=TObject({@A}A) then ;');
  Add('end;');
  Add('procedure {#ProcB}ProcB(const {#B}B);');
  Add('begin');
  Add('  if TObject({@B}B)=nil then ;');
  Add('  if nil=TObject({@B}B) then ;');
  Add('end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  {@ProcA}ProcA(o);');
  Add('  {@ProcB}ProcB(o);');
  ParseProgram;
end;

procedure TTestResolver.TestClassOf;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TClass}{=TObj}TClass = class of TObject;');
  Add('  {#TOBJ}TObject = class');
  Add('    ClassType: TClass; ');
  Add('  end;');
  Add('type');
  Add('  {#TMobile}TMobile = class');
  Add('  end;');
  Add('  {#TMobiles}{=TMobile}TMobiles = class of TMobile;');
  Add('type');
  Add('  {#TCars}{=TCar}TCars = class of TCar;');
  Add('  {#TShips}{=TShip}TShips = class of TShip;');
  Add('  {#TCar}TCar = class(TMobile)');
  Add('  end;');
  Add('  {#TShip}TShip = class(TMobile)');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('  c: TClass;');
  Add('  mobile: TMobile;');
  Add('  mobiletype: TMobiles;');
  Add('  car: TCar;');
  Add('  cartype: TCars;');
  Add('  ship: TShip;');
  Add('  shiptype: TShips;');
  Add('begin');
  Add('  c:=nil;');
  Add('  c:=o.ClassType;');
  Add('  if c=nil then;');
  Add('  if nil=c then;');
  Add('  if c=o.ClassType then ;');
  Add('  if c<>o.ClassType then ;');
  Add('  if Assigned(o) then ;');
  Add('  if Assigned(o.ClassType) then ;');
  Add('  if Assigned(c) then ;');
  Add('  mobiletype:=TMobile;');
  Add('  mobiletype:=TCar;');
  Add('  mobiletype:=TShip;');
  Add('  mobiletype:=cartype;');
  Add('  if mobiletype=nil then ;');
  Add('  if nil=mobiletype then ;');
  Add('  if mobiletype=TShip then ;');
  Add('  if TShip=mobiletype then ;');
  Add('  if mobiletype<>TShip then ;');
  Add('  if mobile is mobiletype then ;');
  Add('  if car is mobiletype then ;');
  Add('  if mobile is cartype then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOfNonClassFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TCars = class of longint;');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "class"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestClassOfIsOperatorFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('  TCar = class end;');
  Add('  TCars = class of TCar;');
  Add('var cars: TCars;');
  Add('begin');
  Add('  if cars is TCars then ;');
  CheckResolverException('left side of is-operator expects a class, but got "class of" type',
    PasResolver.nLeftSideOfIsOperatorExpectsAClassButGot);
end;

procedure TTestResolver.TestClassOfAsOperatorFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('  TCar = class end;');
  Add('  TCars = class of TCar;');
  Add('var');
  Add('  o: TObject;');
  Add('  cars: TCars;');
  Add('begin');
  Add('  cars:=cars as TCars;');
  CheckResolverException('illegal qualifier "as"',PasResolver.nIllegalQualifier);
end;

procedure TTestResolver.TestClass_ClassVar;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class var GlobalId: longint;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('var');
  Add('  o: TObject;');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  o.GlobalId:=3;');
  Add('  if o.GlobalId=4 then ;');
  Add('  if 5=o.GlobalId then ;');
  Add('  TObject.GlobalId:=6;');
  Add('  if TObject.GlobalId=7 then ;');
  Add('  if 8=TObject.GlobalId then ;');
  Add('  oc.GlobalId:=9;');
  Add('  if oc.GlobalId=10 then ;');
  Add('  if 11=oc.GlobalId then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOfDotClassVar;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class var Id: longint;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('var');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  oc.Id:=3;');
  Add('  if oc.Id=4 then ;');
  Add('  if 5=oc.Id then ;');
  Add('  TObject.Id:=3;');
  Add('  if TObject.Id=4 then ;');
  Add('  if 5=TObject.Id then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOfDotVarFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    Id: longint;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('var');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  oc.Id:=3;');
  CheckResolverException('Only class methods, class properties and class variables can be referred with class references',
    PasResolver.nOnlyClassMembersCanBeReferredWithClassReferences);
end;

procedure TTestResolver.TestClassOfDotClassProc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class procedure ProcA;');
  Add('    class function FuncB: longint;');
  Add('    class procedure ProcC(i: longint);');
  Add('    class function FuncD(i: longint): longint;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('class procedure TObject.ProcA; begin end;');
  Add('class function TObject.FuncB: longint; begin end;');
  Add('class procedure TObject.ProcC(i: longint); begin end;');
  Add('class function TObject.FuncD(i: longint): longint; begin end;');
  Add('var');
  Add('  o: TObject;');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  o.ProcA;');
  Add('  oc.ProcA;');
  Add('  TObject.ProcA;');
  Add('  o.FuncB;');
  Add('  o.FuncB();');
  Add('  oc.FuncB;');
  Add('  oc.FuncB();');
  Add('  TObject.FuncB;');
  Add('  TObject.FuncB();');
  Add('  if oc.FuncB=3 then ;');
  Add('  if oc.FuncB()=4 then ;');
  Add('  if 5=oc.FuncB then ;');
  Add('  if 6=oc.FuncB() then ;');
  Add('  oc.ProcC(7);');
  Add('  TObject.ProcC(8);');
  Add('  oc.FuncD(7);');
  Add('  TObject.FuncD(8);');
  Add('  if oc.FuncD(9)=10 then ;');
  Add('  if 11=oc.FuncD(12) then ;');
  Add('  if TObject.FuncD(13)=14 then ;');
  Add('  if 15=TObject.FuncD(16) then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOfDotProcFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('procedure TObject.ProcA; begin end;');
  Add('var');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  oc.ProcA;');
  CheckResolverException('Only class methods, class properties and class variables can be referred with class references',
    PasResolver.nOnlyClassMembersCanBeReferredWithClassReferences);
end;

procedure TTestResolver.TestClassOfDotClassProperty;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class var FA: longint;');
  Add('    class function GetA: longint; static;');
  Add('    class procedure SetA(Value: longint): longint; static;');
  Add('    class property A1: longint read FA write SetA;');
  Add('    class property A2: longint read GetA write FA;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('class function TObject.GetA: longint; begin end;');
  Add('class procedure TObject.SetA(Value: longint): longint; begin end;');
  Add('var');
  Add('  o: TObject;');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  o.A1:=3;');
  Add('  if o.A1=4 then ;');
  Add('  if 5=o.A1 then ;');
  Add('  oc.A1:=6;');
  Add('  if oc.A1=7 then ;');
  Add('  if 8=oc.A1 then ;');
  Add('  TObject.A1:=9;');
  Add('  if TObject.A1=10 then ;');
  Add('  if 11=TObject.A1 then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOfDotPropertyFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FA: longint;');
  Add('    property A: longint read FA;');
  Add('  end;');
  Add('  TObjectClass = class of TObject;');
  Add('var');
  Add('  oc: TObjectClass;');
  Add('begin');
  Add('  if oc.A=3 then ;');
  CheckResolverException('Only class methods, class properties and class variables can be referred with class references',
    PasResolver.nOnlyClassMembersCanBeReferredWithClassReferences);
end;

procedure TTestResolver.TestClass_ClassProcSelf;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class var GlobalId: longint;');
  Add('    class procedure ProcA;');
  Add('  end;');
  Add('  TClass = class of TObject;');
  Add('class procedure TObject.ProcA;');
  Add('var c: TClass;');
  Add('begin');
  Add('  if Self=nil then ;');
  Add('  if Self.GlobalId=3 then ;');
  Add('  if 4=Self.GlobalId then ;');
  Add('  Self.GlobalId:=5;');
  Add('  c:=Self;');
  Add('  c:=TClass(Self);');
  Add('  if Self=c then ;');
  Add('end;');
  Add('begin');
  ParseProgram;
end;

procedure TTestResolver.TestClass_ClassProcSelfTypeCastFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class procedure ProcA;');
  Add('  end;');
  Add('class procedure TObject.ProcA;');
  Add('begin');
  Add('  if TObject(Self)=nil then ;');
  Add('end;');
  Add('begin');
  CheckResolverException('Illegal type conversion: "class TObject" to "TObject"',
    PasResolver.nIllegalTypeConversionTo);
end;

procedure TTestResolver.TestClass_ClassMembers;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  TMobile = class');
  Add('  public');
  Add('    MobileId: longint;');
  Add('    class var LastVal: longint;');
  Add('    constructor Create; virtual;');
  Add('    class procedure ClProcA;');
  Add('    class function ClFuncB: longint;');
  Add('    class function StFuncC: longint; static;');
  Add('    class property ClMobileId: longint read StFuncC write LastVal;');
  Add('  end;');
  Add('  TMobiles = class of TMobile;');
  Add('  TCars = class of TCar;');
  Add('  TCar = class(TMobile)');
  Add('  public');
  Add('    CarId: longint;');
  Add('    class var LastCarVal: longint;');
  Add('    constructor Create; override;');
  Add('  end;');
  Add('constructor TMobile.Create;');
  Add('begin');
  Add('  Self.MobileId:=7;');
  Add('  LastVal:=LastVal+ClMobileId+1;');
  Add('  ClMobileId:=MobileId+3;');
  Add('  TCar(Self).CarId:=4;');
  Add('end;');
  Add('class procedure TMobile.ClProcA;');
  Add('var');
  Add('  m: TMobiles;');
  Add('begin');
  Add('  LastVal:=9;');
  Add('  Self.LastVal:=ClFuncB+ClMobileId;');
  Add('  m:=Self;');
  Add('  if m=Self then ;');
  Add('end;');
  Add('class function TMobile.ClFuncB: longint;');
  Add('begin');
  Add('  if LastVal=3 then ;');
  Add('  Result:=Self.LastVal-ClMobileId;');
  Add('end;');
  Add('class function TMobile.StFuncC: longint;');
  Add('begin');
  Add('  Result:=LastVal;');
  Add('  // Forbidden: no Self in static methods');
  Add('end;');
  Add('');
  Add('constructor TCar.Create;');
  Add('begin');
  Add('  inherited Create;');
  Add('  Self.CarId:=8;');
  Add('  TMobile(Self).LastVal:=5;');
  Add('  if TMobile(Self).LastVal=25 then ;');
  Add('end;');
  Add('');
  Add('var');
  Add('  car: TCar;');
  Add('  cartype: TCars;');
  Add('begin');
  Add('  car:=TCar.Create;');
  Add('  car.MobileId:=10;');
  Add('  car.ClProcA;');
  Add('  exit;');
  Add('  car.ClMobileId:=11;');
  Add('  if car.ClFuncB=16 then ;');
  Add('  if 17=car.ClFuncB then ;');
  Add('  cartype:=TCar;');
  Add('  cartype.LastVal:=18;');
  Add('  if cartype.LastVal=19 then ;');
  Add('  if 20=cartype.LastVal then ;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOf_AsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TClass = class of TObject;');
  Add('  TObject = class');
  Add('  end;');
  Add('var');
  Add('  c: tclass;');
  Add('begin');
  Add('  c:=c as TClass;');
  CheckResolverException('illegal qualifier "as"',nIllegalQualifier);
end;

procedure TTestResolver.TestClassOf_MemberAsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TClass = class of TObject;');
  Add('  TObject = class');
  Add('    c: tclass;');
  Add('  end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.c:=o.c as TClass;');
  CheckResolverException('illegal qualifier "as"',nIllegalQualifier);
end;

procedure TTestResolver.TestClassOf_IsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TClass = class of TObject;');
  Add('  TObject = class');
  Add('  end;');
  Add('var');
  Add('  c: tclass;');
  Add('begin');
  Add('  if c is TObject then;');
  CheckResolverException('left side of is-operator expects a class, but got "class of" type',
    nLeftSideOfIsOperatorExpectsAClassButGot);
end;

procedure TTestResolver.TestClass_TypeCast;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class procedure {#TObject_DoIt}DoIt;');
  Add('  end;');
  Add('  TClass = class of TObject;');
  Add('  TMobile = class');
  Add('    class procedure {#TMobile_DoIt}DoIt;');
  Add('  end;');
  Add('  TMobileClass = class of TMobile;');
  Add('  TCar = class(TMobile)');
  Add('    class procedure {#TCar_DoIt}DoIt;');
  Add('  end;');
  Add('  TCarClass = class of TCar;');
  Add('class procedure TObject.DoIt;');
  Add('begin');
  Add('  TClass(Self).{@TObject_DoIt}DoIt;');
  Add('  TMobileClass(Self).{@TMobile_DoIt}DoIt;');
  Add('end;');
  Add('class procedure TMobile.DoIt;');
  Add('begin');
  Add('  TClass(Self).{@TObject_DoIt}DoIt;');
  Add('  TMobileClass(Self).{@TMobile_DoIt}DoIt;');
  Add('  TCarClass(Self).{@TCar_DoIt}DoIt;');
  Add('end;');
  Add('class procedure TCar.DoIt; begin end;');
  Add('var');
  Add('  ObjC: TClass;');
  Add('  MobileC: TMobileClass;');
  Add('  CarC: TCarClass;');
  Add('begin');
  Add('  ObjC.{@TObject_DoIt}DoIt;');
  Add('  MobileC.{@TMobile_DoIt}DoIt;');
  Add('  CarC.{@TCar_DoIt}DoIt;');
  Add('  TClass(ObjC).{@TObject_DoIt}DoIt;');
  Add('  TMobileClass(ObjC).{@TMobile_DoIt}DoIt;');
  Add('  TCarClass(ObjC).{@TCar_DoIt}DoIt;');
  Add('  TClass(MobileC).{@TObject_DoIt}DoIt;');
  Add('  TMobileClass(MobileC).{@TMobile_DoIt}DoIt;');
  Add('  TCarClass(MobileC).{@TCar_DoIt}DoIt;');
  Add('  TClass(CarC).{@TObject_DoIt}DoIt;');
  Add('  TMobileClass(CarC).{@TMobile_DoIt}DoIt;');
  Add('  TCarClass(CarC).{@TCar_DoIt}DoIt;');
  ParseProgram;
end;

procedure TTestResolver.TestClassOf_AlwaysForward;
begin
  AddModuleWithIntfImplSrc('unit2.pp',
    LinesToStr([
    'type',
    '  TObject = class',
    '  end;',
    '  TCar = class',
    '  end;']),
    LinesToStr([
    '']));

  StartProgram(true);
  Add('uses unit2;');
  Add('type');
  Add('  {#C}{=A}TCars = class of TCar;');
  Add('  {#A}TCar = class');
  Add('    class var {#B}B: longint;');
  Add('  end;');
  Add('begin');
  Add('  {@C}TCars.{@B}B:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestProperty1;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('  end;');
  Add('  {#A}TClassA = class');
  Add('    {#FB}FB: longint;');
  Add('    property {#B}B: longint read {@FB}FB write {@FB}FB;');
  Add('  end;');
  Add('var');
  Add('  {#v}{=A}v: TClassA;');
  Add('begin');
  Add('  {@v}v.{@b}b:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyAccessorNotInFront;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    property B: longint read FB;');
  Add('    FB: longint;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Identifier not found',PasResolver.nIdentifierNotFound);
end;

procedure TTestResolver.TestPropertyReadAccessorVarWrongType;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: string;');
  Add('    property B: longint read FB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Longint expected, but String found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyReadAccessorProcNotFunc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure GetB;');
  Add('    property B: longint read GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('function expected, but procedure found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyReadAccessorFuncWrongResult;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB: string;');
  Add('    property B: longint read GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('function result longint expected, but function result string found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyReadAccessorFuncWrongArgCount;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB(i: longint): string;');
  Add('    property B: longint read GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('function arg count 0 expected, but 1 found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyReadAccessorFunc;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    function {#GetB}GetB: longint;');
  Add('    property {#B}B: longint read {@GetB}GetB;');
  Add('  end;');
  Add('function TObject.GetB: longint;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('begin');
  Add('  if {@o}o.{@B}B=3 then ;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyWriteAccessorVarWrongType;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: string;');
  Add('    property B: longint write FB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Longint expected, but String found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyWriteAccessorFuncNotProc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function SetB: longint;');
  Add('    property B: longint write SetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('procedure expected, but function found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyWriteAccessorProcWrongArgCount;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure SetB;');
  Add('    property B: longint write SetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Wrong number of parameters specified for call to "SetB"',
    PasResolver.nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestPropertyWriteAccessorProcWrongArg;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure SetB(var Value: longint);');
  Add('    property B: longint write SetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Incompatible type arg no. 1: Got "var ", expected "const "',
    PasResolver.nIncompatibleTypeArgNo);
end;

procedure TTestResolver.TestPropertyWriteAccessorProcWrongArgType;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure SetB(Value: string);');
  Add('    property B: longint write SetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Incompatible type arg no. 1: Got "String", expected "Longint"',
    PasResolver.nIncompatibleTypeArgNo);
end;

procedure TTestResolver.TestPropertyWriteAccessorProc;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    procedure {#SetB}SetB(Value: longint);');
  Add('    property {#B}B: longint write {@SetB}SetB;');
  Add('  end;');
  Add('procedure TObject.SetB(Value: longint);');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('begin');
  Add('  {@o}o.{@B}B:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyTypeless;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#FB}FB: longint;');
  Add('    property {#TOBJ_B}B: longint write {@FB}FB;');
  Add('  end;');
  Add('  {#TA}TClassA = class');
  Add('    {#FC}FC: longint;');
  Add('    property {#TA_B}{@TOBJ_B}B write {@FC}FC;');
  Add('  end;');
  Add('var');
  Add('  {#v}{=TA}v: TClassA;');
  Add('begin');
  Add('  {@v}v.{@TA_B}B:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyTypelessNoAncestorFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('  TClassA = class');
  Add('    property B;');
  Add('  end;');
  Add('begin');
  CheckResolverException('no property found to override',PasResolver.nNoPropertyFoundToOverride);
end;

procedure TTestResolver.TestPropertyStoredAccessorProcNotFunc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    procedure GetB;');
  Add('    property B: longint read FB stored GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('function expected, but procedure found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyStoredAccessorFuncWrongResult;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    function GetB: string;');
  Add('    property B: longint read FB stored GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('function result longint expected, but function result string found',PasResolver.nXExpectedButYFound);
end;

procedure TTestResolver.TestPropertyStoredAccessorFuncWrongArgCount;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    function GetB(i: longint): boolean;');
  Add('    property B: longint read FB stored GetB;');
  Add('  end;');
  Add('begin');
  CheckResolverException('Wrong number of parameters specified for call to "GetB"',
    PasResolver.nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestPropertyArgs1;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB(Index: longint): boolean;');
  Add('    procedure SetB(Index: longint; Value: boolean);');
  Add('    property B[Index: longint]: boolean read GetB write SetB;');
  Add('  end;');
  Add('function TObject.GetB(Index: longint): boolean;');
  Add('begin');
  Add('end;');
  Add('procedure TObject.SetB(Index: longint; Value: boolean);');
  Add('begin');
  Add('end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.B[3]:=true;');
  Add('  if o.B[4] then;');
  Add('  if o.B[5]=true then;');
  Add('  if false=o.B[6] then;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyArgs2;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB(Index: longint; const ID: string): longint;');
  Add('    procedure SetB(Index: longint; const ID: string; Value: longint);');
  Add('    property B[Index: longint; const ID: string]: longint read GetB write SetB;');
  Add('  end;');
  Add('function TObject.GetB(Index: longint; const ID: string): longint;');
  Add('begin');
  Add('end;');
  Add('procedure TObject.SetB(Index: longint; const ID: string; Value: longint);');
  Add('begin');
  Add('end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.B[3,''abc'']:=7;');
  Add('  if o.B[4,'''']=8 then;');
  Add('  if 9=o.B[6,''d''] then;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyArgsWithDefaultsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB(Index: longint): boolean;');
  Add('    procedure SetB(Index: longint; Value: boolean);');
  Add('    property B[Index: longint = 0]: boolean read GetB write SetB;');
  Add('  end;');
  Add('function TObject.GetB(Index: longint): boolean;');
  Add('begin');
  Add('end;');
  Add('procedure TObject.SetB(Index: longint; Value: boolean);');
  Add('begin');
  Add('end;');
  Add('begin');
  CheckParserException('Property arguments can not have default values',
    PParser.nParserPropertyArgumentsCanNotHaveDefaultValues);
end;

procedure TTestResolver.TestProperty_Index;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    {#FItems}FItems: array of string;');
  Add('    function {#GetItems}GetItems(Index: longint): string;');
  Add('    procedure {#SetItems}SetItems(Index: longint; Value: string);');
  Add('    procedure DoIt;');
  Add('    property {#Items}Items[Index: longint]: string read {@GetItems}getitems write {@SetItems}setitems;');
  Add('  end;');
  Add('function tobject.getitems(index: longint): string;');
  Add('begin');
  Add('  Result:={@FItems}fitems[index];');
  Add('end;');
  Add('procedure tobject.setitems(index: longint; value: string);');
  Add('begin');
  Add('  {@FItems}fitems[index]:=value;');
  Add('end;');
  Add('procedure tobject.doit;');
  Add('begin');
  Add('  {@Items}items[1]:={@Items}items[2];');
  Add('  self.{@Items}items[3]:=self.{@Items}items[4];');
  Add('end;');
  Add('var Obj: tobject;');
  Add('begin');
  Add('  obj.{@Items}Items[11]:=obj.{@Items}Items[12];');
  ParseProgram;
end;

procedure TTestResolver.TestProperty_WrongTypeAsIndexFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetItems(Index: string): string;');
  Add('    property Items[Index: string]: string read getitems;');
  Add('  end;');
  Add('function tobject.getitems(index: string): string;');
  Add('begin');
  Add('end;');
  Add('var Obj: tobject;');
  Add('begin');
  Add('  obj.Items[3]:=4;');
  CheckResolverException('Incompatible type arg no. 1: Got "Longint", expected "Index:String"',
    PasResolver.nIncompatibleTypeArgNo);
end;

procedure TTestResolver.TestProperty_Option_ClassPropertyNonStatic;
begin
  ResolverEngine.Options:=ResolverEngine.Options+[proClassPropertyNonStatic];
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    class function GetB: longint;');
  Add('    class procedure SetB(Value: longint);');
  Add('    class property B: longint read GetB write SetB;');
  Add('  end;');
  Add('class function TObject.GetB: longint;');
  Add('begin');
  Add('end;');
  Add('class procedure TObject.SetB(Value: longint);');
  Add('begin');
  Add('end;');
  Add('begin');
  Add('  TObject.B:=4;');
  Add('  if TObject.B=6 then;');
  Add('  if 7=TObject.B then;');
  ParseProgram;
end;

procedure TTestResolver.TestDefaultProperty;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    function GetB(Index: longint): longint;');
  Add('    procedure SetB(Index: longint; Value: longint);');
  Add('    property B[Index: longint]: longint read GetB write SetB; default;');
  Add('  end;');
  Add('function TObject.GetB(Index: longint): longint;');
  Add('begin');
  Add('end;');
  Add('procedure TObject.SetB(Index: longint; Value: longint);');
  Add('begin');
  Add('  if Value=Self[Index] then ;');
  Add('  Self[Index]:=Value;');
  Add('end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o[3]:=4;');
  Add('  if o[5]=6 then;');
  Add('  if 7=o[8] then;');
  ParseProgram;
end;

procedure TTestResolver.TestMissingDefaultProperty;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('  end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  if o[5]=6 then;');
  CheckResolverException('illegal qualifier "["',
    PasResolver.nIllegalQualifier);
end;

procedure TTestResolver.TestPropertyAssign;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    property B: longint read FB write FB;');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('  i: longint;');
  Add('begin');
  Add('  {#a1_read}o.{#a2_assign}B:=i;');
  Add('  i:={#b1_read}o.{#b2_read}B;');
  Add('  if i={#c1_read}o.{#c2_read}B then ;');
  Add('  if {#d1_read}o.{#d2_read}B=3 then ;');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestPropertyAssignReadOnlyFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    property B: longint read FB;');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  o.B:=3;');
  CheckResolverException('No member is provided to access property',PasResolver.nPropertyNotWritable);
end;

procedure TTestResolver.TestProperty_PassAsParam;
begin
  ResolverEngine.Options:=ResolverEngine.Options+[proAllowPropertyAsVarParam];
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FA: longint;');
  Add('    property A: longint read FA write FA;');
  Add('  end;');
  Add('procedure DoIt(i: longint; const j: longint; var k: longint; out l: longint);');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  DoIt({#o1_read}o.{#o_a1_read}a,');
  Add('    {#o2_read}o.{#o_a2_read}a,');
  Add('    {#o3_read}o.{#o_a3_var}a,');
  Add('    {#o4_read}o.{#o_a4_out}a);');
  Add('  with o do');
  Add('    DoIt({#w_a1_read}a,');
  Add('      {#w_a2_read}a,');
  Add('      {#w_a3_var}a,');
  Add('      {#w_a4_out}a);');
  ParseProgram;
  CheckAccessMarkers;
end;

procedure TTestResolver.TestPropertyReadNonReadableFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    FB: longint;');
  Add('    property B: longint write FB;');
  Add('  end;');
  Add('var');
  Add('  o: TObject;');
  Add('begin');
  Add('  if o.B=3 then;');
  CheckResolverException('not readable',PasResolver.nNotReadable);
end;

procedure TTestResolver.TestWithBlock1;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#TOBJ_A}A: longint;');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#a}a: longint;');
  Add('begin');
  Add('  {@a}a:=1;');
  Add('  with {@o}o do');
  Add('    {@TOBJ_A}a:=2;');
  ParseProgram;
end;

procedure TTestResolver.TestWithBlock2;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#TOBJ_i}i: longint;');
  Add('  end;');
  Add('  {#TA}TClassA = class');
  Add('    {#TA_j}j: longint;');
  Add('    {#TA_b}{=TA}b: TClassA;');
  Add('  end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#a}{=TA}a: TClassA;');
  Add('  {#i}i: longint;');
  Add('begin');
  Add('  {@i}i:=1;');
  Add('  with {@o}o do');
  Add('    {@TOBJ_i}i:=2;');
  Add('  {@i}i:=1;');
  Add('  with {@o}o,{@a}a do begin');
  Add('    {@TOBJ_i}i:=3;');
  Add('    {@TA_j}j:=4;');
  Add('    {@TA_b}b:={@a}a;');
  Add('  end;');
  ParseProgram;
end;

procedure TTestResolver.TestWithBlockFuncResult;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#TOBJ_i}i: longint;');
  Add('  end;');
  Add('  {#TA}TClassA = class');
  Add('    {#TA_j}j: longint;');
  Add('    {#TA_b}{=TA}b: TClassA;');
  Add('  end;');
  Add('function {#GiveA}Give: TClassA;');
  Add('begin');
  Add('end;');
  Add('function {#GiveB}Give(i: longint): TClassA;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#a}{=TA}a: TClassA;');
  Add('  {#i}i: longint;');
  Add('begin');
  Add('  with {@GiveA}Give do {@TOBJ_i}i:=3;');
  Add('  with {@GiveA}Give() do {@TOBJ_i}i:=3;');
  Add('  with {@GiveB}Give(2) do {@TOBJ_i}i:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestWithBlockConstructor;
begin
  StartProgram(false);
  Add('type');
  Add('  {#TOBJ}TObject = class');
  Add('    {#TOBJ_i}i: longint;');
  Add('  end;');
  Add('  {#TA}TClassA = class');
  Add('    {#TA_j}j: longint;');
  Add('    {#TA_b}{=TA}b: TClassA;');
  Add('    constructor {#A_CreateA}Create;');
  Add('    constructor {#A_CreateB}Create(i: longint);');
  Add('  end;');
  Add('constructor TClassA.Create;');
  Add('begin');
  Add('end;');
  Add('constructor TClassA.Create(i: longint);');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  {#o}{=TOBJ}o: TObject;');
  Add('  {#a}{=TA}a: TClassA;');
  Add('  {#i}i: longint;');
  Add('begin');
  Add('  with TClassA.{@A_CreateA}Create do {@TOBJ_i}i:=3;');
  Add('  with TClassA.{@A_CreateA}Create() do {@TOBJ_i}i:=3;');
  Add('  with TClassA.{@A_CreateB}Create(2) do {@TOBJ_i}i:=3;');
  ParseProgram;
end;

procedure TTestResolver.TestDynArrayOfLongint;
begin
  StartProgram(false);
  Add('type TIntArray = array of longint;');
  Add('var a: TIntArray;');
  Add('begin');
  Add('  a:=nil;');
  Add('  if a=nil then ;');
  Add('  if nil=a then ;');
  Add('  SetLength(a,3);');
  Add('  a[0]:=1;');
  Add('  a[1]:=length(a);');
  Add('  a[2]:=a[0];');
  Add('  if a[3]=a[4] then ;');
  Add('  a[a[5]]:=a[a[6]];');
  ParseProgram;
end;

procedure TTestResolver.TestStaticArray;
begin
  StartProgram(false);
  Add('type');
  Add('  TArrA = array[1..2] of longint;');
  Add('  TArrB = array[char] of boolean;');
  Add('  TArrC = array[byte,''a''..''z''] of longint;');
  Add('var');
  Add('  a: TArrA;');
  Add('  b: TArrB;');
  Add('  c: TArrC;');
  Add('begin');
  Add('  a[1]:=1;');
  Add('  if a[2]=length(a) then ;');
  Add('  b[''x'']:=true;');
  Add('  if b[''y''] then ;');
  Add('  c[3,''f'']:=1;');
  Add('  if c[4,''g'']=a[1] then ;');
  ParseProgram;
end;

procedure TTestResolver.TestArrayOfArray;
begin
  StartProgram(false);
  Add('type');
  Add('  TArrA = array[byte] of longint;');
  Add('  TArrB = array[smallint] of TArrA;');
  Add('var');
  Add('  b: TArrB;');
  Add('begin');
  Add('  b[1][2]:=5;');
  Add('  b[1,2]:=5;');
  Add('  if b[2,1]=b[0,1] then ;');
  ParseProgram;
end;

procedure TTestResolver.TestFunctionReturningArray;
begin
  StartProgram(false);
  Add('type');
  Add('  TArrA = array[1..20] of longint;');
  Add('  TArrB = array of TArrA;');
  Add('function FuncC: TArrB;');
  Add('begin');
  Add('  SetLength(Result,3);');
  Add('end;');
  Add('begin');
  Add('  FuncC[2,4]:=6;');
  Add('  FuncC()[1,3]:=5;');
  ParseProgram;
end;

procedure TTestResolver.TestLowHighArray;
begin
  StartProgram(false);
  Add('type');
  Add('  TArrA = array[char] of longint;');
  Add('  TArrB = array of TArrA;');
  Add('var');
  Add('  c: char;');
  Add('  i: longint;');
  Add('begin');
  Add('  for c:=low(TArrA) to High(TArrA) do ;');
  Add('  for i:=low(TArrB) to High(TArrB) do ;');
  ParseProgram;
end;

procedure TTestResolver.TestPropertyOfTypeArray;
begin
  StartProgram(false);
  Add('type');
  Add('  TArray = array of longint;');
  Add('  TObject = class');
  Add('    FItems: TArray;');
  Add('    function GetItems: TArray;');
  Add('    procedure SetItems(Value: TArray);');
  Add('    property Items: TArray read FItems write FItems;');
  Add('    property Numbers: TArray read GetItems write SetItems;');
  Add('  end;');
  Add('function TObject.GetItems: TArray;');
  Add('begin');
  Add('  Result:=FItems;');
  Add('end;');
  Add('procedure TObject.SetItems(Value: TArray);');
  Add('begin');
  Add('  FItems:=Value;');
  Add('end;');
  Add('var Obj: TObject;');
  Add('begin');
  Add('  Obj.Items[3]:=4;');
  Add('  if Obj.Items[5]=6 then;');
  Add('  Obj.Numbers[7]:=8;');
  Add('  if Obj.Numbers[9]=10 then;');
  ParseProgram;
end;

procedure TTestResolver.TestArrayElementFromFuncResult_AsParams;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  ActualImplicitCall: Boolean;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
begin
  StartProgram(false);
  Add('type Integer = longint;');
  Add('type TArrayInt = array of integer;');
  Add('function GetArr(vB: integer = 0): tarrayint;');
  Add('begin');
  Add('end;');
  Add('procedure DoIt(vG: integer);');
  Add('begin');
  Add('end;');
  Add('begin');
  Add('  doit({#a}getarr[1+1]);');
  Add('  doit({#b}getarr()[2+1]);');
  Add('  doit({#b}getarr(7)[3+1]);');
  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestArrayElementFromFuncResult_AsParams ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualImplicitCall:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestArrayElementFromFuncResult_AsParams ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        if rrfImplicitCallWithoutParams in Ref.Flags then
          ActualImplicitCall:=true;
        break;
        end;
      case aMarker^.Identifier of
      'a':
        if not ActualImplicitCall then
          RaiseErrorAtSrcMarker('expected rrfImplicitCallWithoutParams at "#'+aMarker^.Identifier+'"',aMarker);
      else
        if ActualImplicitCall then
          RaiseErrorAtSrcMarker('expected no rrfImplicitCallWithoutParams at "#'+aMarker^.Identifier+'"',aMarker);
      end;
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestArrayEnumTypeRange;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('  TEnumArray = array[TEnum] of longint;');
  Add('var');
  Add('  e: TEnum;');
  Add('  i: longint;');
  Add('  a: TEnumArray;');
  Add('  names: array[TEnum] of string = (''red'',''blue'');');
  Add('begin');
  Add('  e:=low(a);');
  Add('  e:=high(a);');
  Add('  i:=length(a);');
  Add('  i:=a[red];');
  Add('  a[e]:=a[e];');
  ParseProgram;
end;

procedure TTestResolver.TestArrayEnumTypeConstNotEnoughValuesFail1;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('var');
  Add('  a: array[TEnum] of string = (''red'');');
  Add('begin');
  CheckResolverException('Expect 2 array elements, but found 1',nExpectXArrayElementsButFoundY);
end;

procedure TTestResolver.TestArrayEnumTypeConstNotEnoughValuesFail2;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue,green);');
  Add('var');
  Add('  a: array[TEnum] of string = (''red'',''blue'');');
  Add('begin');
  CheckResolverException('Expect 3 array elements, but found 2',nExpectXArrayElementsButFoundY);
end;

procedure TTestResolver.TestArrayEnumTypeConstWrongTypeFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('var');
  Add('  a: array[TEnum] of string = (1,2);');
  Add('begin');
  CheckResolverException('Incompatible types: got "Longint" expected "String"',
    nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestArrayEnumTypeConstNonConstFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('var');
  Add('  s: string;');
  Add('  a: array[TEnum] of string = (''red'',s);');
  Add('begin');
  CheckResolverException('Constant expression expected',
    nConstantExpressionExpected);
end;

procedure TTestResolver.TestArrayEnumTypeSetLengthFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('var');
  Add('  a: array[TEnum] of longint;');
  Add('begin');
  Add('  SetLength(a,1);');
  CheckResolverException('Incompatible type arg no. 1: Got "array[] of Longint", expected "string or dynamic array variable',
    nIncompatibleTypeArgNo);
end;

procedure TTestResolver.TestArray_AssignNilToStaticArrayFail1;
begin
  StartProgram(false);
  Add('type');
  Add('  TEnum = (red,blue);');
  Add('var');
  Add('  a: array[TEnum] of longint;');
  Add('begin');
  Add('  a:=nil;');
  CheckResolverException('Incompatible types: got "nil" expected "array type"',
    nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestArray_SetLengthProperty;
begin
  ResolverEngine.Options:=ResolverEngine.Options+[proAllowPropertyAsVarParam];
  StartProgram(false);
  Add('type');
  Add('  TArrInt = array of longint;');
  Add('  TObject = class');
  Add('    function GetColors: TArrInt; external name ''GetColors'';');
  Add('    procedure SetColors(const Value: TArrInt); external name ''SetColors'';');
  Add('    property Colors: TArrInt read GetColors write SetColors;');
  Add('  end;');
  Add('procedure DoIt(var i: longint; out j: longint; const k: longint); begin end;');
  Add('var Obj: TObject;');
  Add('begin');
  Add('  SetLength(Obj.Colors,2);');
  Add('  DoIt(Obj.Colors[1],Obj.Colors[2],Obj.Colors[3]);');
  ParseProgram;
end;

procedure TTestResolver.TestArray_PassArrayElementToVarParam;
begin
  StartProgram(false);
  Add('type');
  Add('  TArrInt = array of longint;');
  Add('procedure DoIt(var i: longint; out j: longint; const k: longint); begin end;');
  Add('var a: TArrInt;');
  Add('begin');
  Add('  DoIt(a[1],a[2],a[3]);');
  ParseProgram;
end;

procedure TTestResolver.TestProcTypesAssignObjFPC;
begin
  StartProgram(false);
  Add('type');
  Add('  TProcedure = procedure;');
  Add('  TFunctionInt = function:longint;');
  Add('  TFunctionIntFunc = function:TFunctionInt;');
  Add('  TFunctionIntFuncFunc = function:TFunctionIntFunc;');
  Add('function GetNumber: longint;');
  Add('begin');
  Add('  Result:=3;');
  Add('end;');
  Add('function GetNumberFunc: TFunctionInt;');
  Add('begin');
  Add('  Result:=@GetNumber;');
  Add('end;');
  Add('function GetNumberFuncFunc: TFunctionIntFunc;');
  Add('begin');
  Add('  Result:=@GetNumberFunc;');
  Add('end;');
  Add('var');
  Add('  i: longint;');
  Add('  f: TFunctionInt;');
  Add('  ff: TFunctionIntFunc;');
  Add('begin');
  Add('  i:=GetNumber; // omit ()');
  Add('  i:=GetNumber();');
  Add('  i:=GetNumberFunc()();');
  Add('  i:=GetNumberFuncFunc()()();');
  Add('  if i=GetNumberFunc()() then ;');
  Add('  if GetNumberFunc()()=i then ;');
  Add('  if i=GetNumberFuncFunc()()() then ;');
  Add('  if GetNumberFuncFunc()()()=i then ;');
  Add('  f:=nil;');
  Add('  if f=nil then ;');
  Add('  if nil=f then ;');
  Add('  if Assigned(f) then ;');
  Add('  f:=f;');
  Add('  f:=@GetNumber;');
  Add('  f:=GetNumberFunc; // not in Delphi');
  Add('  f:=GetNumberFunc(); // not in Delphi');
  Add('  f:=GetNumberFuncFunc()();');
  Add('  if f=f then ;');
  Add('  if i=f then ;');
  Add('  if i=f() then ;');
  Add('  if f()=i then ;');
  Add('  if f()=f() then ;');
  Add('  if f=@GetNumber then ;');
  Add('  if @GetNumber=f then ;');
  Add('  if f=GetNumberFunc then ;');
  Add('  if f=GetNumberFunc() then ;');
  Add('  if f=GetNumberFuncFunc()() then ;');
  Add('  ff:=nil;');
  Add('  if ff=nil then ;');
  Add('  if nil=ff then ;');
  Add('  ff:=ff;');
  Add('  if ff=ff then ;');
  Add('  ff:=@GetNumberFunc;');
  Add('  ff:=GetNumberFuncFunc; // not in Delphi');
  Add('  ff:=GetNumberFuncFunc();');
  ParseProgram;
end;

procedure TTestResolver.TestMethodTypesAssignObjFPC;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class;');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('  TObject = class');
  Add('    FOnClick: TNotifyEvent;');
  Add('    procedure SetOnClick(const Value: TNotifyEvent);');
  Add('    procedure Notify(Sender: TObject);');
  Add('    property OnClick: TNotifyEvent read FOnClick write SetOnClick;');
  Add('  end;');
  Add('procedure TObject.SetOnClick(const Value: TNotifyEvent);');
  Add('begin');
  Add('  if FOnClick=Value then exit;');
  Add('  FOnClick:=Value;');
  Add('end;');
  Add('procedure TObject.Notify(Sender: TObject);');
  Add('begin');
  Add('  if Assigned(OnClick) and (OnClick<>@Notify) then begin');
  Add('    OnClick(Sender);');
  Add('    OnClick(Self);');
  Add('    Self.OnClick(nil);');
  Add('  end;');
  Add('  if OnClick=@Self.Notify then ;');
  Add('  if Self.OnClick=@Self.Notify then ;');
  Add('end;');
  Add('var o: TObject;');
  Add('begin');
  Add('  o.OnClick:=@o.Notify');
  Add('  o.OnClick(nil);');
  Add('  o.OnClick(o);');
  Add('  o.SetOnClick(@o.Notify);');
  ParseProgram;
end;

procedure TTestResolver.TestProcTypeCall;
var
  aMarker: PSrcMarker;
  Elements: TFPList;
  ActualImplicitCallWithoutParams: Boolean;
  i: Integer;
  El: TPasElement;
  Ref: TResolvedReference;
begin
  StartProgram(false);
  Add('type');
  Add('  TFuncInt = function(vI: longint = 1):longint;');
  Add('  TFuncFuncInt = function(vI: longint = 1): TFuncInt;');
  Add('procedure DoI(vI: longint); begin end;');
  Add('procedure DoFConst(const vI: tfuncint); begin end;');
  Add('procedure DoFVar(var vI: tfuncint); begin end;');
  Add('procedure DoFDefault(vI: tfuncint); begin end;');
  Add('var');
  Add('  i: longint;');
  Add('  f: tfuncint;');
  Add('begin');
  Add('  {#a}f;');
  Add('  {#b}f();');
  Add('  {#c}f(2);');
  Add('  i:={#d}f;');
  Add('  i:={#e}f();');
  Add('  i:={#f}f(2);');
  Add('  doi({#g}f);');
  Add('  doi({#h}f());');
  Add('  doi({#i}f(2));');
  Add('  dofconst({#j}f);');
  ParseProgram;

  aMarker:=FirstSrcMarker;
  while aMarker<>nil do
    begin
    //writeln('TTestResolver.TestProcTypeCall ',aMarker^.Identifier,' ',aMarker^.StartCol,' ',aMarker^.EndCol);
    Elements:=FindElementsAt(aMarker);
    try
      ActualImplicitCallWithoutParams:=false;
      for i:=0 to Elements.Count-1 do
        begin
        El:=TPasElement(Elements[i]);
        //writeln('TTestResolver.TestProcTypeCall ',aMarker^.Identifier,' ',i,'/',Elements.Count,' El=',GetObjName(El),' ',GetObjName(El.CustomData));
        if not (El.CustomData is TResolvedReference) then continue;
        Ref:=TResolvedReference(El.CustomData);
        //writeln('TTestResolver.TestProcTypeCall ',GetObjName(Ref.Declaration),' rrfImplicitCallWithoutParams=',rrfImplicitCallWithoutParams in Ref.Flags);
        if rrfImplicitCallWithoutParams in Ref.Flags then
          ActualImplicitCallWithoutParams:=true;
        break;
        end;
      case aMarker^.Identifier of
      'a','d','g':
        if not ActualImplicitCallWithoutParams then
          RaiseErrorAtSrcMarker('expected implicit call at "#'+aMarker^.Identifier+'"',aMarker);
      else
        if ActualImplicitCallWithoutParams then
          RaiseErrorAtSrcMarker('expected no implicit call at "#'+aMarker^.Identifier+'"',aMarker);
      end;
    finally
      Elements.Free;
    end;
    aMarker:=aMarker^.Next;
    end;
end;

procedure TTestResolver.TestProcType_FunctionFPC;
begin
  StartProgram(false);
  Add('type');
  Add('  TFuncInt = function(vA: longint = 1): longint;');
  Add('function DoIt(vI: longint): longint;');
  Add('begin end;');
  Add('var');
  Add('  b: boolean;');
  Add('  vP, vQ: tfuncint;');
  Add('begin');
  Add('  vp:=nil;');
  Add('  vp:=vp;');
  Add('  vp:=@doit;'); // ok in fpc and delphi
  //Add('  vp:=doit;'); // illegal in fpc, ok in delphi
  Add('  vp;'); // ok in fpc and delphi
  Add('  vp();');
  Add('  vp(2);');
  Add('  b:=vp=nil;'); // ok in fpc, illegal in delphi
  Add('  b:=nil=vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp=vq;'); // in fpc compare proctypes, in delphi compare results
  Add('  b:=vp=@doit;'); // ok in fpc, illegal in delphi
  Add('  b:=@doit=vp;'); // ok in fpc, illegal in delphi
  //Add('  b:=vp=3;'); // illegal in fpc, ok in delphi
  Add('  b:=4=vp;'); // illegal in fpc, ok in delphi
  Add('  b:=vp<>nil;'); // ok in fpc, illegal in delphi
  Add('  b:=nil<>vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp<>vq;'); // in fpc compare proctypes, in delphi compare results
  Add('  b:=vp<>@doit;'); // ok in fpc, illegal in delphi
  Add('  b:=@doit<>vp;'); // ok in fpc, illegal in delphi
  //Add('  b:=vp<>5;'); // illegal in fpc, ok in delphi
  Add('  b:=6<>vp;'); // illegal in fpc, ok in delphi
  Add('  b:=Assigned(vp);');
  //Add('  doit(vp);'); // illegal in fpc, ok in delphi
  Add('  doit(vp());'); // ok in fpc and delphi
  Add('  doit(vp(2));'); // ok in fpc and delphi
  ParseProgram;
end;

procedure TTestResolver.TestProcType_FunctionDelphi;
begin
  StartProgram(false);
  Add('{$mode Delphi}');
  Add('type');
  Add('  TFuncInt = function(vA: longint = 1): longint;');
  Add('function DoIt(vI: longint): longint;');
  Add('begin end;');
  Add('var');
  Add('  b: boolean;');
  Add('  vP, vQ: tfuncint;');
  Add('begin');
  Add('  vp:=nil;');
  Add('  vp:=vp;');
  Add('  vp:=@doit;'); // ok in fpc and delphi
  Add('  vp:=doit;'); // illegal in fpc, ok in delphi
  Add('  vp;'); // ok in fpc and delphi
  Add('  vp();');
  Add('  vp(2);');
  //Add('  b:=vp=nil;'); // ok in fpc, illegal in delphi
  //Add('  b:=nil=vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp=vq;'); // in fpc compare proctypes, in delphi compare results
  //Add('  b:=vp=@doit;'); // ok in fpc, illegal in delphi
  //Add('  b:=@doit=vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp=3;'); // illegal in fpc, ok in delphi
  Add('  b:=4=vp;'); // illegal in fpc, ok in delphi
  //Add('  b:=vp<>nil;'); // ok in fpc, illegal in delphi
  //Add('  b:=nil<>vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp<>vq;'); // in fpc compare proctypes, in delphi compare results
  //Add('  b:=vp<>@doit;'); // ok in fpc, illegal in delphi
  //Add('  b:=@doit<>vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp<>5;'); // illegal in fpc, ok in delphi
  Add('  b:=6<>vp;'); // illegal in fpc, ok in delphi
  Add('  b:=Assigned(vp);');
  Add('  doit(vp);'); // illegal in fpc, ok in delphi
  Add('  doit(vp());'); // ok in fpc and delphi
  Add('  doit(vp(2));'); // ok in fpc and delphi  *)
  ParseProgram;
end;

procedure TTestResolver.TestProcType_MethodFPC;
begin
  StartProgram(false);
  Add('type');
  Add('  TFuncInt = function(vA: longint = 1): longint of object;');
  Add('  TObject = class');
  Add('    function DoIt(vA: longint = 1): longint;');
  Add('  end;');
  Add('function tobject.doit(vA: longint): longint;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  Obj: TObject;');
  Add('  vP: tfuncint;');
  Add('  b: boolean;');
  Add('begin');
  Add('  vp:=@obj.doit;'); // ok in fpc and delphi
  //Add('  vp:=obj.doit;'); // illegal in fpc, ok in delphi
  Add('  vp;'); // ok in fpc and delphi
  Add('  vp();');
  Add('  vp(2);');
  Add('  b:=vp=@obj.doit;'); // ok in fpc, illegal in delphi
  Add('  b:=@obj.doit=vp;'); // ok in fpc, illegal in delphi
  Add('  b:=vp<>@obj.doit;'); // ok in fpc, illegal in delphi
  Add('  b:=@obj.doit<>vp;'); // ok in fpc, illegal in delphi
  ParseProgram;
end;

procedure TTestResolver.TestProcType_MethodDelphi;
begin
  StartProgram(false);
  Add('{$mode delphi}');
  Add('type');
  Add('  TFuncInt = function(vA: longint = 1): longint of object;');
  Add('  TObject = class');
  Add('    function DoIt(vA: longint = 1): longint;');
  Add('  end;');
  Add('function tobject.doit(vA: longint): longint;');
  Add('begin');
  Add('end;');
  Add('var');
  Add('  Obj: TObject;');
  Add('  vP: tfuncint;');
  Add('  b: boolean;');
  Add('begin');
  Add('  vp:=@obj.doit;'); // ok in fpc and delphi
  Add('  vp:=obj.doit;'); // illegal in fpc, ok in delphi
  Add('  vp;'); // ok in fpc and delphi
  Add('  vp();');
  Add('  vp(2);');
  //Add('  b:=vp=@obj.doit;'); // ok in fpc, illegal in delphi
  //Add('  b:=@obj.doit=vp;'); // ok in fpc, illegal in delphi
  //Add('  b:=vp<>@obj.doit;'); // ok in fpc, illegal in delphi
  //Add('  b:=@obj.doit<>vp;'); // ok in fpc, illegal in delphi
  ParseProgram;
end;

procedure TTestResolver.TestAssignProcToMethodFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('procedure ProcA(Sender: TObject);');
  Add('begin end;');
  Add('var n: TNotifyEvent;');
  Add('begin');
  Add('  n:=@ProcA;');
  CheckResolverException('Incompatible types: got "procedure(class TObject)" expected "n:procedure(class TObject) of object"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestAssignMethodToProcFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class');
  Add('    procedure ProcA(Sender: TObject);');
  Add('  end;');
  Add('  TNotifyProc = procedure(Sender: TObject);');
  Add('procedure TObject.ProcA(Sender: TObject);');
  Add('begin end;');
  Add('var');
  Add('  n: TNotifyProc;');
  Add('  o: TObject;');
  Add('begin');
  Add('  n:=@o.ProcA;');
  CheckResolverException('Incompatible types: got "procedure(class TObject) of object" expected "n:procedure(class TObject)"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestAssignProcToFunctionFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TFuncInt = function(i: longint): longint;');
  Add('procedure ProcA(i: longint);');
  Add('begin end;');
  Add('var p: TFuncInt;');
  Add('begin');
  Add('  p:=@ProcA;');
  CheckResolverException('Incompatible types: got "procedure(Longint)" expected "p:function(Longint)"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestAssignProcWrongArgsFail;
begin
  StartProgram(false);
  Add('type');
  Add('  TProcInt = procedure(i: longint);');
  Add('procedure ProcA(i: string);');
  Add('begin end;');
  Add('var p: TProcInt;');
  Add('begin');
  Add('  p:=@ProcA;');
  CheckResolverException('Incompatible types: got "procedure(String)" expected "p:procedure(Longint)"',
    PasResolver.nIncompatibleTypesGotExpected);
end;

procedure TTestResolver.TestArrayOfProc;
begin
  StartProgram(false);
  Add('type');
  Add('  TObject = class end;');
  Add('  TNotifyProc = function(Sender: TObject = nil): longint;');
  Add('  TProcArray = array of TNotifyProc;');
  Add('function ProcA(Sender: TObject): longint;');
  Add('begin end;');
  Add('var');
  Add('  a: TProcArray;');
  Add('  p: TNotifyProc;');
  Add('begin');
  Add('  a[0]:=@ProcA;');
  Add('  if a[1]=@ProcA then ;');
  Add('  if @ProcA=a[2] then ;');
  // Add('  a[3];'); ToDo
  Add('  a[3](nil);');
  Add('  if a[4](nil)=5 then ;');
  Add('  if 6=a[7](nil) then ;');
  Add('  a[8]:=a[9];');
  Add('  p:=a[10];');
  Add('  a[11]:=p;');
  Add('  if a[12]=p then ;');
  Add('  if p=a[13] then ;');
  ParseProgram;
end;

procedure TTestResolver.TestProcType_Assigned;
begin
  StartProgram(false);
  Add('type');
  Add('  TFuncInt = function(i: longint): longint;');
  Add('function ProcA(i: longint): longint;');
  Add('begin end;');
  Add('var');
  Add('  a: array of TFuncInt;');
  Add('  p: TFuncInt;');
  Add('begin');
  Add('  if Assigned(p) then ;');
  Add('  if Assigned(a[1]) then ;');
  ParseProgram;
end;

procedure TTestResolver.TestProcType_TNotifyEvent;
begin
  StartProgram(true,[supTObject]);
  Add('type');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('  TButton = class(TObject)');
  Add('  private');
  Add('    FOnClick: TNotifyEvent;');
  Add('  published');
  Add('    property OnClick: TNotifyEvent read FOnClick write FOnClick;');
  Add('  end;');
  Add('  TApplication = class(TObject)');
  Add('    procedure BtnClickHandler(Sender: TObject); external name ''BtnClickHandler'';');
  Add('  end;');
  Add('var ');
  Add('  App: TApplication;');
  Add('  Button1: TButton;');
  Add('begin');
  Add('  Button1.OnClick := @App.BtnClickHandler;');
  ParseProgram;
end;

procedure TTestResolver.TestProcType_TNotifyEvent_NoAtFPC_Fail1;
begin
  StartProgram(true,[supTObject]);
  Add('type');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('  TButton = class(TObject)');
  Add('  private');
  Add('    FOnClick: TNotifyEvent;');
  Add('  published');
  Add('    property OnClick: TNotifyEvent read FOnClick write FOnClick;');
  Add('  end;');
  Add('  TApplication = class(TObject)');
  Add('    procedure BtnClickHandler(Sender: TObject); external name ''BtnClickHandler'';');
  Add('  end;');
  Add('var ');
  Add('  App: TApplication;');
  Add('  Button1: TButton;');
  Add('begin');
  Add('  Button1.OnClick := App.BtnClickHandler;');
  CheckResolverException('Wrong number of parameters specified for call to "BtnClickHandler"',
    nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestProcType_TNotifyEvent_NoAtFPC_Fail2;
begin
  StartProgram(true,[supTObject]);
  Add('type');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('  TButton = class(TObject)');
  Add('  private');
  Add('    FOnClick: TNotifyEvent;');
  Add('  published');
  Add('    property OnClick: TNotifyEvent read FOnClick write FOnClick;');
  Add('  end;');
  Add('  TApplication = class(TObject)');
  Add('    procedure BtnClickHandler(Sender: TObject); external name ''BtnClickHandler'';');
  Add('  end;');
  Add('var ');
  Add('  App: TApplication;');
  Add('  Button1: TButton;');
  Add('begin');
  Add('  Button1.OnClick := App.BtnClickHandler();');
  CheckResolverException('Wrong number of parameters specified for call to "BtnClickHandler"',
    nWrongNumberOfParametersForCallTo);
end;

procedure TTestResolver.TestProcType_TNotifyEvent_NoAtFPC_Fail3;
begin
  StartProgram(true,[supTObject]);
  Add('type');
  Add('  TNotifyEvent = procedure(Sender: TObject) of object;');
  Add('  TButton = class(TObject)');
  Add('  private');
  Add('    FOnClick: TNotifyEvent;');
  Add('  published');
  Add('    property OnClick: TNotifyEvent read FOnClick write FOnClick;');
  Add('  end;');
  Add('  TApplication = class(TObject)');
  Add('    procedure BtnClickHandler(Sender: TObject); external name ''BtnClickHandler'';');
  Add('  end;');
  Add('var ');
  Add('  App: TApplication;');
  Add('  Button1: TButton;');
  Add('begin');
  Add('  Button1.OnClick := @App.BtnClickHandler();');
  CheckResolverException('Wrong number of parameters specified for call to "BtnClickHandler"',
    nWrongNumberOfParametersForCallTo);
end;

initialization
  RegisterTests([TTestResolver]);

end.

