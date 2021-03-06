unit XSIDTypes;

{$INCLUDE XSID.inc}

interface

uses
	Classes, SyncObjs, IniFiles, C64Types;

const
	VAL_MAX_BUFFERSIZE = 65536;

type
	TXSIDSampleRate = (rsr11025, rsr22050, rsr44100, rsr48000, rsr96000);
	TXSIDBufferSize = (rsbImmediate, rsbTiny, rsbSmall, rsbMedium, rsbLarge,
			rsbExtra, rsbHuge);
//	sampling_method = (SAMPLE_INTERPOLATE = 1, SAMPLE_RESAMPLE_INTERPOLATE);
	TXSIDInterpolation = (rsiDecimate = 1, rsiResample);

	TXSIDModelType3 = (rm3R2, rm3R4);
	TXSIDModelType4 = (rm4R5);

//dengland Added these
	PXSIDFloat = ^TXSIDFloat;
	TXSIDFloat = TC64Float;
//	PArrXSIDFloat = ^TArrRXSIDFloat;
//	TArrXSIDFloat = array[0..VAL_MAX_BUFFERSIZE - 1] of TXSIDFloat;
	PArrSmallInt = ^TArrSmallInt;
	TArrSmallInt = array[0..VAL_MAX_BUFFERSIZE - 1] of SmallInt;

//	TArrDac = array[0..11] of TXSIDFloat;

	TXSIDCtxReg = record
		isUsed: Boolean;
		value: Byte;
	end;

	TXSIDContext = array[0..24] of TXSIDCtxReg;


const
//	siddefs-fp.h
//	M_PI = 3.14159265358979323846;
//	M_LN2 = 0.69314718055994530942;

	ARR_VAL_TYPE3PROPS: array[TXSIDModelType3] of Double = (
//		rm3R2
		0.01,
//      rm3R4
		0.50);

	ARR_VAL_TYPE4PROPS: array[TXSIDModelType4] of Double = (
//		rm4R5
		12500);

	ARR_STR_MODELTYPE3: array[TXSIDModelType3] of string = (
			'R2', 'R4');

	ARR_STR_MODELTYPE4: array[TXSIDModelType4] of string = (
			'R5');

	ARR_VAL_SAMPLERATE: array[TXSIDSampleRate] of Cardinal = (
			11025, 22050, 44100, 48000, 96000);

	ARR_VAL_BUFFERFACT: array[TXSIDBufferSize] of Cardinal = (
			1, 2, 4, 6, 8, 12, 16);

	VAL_DEF_FILTENABLE = True;
	VAL_DEF_DIGIBSTENB = False;

	VAL_DEF_SAMPLERATE = rsr44100;
	VAL_DEF_BUFFERSIZE = rsbMedium;
	VAL_DEF_INTERPLATE = rsiResample;

type
{ TXSIDEventPool }

	TXSIDEventData = record
		reg,
		val: TC64Uns8;
	end;

	TXSIDEventArr = array of TXSIDEventData;

	PXSIDEvent = ^TXSIDEvent;
	TXSIDEvent = record
		offs: TC64CycCnt;
		data: TXSIDEventData;
		next,
		prev: PXSIDEvent;
	end;

	TXSIDEventPool = class(TObject)
	protected
		FLock: TCriticalSection;
		FAllocList: TList;
		FAvailList: TList;

	public
		constructor Create;
		destructor  Destroy; override;

		function  AllocateEvent: PXSIDEvent;
		procedure ReleaseEvent(AEvent: PXSIDEvent);
		procedure Clear;
	end;

{ TXSIDAudioRenderer }

	TXSIDAudioRenderer = class(TObject)
	public
		constructor Create(const ASampleRate: TXSIDSampleRate;
				const AFrameRate: Cardinal;
				const ABufferSize: TXSIDBufferSize;
				const AParams: TStrings; var ABuffer: PArrSmallInt;
				var ASize: Cardinal); virtual;

		class function  GetName: AnsiString; virtual; abstract;
		class function  GetRequireAllData: Boolean; virtual;
		class function  GetWantPlatformDefault: Boolean; virtual;
		class function  GetIsRealTime: Boolean; virtual;

		class procedure FillParameterNames(const AStrings: TStrings); virtual;

		procedure SwapBuffers(var ABuffer: PArrSmallInt;
				const ASize: Integer); virtual; abstract;
		procedure TransferBuffer(const ABuffer: PArrSmallInt;
				var ASize: Integer); virtual; abstract;

		procedure Pause(var ABuffer: PArrSmallInt); virtual; abstract;
		procedure Play(var ABuffer: PArrSmallInt); virtual; abstract;

		property  Name: AnsiString read GetName;
		property  RequireAllData: Boolean read GetRequireAllData;
		property  WantPlatformDefault: Boolean read GetWantPlatformDefault;
		property  IsRealTime: Boolean read GetIsRealTime;
	end;

	TXSIDAudioRendererClass = class of TXSIDAudioRenderer;

{ TXSIDAudioRenderers }

	TXSIDAudioRenderers = class(TObject)
	private
		FList: TList;

	protected
		function  GetCount: Integer;
		function  GetItem(AIndex: Integer): TXSIDAudioRendererClass;
		procedure AddItem(const AItem: TXSIDAudioRendererClass);
		function  GetDefaultRenderer: TXSIDAudioRendererClass;

	public
		constructor Create;
		destructor  Destroy; override;

		function  IndexOf(const AItem: TXSIDAudioRendererClass): Integer;
		function  ItemByName(const AName: AnsiString): TXSIDAudioRendererClass;

		property  Count: Integer read GetCount;
		property  Items[AIndex: Integer]: TXSIDAudioRendererClass read GetItem; default;
		property  DefaultRenderer: TXSIDAudioRendererClass read GetDefaultRenderer;
	end;

{ TXSIDConfig }
	TXSIDConfig = class;

{ TXSIDConfigFilter }

	TXSIDConfigFilter = class(TObject)
	protected
		FOwner: TXSIDConfig;
		FCustom: Boolean;

		procedure SetChanged(AValue: Boolean);

		procedure SetCustom(AValue: Boolean);
		function  GetCustom: Boolean;

		procedure Lock;
		procedure Unlock;

		procedure DoSetTypeSettings; virtual; abstract;
		procedure DoSetSystemDefaults; virtual;

		procedure DoAssign(AFilter: TXSIDConfigFilter); virtual; abstract;
		procedure Assign(AFilter: TXSIDConfigFilter);

		procedure LoadFromIniFile(const AIniFile: TIniFile); virtual; abstract;
		procedure SaveToIniFile(const AIniFile: TIniFile); virtual; abstract;

	public
		constructor  Create(AOwner: TXSIDConfig); virtual;

		property  Owner: TXSIDConfig read FOwner;
		property  Custom: Boolean read GetCustom write SetCustom;
	end;

	TXSIDConfig = class(TObject)
	protected
		FLock: TCriticalSection;

		FStarted: Boolean;
		FChanged: Boolean;
		FAllowOverrides: Boolean;

//		System settings
		FSystem: TC64SystemType;
		FSystemOverride: Boolean;
//		FUpdateRate: TC64UpdateRate;
//		FUpdateRateOverride: Boolean;

//		SID settings
		FModel: TC64SIDModel;
		FModelOverride: Boolean;
		FFilter6581,
		FFilter8580: Double;
		FFilterEnable: Boolean;
		FDigiBoostEnable: Boolean;

//		Audio interface
		FRenderer: AnsiString;
		FRenderParams: TStringList;
		FSampleRate: TXSIDSampleRate;
		FBufferSize: TXSIDBufferSize;
		FInterpolation: TXSIDInterpolation;

//		Utility interface
		function  GetStarted: Boolean;
		procedure SetStarted(AValue: Boolean);
		procedure SetChanged(AValue: Boolean);
		function  GetChanged: Boolean;
		procedure SetAllowOverrides(const AValue: Boolean);
		function  GetAllowOverrides: Boolean;

		procedure LoadFromIniFile(const AIniFile: TIniFile);
		procedure SaveToIniFile(const AIniFile: TIniFile);

//		System settings
		procedure SetSystem(AValue: TC64SystemType);
		function  GetSystem: TC64SystemType;
		procedure SetSystemOverride(const AValue: Boolean);
		function  GetSystemOverride: Boolean;
//		procedure SetUpdateRate(AValue: TC64UpdateRate);
//		function  GetUpdateRate: TC64UpdateRate;
//		procedure SetUpdateRateOverride(const AValue: Boolean);
//		function  GetUpdateRateOverride: Boolean;

//		SID settings
		procedure SetModel(AValue: TC64SIDModel);
		function  GetModel: TC64SIDModel;
		procedure SetModelOverride(const AValue: Boolean);
		function  GetModelOverride: Boolean;
		procedure SetFilterEnable(AValue: Boolean);
		function  GetFilterEnable: Boolean;
		procedure SetFilter6581(AValue: Double);
		function  GetFilter6581: Double;
		procedure SetFilter8580(AValue: Double);
		function  GetFilter8580: Double;
		procedure SetDigiBoostEnable(AValue: Boolean);
		function  GetDigiBoostEnable: Boolean;

		function  GetCyclesPerSec: Cardinal;
		function  GetRefreshPerSec: TXSIDFloat;
		function  GetFreqFactor: TXSIDFloat;

//		Audio interface
		procedure SetRenderer(AValue: AnsiString);
		function  GetRenderer: AnsiString;

		procedure SetSampleRate(AValue: TXSIDSampleRate);
		function  GetSampleRate: TXSIDSampleRate;
		procedure SetBufferSize(AValue: TXSIDBufferSize);
		function  GetBufferSize: TXSIDBufferSize;
		procedure SetInterpolation(AValue: TXSIDInterpolation);
		function  GetInterpolation: TXSIDInterpolation;

	public
		constructor Create(const AIniFile: TIniFile = nil;
				const AAllowOverrides: Boolean = False);
		destructor  Destroy; override;

		procedure Lock;
		procedure Unlock;

		procedure Assign(AConfig: TXSIDConfig);

//dengland This will have to do for the time being.  Use with care!
		procedure SetRenderParams(const AStrings: TStrings);
		function  GetRenderParams: TStrings;

//		function  GetSysCyclesPerUpdate: TC64Float;

		property  Started: Boolean read GetStarted write SetStarted;
		property  Changed: Boolean read GetChanged write SetChanged;
		property  AllowOverrides: Boolean read GetAllowOverrides
				write SetAllowOverrides;

//		System settings
		property  System: TC64SystemType read GetSystem write SetSystem;
		property  SystemOverride: Boolean read GetSystemOverride
				write SetSystemOverride;
//		property  UpdateRate: TC64UpdateRate read GetUpdateRate write SetUpdateRate;
//		property  UpdateRateOverride: Boolean read GetUpdateRateOverride
//				write SetUpdateRateOverride;

//		SID settings
		property  Model: TC64SIDModel read GetModel write SetModel;
		property  ModelOverride: Boolean read GetModelOverride
				write SetModelOverride;
		property  FilterEnable: Boolean
				read GetFilterEnable write SetFilterEnable;
		property  Filter6581: Double read GetFilter6581 write SetFilter6581;
		property  Filter8580: Double read GetFilter8580 write SetFilter8580;

		property  DigiBoostEnable: Boolean
				read GetDigiBoostEnable write SetDigiBoostEnable;

		property  CyclesPerSec: Cardinal read GetCyclesPerSec;
		property  RefreshPerSec: TXSIDFloat read GetRefreshPerSec;
		property  FreqFactor: TXSIDFloat read GetFreqFactor;

//		Audio interface
		property  Renderer: AnsiString read GetRenderer write SetRenderer;
//dengland Need proper interface for params...

		property  SampleRate: TXSIDSampleRate
				read GetSampleRate write SetSampleRate;
		property  BufferSize: TXSIDBufferSize
				read GetBufferSize write SetBufferSize;
		property  Interpolation: TXSIDInterpolation
				read GetInterpolation write SetInterpolation;
	end;


var
//dengland  I suspect that these should be put into the objects or made
//		threadvars
//todo Check the usage of these globals
//	wave.h
//	dac: TArrDac;
//	wftable: array[0..10, 0..4095] of TXSIDFloat;
//	envelope.h
//	env_dac: array[0..255] of TXSIDFloat;

	GlobalEventPool: TXSIDEventPool;


function  XSIDCreateEvent(AOffset: TC64CycCnt; AReg, AValue: TC64Uns8): PXSIDEvent;
procedure XSIDAssignEvent(var ATarget: TXSIDEvent; ASource: TXSIDEvent);

procedure XSIDInitialiseConfig(const AIniFileName: string;
		const AAllowOverrides: Boolean = False);
procedure XSIDFinaliseConfig(const AIniFileName: string);

procedure XSIDRegisterRenderer(const ARenderer: TXSIDAudioRendererClass);

function  XSIDGlobalConfig: TXSIDConfig;
function  XSIDGlobalRenderers: TXSIDAudioRenderers;


implementation

uses
{$IFDEF FPC}
//dengland For AnsiCompareText
	SysUtils,
{$ENDIF}
{$IFDEF DCC}
//dengland For AnsiCompareText
	Windows,
	AnsiStrings,
{$ENDIF}
//dengland Include this so that the dump renderer is always the first in the list.
	XSIDAudioDump;

var
	FGlobalConfig: TXSIDConfig;
	FGlobalRenderers: TXSIDAudioRenderers;


procedure XSIDInitialiseConfig(const AIniFileName: string; const AAllowOverrides: Boolean);
	var
	ini: TIniFile;

	begin
	if  not Assigned(FGlobalConfig) then
		begin
		if  AIniFileName <> '' then
			ini:= TIniFile.Create(AIniFileName)
		else
			ini:= nil;
		try
			FGlobalConfig:= TXSIDConfig.Create(ini, AAllowOverrides);

			finally
			if  Assigned(ini) then
				ini.Free;
			end;
		end;
	end;

procedure XSIDFinaliseConfig(const AIniFileName: string);
	var
	ini: TIniFile;

	begin
	if  Assigned(FGlobalConfig) then
		if  AIniFileName <> '' then
			begin
			ini:= TIniFile.Create(AIniFileName);
			try
				FGlobalConfig.SaveToIniFile(ini);

				finally
				ini.Free;
				end;
			end;
	end;

procedure DoCheckGlobalRenderers;
	begin
	if not Assigned(FGlobalRenderers) then
		FGlobalRenderers:= TXSIDAudioRenderers.Create;
	end;

function  XSIDGlobalConfig: TXSIDConfig;
	begin
	Result:= FGlobalConfig;
	end;

function  XSIDGlobalRenderers: TXSIDAudioRenderers;
	begin
	Result:= FGlobalRenderers;
	end;


function XSIDCreateEvent(AOffset: TC64CycCnt; AReg, AValue: TC64Uns8): PXSIDEvent;
	begin
	Result:= GlobalEventPool.AllocateEvent;

	Result^.offs:= AOffset;
	Result^.data.reg:= AReg;
	Result^.data.val:= AValue;

	Result^.next:= nil;
	Result^.prev:= nil;
	end;

procedure XSIDAssignEvent(var ATarget: TXSIDEvent; ASource: TXSIDEvent);
	begin
	ATarget.offs:= ASource.offs;
	ATarget.data.reg:= ASource.data.reg;
	ATarget.data.val:= ASource.data.val;

	ATarget.next:= nil;
	ATarget.prev:= nil;
	end;


procedure XSIDRegisterRenderer(const ARenderer: TXSIDAudioRendererClass);
	begin
	DoCheckGlobalRenderers;
	FGlobalRenderers.AddItem(ARenderer);
	end;

{ TXSIDAudioRenderers }

function TXSIDAudioRenderers.GetCount: Integer;
	begin
	Result:= FList.Count;
	end;

function TXSIDAudioRenderers.GetItem(
		AIndex: Integer): TXSIDAudioRendererClass;
	begin
	Result:= TXSIDAudioRendererClass(FList.Items[AIndex]);
	end;

procedure TXSIDAudioRenderers.AddItem(const AItem: TXSIDAudioRendererClass);
	begin
//dengland Should also make sure that the names are unique and replace the
//		existing entry when a duplicate name is entered.
	if  FList.IndexOf(AItem) = -1 then
		FList.Add(AItem);
	end;

function TXSIDAudioRenderers.GetDefaultRenderer: TXSIDAudioRendererClass;
	var
	i: Integer;
	r: TXSIDAudioRendererClass;

	begin
//dengland Should cache this data in add
	if FList.Count > 0 then
		begin
		Result:= GetItem(0);

		for i:= 0 to FList.Count - 1 do
			begin
			r:= GetItem(i);
			if  r.GetWantPlatformDefault then
				begin
				Result:= r;
				Break;
				end;
			end;
		end
	else
		Result:= nil;
	end;

constructor TXSIDAudioRenderers.Create;
	begin
	FList:= TList.Create;
	end;

destructor TXSIDAudioRenderers.Destroy;
	begin
	FList.Free;

	inherited Destroy;
	end;

function TXSIDAudioRenderers.IndexOf(
		const AItem: TXSIDAudioRendererClass): Integer;
	begin
	Result:= FList.IndexOf(AItem);
	end;

function TXSIDAudioRenderers.ItemByName(
		const AName: AnsiString): TXSIDAudioRendererClass;
	var
	i: Integer;
	r: TXSIDAudioRendererClass;

	begin
	Result:= nil;

	for i:= 0 to FList.Count - 1 do
		begin
		r:= GetItem(i);

		if  AnsiCompareText(AName, r.GetName) = 0 then
			begin
			Result:= r;
			Break;
			end;
		end;
	end;


{ TXSIDAudioRenderer }

class function TXSIDAudioRenderer.GetIsRealTime: Boolean;
	begin
    Result:= True;
	end;

class function TXSIDAudioRenderer.GetRequireAllData: Boolean;
	begin
	Result:= False;
	end;

class function TXSIDAudioRenderer.GetWantPlatformDefault: Boolean;
	begin
	Result:= False;
	end;

constructor TXSIDAudioRenderer.Create(const ASampleRate: TXSIDSampleRate;
		const AFrameRate: Cardinal; const ABufferSize: TXSIDBufferSize;
		const AParams: TStrings; var ABuffer: PArrSmallInt; var ASize: Cardinal);
	begin
	inherited Create;
	end;

class procedure TXSIDAudioRenderer.FillParameterNames(const AStrings: TStrings);
	begin
	AStrings.Clear;
	end;


{ TXSIDConfigFilter }

procedure TXSIDConfigFilter.SetChanged(AValue: Boolean);
	begin
	FOwner.SetChanged(AValue);
	end;

procedure TXSIDConfigFilter.SetCustom(AValue: Boolean);
	begin
	Lock;
	try
		if AValue <> FCustom then
			begin
			FCustom:= AValue;

			if not AValue then
				DoSetTypeSettings;

			SetChanged(True);
			end;

		finally
		Unlock;
		end;
	end;

function TXSIDConfigFilter.GetCustom: Boolean;
	begin
	Lock;
	try
		Result:= FCustom;

		finally
		Unlock;
		end;
	end;

procedure TXSIDConfigFilter.Lock;
	begin
	FOwner.Lock;
	end;

procedure TXSIDConfigFilter.Unlock;
	begin
	FOwner.Unlock;
	end;

procedure TXSIDConfigFilter.DoSetSystemDefaults;
	begin
	FCustom:= False;
	DoSetTypeSettings;
	end;

procedure TXSIDConfigFilter.Assign(AFilter: TXSIDConfigFilter);
	begin
	FCustom:= AFilter.FCustom;

//dengland Should add class checking here
	DoAssign(AFilter);
	end;

constructor TXSIDConfigFilter.Create(AOwner: TXSIDConfig);
	begin
	inherited Create;

	FOwner:= AOwner;
	DoSetSystemDefaults;
	end;


{ TXSIDConfig }

function TXSIDConfig.GetStarted: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FStarted;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetSampleRate(AValue: TXSIDSampleRate);
	begin
	FLock.Acquire;
	try
		if AValue <> FSampleRate then
			begin
			FSampleRate:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetSampleRate: TXSIDSampleRate;
	begin
	FLock.Acquire;
	try
		Result:= FSampleRate;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetAllowOverrides(const AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if  AValue <> FAllowOverrides then
			begin
			FAllowOverrides:= AValue;

			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetBufferSize(AValue: TXSIDBufferSize);
	begin
	FLock.Acquire;
	try
		if AValue <> FBufferSize then
			begin
			FBufferSize:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetAllowOverrides: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FAllowOverrides;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetBufferSize: TXSIDBufferSize;
	begin
	FLock.Acquire;
	try
		Result:= FBufferSize;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetInterpolation(AValue: TXSIDInterpolation);
	begin
	FLock.Acquire;
	try
		if  AValue <> FInterpolation then
			begin
			FInterpolation:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetInterpolation: TXSIDInterpolation;
	begin
	FLock.Acquire;
	try
		Result:= FInterpolation;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetStarted(AValue: Boolean);
	begin
	FLock.Acquire;
	try
		FStarted:= AValue;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetChanged(AValue: Boolean);
	begin
	FLock.Acquire;
	try
		FChanged:= AValue;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetChanged: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FChanged;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.LoadFromIniFile(const AIniFile: TIniFile);
	var
	i: Integer;
	f: TXSIDFloat;
	b: Boolean;
	s: string;

	begin
	FLock.Acquire;
	try
//		Read the SID settings
		i:= AIniFile.ReadInteger('SID', 'Model', Ord(FModel));
		if  i = 0 then
			i:= 1;
		FModel:= TC64SIDModel(i);

		i:= AIniFile.ReadInteger('SID', 'System', Ord(FSystem));
		if  i = 0 then
			i:= 1;
		FSystem:= TC64SystemType(i);

//		i:= AIniFile.ReadInteger('SID', 'UpdateRate', Ord(FUpdateRate));
//		FUpdateRate:= TC64UpdateRate(i);

		if  FAllowOverrides then
			begin
			FModelOverride:= AIniFile.ReadBool('SID', 'ModelOverride', False);
			FSystemOverride:= AIniFile.ReadBool('SID', 'SystemOverride', False);
//			FUpdateRateOverride:= AIniFile.ReadBool('SID', 'UpdateRateOverride', False);
			end
		else
			begin
			FModelOverride:= False;
			FSystemOverride:= False;
//			FUpdateRateOverride:= False;
			end;

		b:= AIniFile.ReadBool('SID', 'FilterEnable', FFilterEnable);
		FFilterEnable:= b;

		f:= AIniFIle.ReadFloat('SID', 'Filter6581', FFilter6581);
		FFilter6581:= f;

		f:= AIniFIle.ReadFloat('SID', 'Filter8580', FFilter8580);
		FFilter8580:= f;

		b:= AIniFile.ReadBool('SID', 'DigiBoostEnable', FDigiBoostEnable);
		FDigiBoostEnable:= b;

//		Read the Audio settings
		s:= AIniFile.ReadString('Audio', 'Renderer', string(FRenderer));
		SetRenderer(AnsiString(s));

		i:= AIniFile.ReadInteger('Audio', 'SampleRate', Ord(FSampleRate));
		FSampleRate:= TXSIDSampleRate(i);

		i:= AIniFile.ReadInteger('Audio', 'BufferSize', Ord(FBufferSize));
		FBufferSize:= TXSIDBufferSize(i);

		i:= AIniFile.ReadInteger('Audio', 'Interpolation', Ord(FInterpolation));
		if  i = 0 then
			i:= 2;
		FInterpolation:= TXSIDInterpolation(i);

		AIniFile.ReadSectionValues('Audio.Renderer.' + string(FRenderer),
				FRenderParams);

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SaveToIniFile(const AIniFile: TIniFile);
	var
	i: Integer;

	begin
	FLock.Acquire;
	try
//		Write the SID settings
		AIniFile.WriteInteger('SID', 'Model', Ord(FModel));

		AIniFile.WriteInteger('SID', 'System', Ord(FSystem));

//		AIniFile.WriteInteger('SID', 'UpdateRate', Ord(FUpdateRate));

		if  FAllowOverrides then
			begin
			AIniFile.WriteBool('SID', 'ModelOverride', FModelOverride);
			AIniFile.WriteBool('SID', 'SystemOverride', FSystemOverride);
//			AIniFile.WriteBool('SID', 'UpdateRateOverride', FUpdateRateOverride);
			end;

		AIniFile.WriteBool('SID', 'FilterEnable', FFilterEnable);

		AIniFIle.WriteFloat('SID', 'Filter6581', FFilter6581);

		AIniFIle.WriteFloat('SID', 'Filter8580', FFilter8580);

		AIniFile.WriteBool('SID', 'DigiBoostEnable', FDigiBoostEnable);

//		Read the Audio settings
		AIniFile.WriteString('Audio', 'Renderer', string(FRenderer));

		AIniFile.WriteInteger('Audio', 'SampleRate', Ord(FSampleRate));

		AIniFile.WriteInteger('Audio', 'BufferSize', Ord(FBufferSize));

		AIniFile.WriteInteger('Audio', 'Interpolation', Ord(FInterpolation));

		for i:= 0 to FRenderParams.Count - 1 do
			AIniFile.WriteString('Audio.Renderer.' + string(FRenderer),
					FRenderParams.Names[i], FRenderParams.ValueFromIndex[i]);

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetModel(AValue: TC64SIDModel);
	begin
	FLock.Acquire;
	try
		if  AValue <> FModel then
			begin
			FModel:= AValue;

			if AValue = csmMOS6581 then
				FDigiBoostEnable:= False;

			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetModelOverride(const AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if  AValue <> FModelOverride then
			begin
			FModelOverride:= AValue;

			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetModel: TC64SIDModel;
	begin
	FLock.Acquire;
	try
		Result:= FModel;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetModelOverride: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FModelOverride;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetSystem(AValue: TC64SystemType);
	begin
	FLock.Acquire;
	try
		if  AValue <> FSystem then
			begin
			FSystem:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetSystemOverride(const AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if  AValue <> FSystemOverride then
			begin
			FSystemOverride:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

(*procedure TXSIDConfig.SetUpdateRate(AValue: TC64UpdateRate);
	begin
	FLock.Acquire;
	try
		if  AValue <> FUpdateRate then
			begin
			FUpdateRate:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetUpdateRateOverride(const AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if  AValue <> FUpdateRateOverride then
			begin
			FUpdateRateOverride:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;*)

(*function TXSIDConfig.GetSysCyclesPerUpdate: TC64Float;
	var
	f: Integer;

	begin
	f:= 1 shl Ord(FUpdateRate);
	Result:= ARR_VAL_SYSCYCPRFS[FSystem] / f;
	end;*)

function TXSIDConfig.GetSystem: TC64SystemType;
	begin
	FLock.Acquire;
	try
		Result:= FSystem;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetSystemOverride: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FSystemOverride;

		finally
		FLock.Release;
		end;
	end;

(*function TXSIDConfig.GetUpdateRate: TC64UpdateRate;
	begin
	FLock.Acquire;
	try
		Result:= FUpdateRate;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetUpdateRateOverride: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FUpdateRateOverride;

		finally
		FLock.Release;
		end;
	end;*)

procedure TXSIDConfig.SetFilter6581(AValue: Double);
	begin
	FLock.Acquire;
	try
		if AValue <> FFilter6581 then
			begin
			FFilter6581:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetFilter8580(AValue: Double);
	begin
	FLock.Acquire;
	try
		if AValue <> FFilter8580 then
			begin
			FFilter8580:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetFilterEnable(AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if AValue <> FFilterEnable then
			begin
			FFilterEnable:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetFilter6581: Double;
	begin
	FLock.Acquire;
	try
		Result:= FFilter6581;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetFilter8580: Double;
	begin
	FLock.Acquire;
	try
		Result:= FFilter8580;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetFilterEnable: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FFilterEnable;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetDigiBoostEnable(AValue: Boolean);
	begin
	FLock.Acquire;
	try
		if AValue <> FDigiBoostEnable then
			begin
			FDigiBoostEnable:= AValue;
			FChanged:= True;
			end;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetDigiBoostEnable: Boolean;
	begin
	FLock.Acquire;
	try
		Result:= FDigiBoostEnable;

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetCyclesPerSec: Cardinal;
	begin
	FLock.Acquire;
	try
		Result:= ARR_VAL_SYSCYCPSEC[FSystem];

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetRefreshPerSec: TXSIDFloat;
	begin
	FLock.Acquire;
	try
		Result:= ARR_VAL_SYSRFRSHPS[FSystem];

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetFreqFactor: TXSIDFloat;
	begin
	FLock.Acquire;
	try
		Result:= ARR_VAL_SYSSIDFRQF[FSystem];

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetRenderer(AValue: AnsiString);
	var
	r: TXSIDAudioRendererClass;

	begin
	FLock.Acquire;
	try
		if AValue <> FRenderer then
			begin
			r:= XSIDGlobalRenderers.ItemByName(AValue);
			if  Assigned(r) then
				begin
				FRenderer:= AValue;

				FRenderParams.Clear;
				r.FillParameterNames(FRenderParams);

				FChanged:= True;
				end;
			end;
		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetRenderer: AnsiString;
	begin
	FLock.Acquire;
	try
		Result:= FRenderer;

		finally
		FLock.Release;
		end;
	end;

constructor TXSIDConfig.Create(const AIniFile: TIniFile;
		const AAllowOverrides: Boolean);
	begin
	FLock:= TCriticalSection.Create;

	FAllowOverrides:= AAllowOverrides;
	FSystemOverride:= False;
//	FUpdateRateOverride:= False;
	FModelOverride:= False;

	FSystem:= VAL_DEF_C64SYSTYPE;
//	FUpdateRate:= VAL_DEF_C64UPDRATE;

	FModel:= VAL_DEF_C64SIDMODL;
	FFilterEnable:= VAL_DEF_FILTENABLE;
	FFilter6581:= ARR_VAL_TYPE3PROPS[rm3R2];
	FFilter8580:= ARR_VAL_TYPE4PROPS[rm4R5];
	FDigiBoostEnable:= VAL_DEF_DIGIBSTENB;

	FRenderer:= XSIDGlobalRenderers.DefaultRenderer.GetName;
	FRenderParams:= TStringList.Create;
	XSIDGlobalRenderers.DefaultRenderer.FillParameterNames(FRenderParams);

	FSampleRate:= VAL_DEF_SAMPLERATE;
	FBufferSize:= VAL_DEF_BUFFERSIZE;
	FInterpolation:= VAL_DEF_INTERPLATE;

	if  Assigned(AIniFile) then
		LoadFromIniFile(AIniFile);
	end;

destructor TXSIDConfig.Destroy;
	begin
	FRenderParams.Free;

	FLock.Free;

	inherited Destroy;
	end;

procedure TXSIDConfig.Lock;
	begin
	FLock.Acquire;
	end;

procedure TXSIDConfig.Unlock;
	begin
	FLock.Release;
	end;

procedure TXSIDConfig.Assign(AConfig: TXSIDConfig);
	begin
	FLock.Acquire;
	try
		AConfig.FLock.Acquire;
		try
			FAllowOverrides:= AConfig.FAllowOverrides;

			FModel:= AConfig.FModel;
			FSystem:= AConfig.FSystem;
//			FUpdateRate:= AConfig.UpdateRate;

			FModelOverride:= AConfig.FModelOverride;
			FSystemOverride:= AConfig.FSystemOverride;
//			FUpdateRateOverride:= AConfig.UpdateRateOverride;

			FFilterEnable:= AConfig.FFilterEnable;
			FFilter6581:= AConfig.FFilter6581;
			FFilter8580:= AConfig.FFilter8580;
			FDigiBoostEnable:= AConfig.FDigiBoostEnable;

			FRenderer:= AConfig.FRenderer;
			FRenderParams.Clear;
			FRenderParams.AddStrings(AConfig.FRenderParams);

			FSampleRate:= AConfig.FSampleRate;
			FBufferSize:= AConfig.FBufferSize;
			FInterpolation:= AConfig.FInterpolation;

//			FChanged:= AConfig.FChanged;
			FChanged:= False;

			finally
			AConfig.FLock.Release;
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDConfig.SetRenderParams(const AStrings: TStrings);
	begin
	FLock.Acquire;
	try
		FRenderParams.Clear;
		FRenderParams.AddStrings(AStrings);

		finally
		FLock.Release;
		end;
	end;

function TXSIDConfig.GetRenderParams: TStrings;
	begin
	FLock.Acquire;
	try
//dengland This is quite nasty.  A lock should be maintained around all useage
//		of this result unless extreme care is taken.
		Result:= FRenderParams;

		finally
		FLock.Release;
		end;
	end;

{ TXSIDEventPool }

function TXSIDEventPool.AllocateEvent: PXSIDEvent;
	begin
	FLock.Acquire;
	try
		if FAvailList.Count > 0 then
			begin
			Result:= FAvailList[FAvailList.Count - 1];
			FAvailList.Delete(FAvailList.Count - 1);
			end
		else
			begin
			New(Result);
			FAllocList.Add(Result);
			end;

		finally
		FLock.Release;
		end;
	end;

procedure TXSIDEventPool.Clear;
	var
	i: Integer;

	begin
	FLock.Acquire;
	try
		FAvailList.Clear;

		for i:= FAllocList.Count - 1 downto 0 do
			Dispose(PXSIDEvent(FAllocList[i]));

		FAllocList.Clear;

		finally
		FLock.Release;
		end;
	end;

constructor TXSIDEventPool.Create;
	begin
	inherited Create;

	FLock:= TCriticalSection.Create;
	FAllocList:= TList.Create;
	FAvailList:= TList.Create;
	end;

destructor TXSIDEventPool.Destroy;
	begin
	Clear;

	FAvailList.Free;
	FAllocList.Free;
	FLock.Free;

	inherited;
	end;

procedure TXSIDEventPool.ReleaseEvent(AEvent: PXSIDEvent);
	begin
	FLock.Acquire;
	try
		FAvailList.Add(AEvent);

		finally
		FLock.Release;
		end;
	end;



initialization
	DoCheckGlobalRenderers;
//	FGlobalConfig:= TXSIDConfig.Create;
	GlobalEventPool:= TXSIDEventPool.Create;

finalization
	if Assigned(FGlobalConfig) then
		FGlobalConfig.Free;

	if Assigned(FGlobalRenderers) then
		FGlobalRenderers.Free;

	GlobalEventPool.Free;

end.
