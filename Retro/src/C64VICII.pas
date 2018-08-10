unit C64VICII;

interface

uses
	Classes, SyncObjs, C64Classes, MR64Board;

type
	TSpriteRegs = packed record
		posX,
		posY: Word;
		enabled: Boolean;
		colour: Byte;
	end;

	TC64VICIIRegs = packed record
		rasterY: Word;
		rasterIRQY: Word;
		rasterIRQ: Boolean;
		rasterIRQSrc: Boolean;
		borderClr: Byte;
		backgdClr: Byte;
		sprites: array[0..7] of TSpriteRegs;
	end;

	TC64VICIIIO = class
	public
		procedure Write(const AAddress: Word; const AValue: Byte);
		function  Read(const AAddress: Word): Byte;
	end;

	TC64VICIIThread = class(TThread)
	protected
		FBuffer: TC64VideoBuffer;

	public
		RunSignal,
		DoneSignal: TSimpleEvent;

		constructor Create(ABuffer: TC64VideoBuffer);
		destructor Destroy; override;
	end;

	TC64VICIIFrame = class(TC64VICIIThread)
	protected
		FBrdRegs: TMR64BoardRegs;
		FPrevBrd: TMR64BoardSqrs;
		FThisBrd: TMR64BoardSqrs;
		FBlnkIdx: Integer;
		FBlnkFlg: Boolean;

		procedure Execute; override;

	public
		constructor Create(ABuffer: TC64VideoBuffer);
	end;

	TC64VICIIRaster = class(TC64VICIIThread)
	private
		FRegs: TC64VICIIRegs;

	protected
		procedure Execute; override;
	end;

	TC64VICIIBadLine = class(TC64VICIIThread)
	private
		FRegs: TC64VICIIRegs;
		FScreen: array[0..39] of Byte;
		FColour: array[0..39] of Byte;

        procedure DoDrawHiResText(AX, AY: Integer; AIndex: Integer);

	protected
		procedure Execute; override;

	public
		FRaster: Word;

	end;

var
	C64GlobalVICIIRegs: TC64VICIIRegs;

implementation

uses
	C64Types, C64Memory, C64Video;

{ TC64VICIIIO }

function TC64VICIIIO.Read(const AAddress: Word): Byte;
	var
	r: Byte;
	i: Integer;


	begin
	Result:= 0;
	r:= AAddress and $00FF;
	case r of
		$00..$0F:
			if  (r and $01) <> 0 then
				Result:= C64GlobalVICIIRegs.sprites[r div 2].posY
			else
				Result:= (C64GlobalVICIIRegs.sprites[r div 2].posX and $00FF);
		$10:
			begin
			Result:= 0;
			for i:= 0 to 7 do
				Result:= Result or
						(((C64GlobalVICIIRegs.sprites[i].posX and $100) shr 8) shl i);
			end;
		$11:
			begin
			Result:= (C64GlobalVICIIRegs.rasterY and $0100) shr 1;
			end;
		$12:
			Result:= C64GlobalVICIIRegs.rasterY and $00FF;
		$15:
			begin
			Result:= 0;
			for i:= 0 to 7 do
				if C64GlobalVICIIRegs.sprites[i].enabled then
					Result:= Result or (1 shl i);
			end;
		$19:
			Result:= Ord(C64GlobalVICIIRegs.rasterIRQSrc);
		$1A:
			begin
			Result:= Ord(C64GlobalVICIIRegs.rasterIRQ);
			end;
		$20:
			Result:= C64GlobalVICIIRegs.borderClr;
		$21:
			Result:= C64GlobalVICIIRegs.backgdClr;
		$27..$2E:
			Result:= C64GlobalVICIIRegs.sprites[r - $27].colour;
		end;
	end;

procedure TC64VICIIIO.Write(const AAddress: Word; const AValue: Byte);
	var
	r: Byte;
	v: Byte;
	i: Integer;

	begin
	r:= AAddress and $00FF;
	case r of
		$00..$0F:
			begin
			if  (r and $01) <> 0 then
				C64GlobalVICIIRegs.sprites[r div 2].posY:= AValue
			else
				C64GlobalVICIIRegs.sprites[r div 2].posX:=
					(C64GlobalVICIIRegs.sprites[r div 2].posX and $0100) or AValue;
			end;
		$10:
			begin
			v:= AValue;
			for i:= 0 to 7 do
				begin
				if  (v and $01) <> 0 then
					C64GlobalVICIIRegs.sprites[i].posX:=
							(C64GlobalVICIIRegs.sprites[i].posX and $00FF) or $0100
				else
					C64GlobalVICIIRegs.sprites[i].posX:=
							(C64GlobalVICIIRegs.sprites[i].posX and $00FF);

				v:= v shr 1;
				end;
			end;
		$11:
			begin
			v:= C64GlobalVICIIRegs.rasterIRQY and $00FF;
			v:= v or ((AValue and $80) shl 1);
			C64GlobalVICIIRegs.rasterIRQY:= v;
			end;
		$12:
			begin
			v:= C64GlobalVICIIRegs.rasterIRQY and $0100;
			v:= v or AValue;
			C64GlobalVICIIRegs.rasterIRQY:= v;
			end;
		$15:
			begin
			v:= AValue;
			for i:= 0 to 7 do
				begin
				C64GlobalVICIIRegs.sprites[i].enabled:= (v and $01) <> 0;
				v:= v shr 1;
				end;
			end;
		$1A:
			begin
			C64GlobalVICIIRegs.rasterIRQ:= (AValue and $01) <> 0;
			end;
		$20:
			C64GlobalVICIIRegs.borderClr:= AValue and $0F;
		$21:
			C64GlobalVICIIRegs.backgdClr:= AValue and $0F;
		$27..$2E:
			C64GlobalVICIIRegs.sprites[r - $27].colour:= AValue and $0F;
		end;
	end;

{ TC64VICIIThread }

constructor TC64VICIIThread.Create(ABuffer: TC64VideoBuffer);
	begin
	FBuffer:= ABuffer;

	RunSignal:= TSimpleEvent.Create;
	RunSignal.ResetEvent;
	DoneSignal:= TSimpleEvent.Create;
	DoneSignal.SetEvent;

	inherited Create(False);

	FreeOnTerminate:= True;
	end;

destructor TC64VICIIThread.Destroy;
	begin

	inherited;
	end;

{ TC64VICIIFrame }

constructor TC64VICIIFrame.Create(ABuffer: TC64VideoBuffer);
	var
	i: Integer;
	s: TMR64BoardSqr;

	begin
	s.own:= $FF;
	s.imprv:= $00;

	for i:= 0 to 39 do
		FPrevBrd[i]:= s;

	inherited Create(ABuffer);
	end;

procedure TC64VICIIFrame.Execute;
	var
	p: TC64PalToInt;

	procedure DoFillSquareSolid(const ASquare: Integer; const AColourInt: Integer);
		var
		y,
		yp,
		xp,
		sz: Integer;

		begin
		for y:= 0 to ARR_REC_BOARD_DET[ASquare].h - 1 do
			begin
			yp:= 319 - (ARR_REC_BOARD_DET[ASquare].y + y);
			xp:= ARR_REC_BOARD_DET[ASquare].x;
			sz:= ARR_REC_BOARD_DET[ASquare].w;

			DoFillInt(PInteger(@FBuffer.FBR^[yp, xp]), sz, AColourInt);
			end;
		end;

	procedure DoCopyOrigGlyph(const ASquare: Integer);
		var
		y,
		yp,
		xp,
		sz: Integer;

		begin
		for y:= 0 to ARR_REC_BOARD_DET[ASquare].h - 1 do
			begin
			yp:= 319 - (ARR_REC_BOARD_DET[ASquare].y + y);
			xp:= ARR_REC_BOARD_DET[ASquare].x;
			sz:= ARR_REC_BOARD_DET[ASquare].w * 4;

			Move(GlobalMR64Board[yp, xp, 0], FBuffer.FBR^[yp, xp, 0], sz);
			end;
		end;

	procedure DoCopySelGlyph(const ASquare: Integer);
		var
		y,
		yp,
		xp,
		sz: Integer;

		begin
		for y:= 0 to ARR_REC_BOARD_DET[ASquare].h - 1 do
			begin
			yp:= 319 - (ARR_REC_BOARD_DET[ASquare].y + y);
			xp:= ARR_REC_BOARD_DET[ASquare].x;
			sz:= ARR_REC_BOARD_DET[ASquare].w * 4;

			Move(GlobalMR64BrdGlyphs[ASquare, (ARR_REC_BOARD_DET[ASquare].h - 1) - y,
					0, 0], FBuffer.FBR^[yp, xp, 0], sz);
			end;
		end;

	procedure DoDrawVICIIChar(const AX, AY: Integer; const AChar, AFGClr, ABGClr: Byte);
		var
		x,
		y: Integer;
		b,
		m: Byte;

		begin
		for y:= 0 to 7 do
			begin
			b:= GlobalC64CharGen[AChar * 8 + y];
			m:= $80;
			for x:= 0 to 7 do
				begin
				if  (b and m) <> 0 then
					Move(GlobalC64Palette[AFGClr, 0], FBuffer.FBR^[319 - (AY + y),
							AX + x, 0], 4)
				else
					Move(GlobalC64Palette[ABGClr, 0], FBuffer.FBR^[319 - (AY + y),
							AX + x, 0], 4);

				m:= m shr 1;
				end;
            end;
		end;

	procedure UpdateOwn;
		var
		i: Integer;
		ch,
		cl: Byte;
		x,
		y: Integer;

		begin
		for i:= 0 to 39 do
			begin
			if  (FThisBrd[i].imprv and $40) <> 0 then
				ch:= $A0
			else
				ch:= $E6;

			if  FThisBrd[i].own = $FF then
				cl:= $0B
			else
				cl:= FBrdRegs.players[FThisBrd[i].own].colour;

			case ARR_REC_BOARD_DET[i].ps of
				mbpBottom, mbpTop:
					begin
					if  ARR_REC_BOARD_DET[i].ps = mbpBottom then
						x:= ARR_REC_BOARD_DET[i].x
					else
						x:= ARR_REC_BOARD_DET[i].x - 2;

					y:= ARR_VAL_BOARD_OWN[ARR_REC_BOARD_DET[i].ps];

					DoDrawVICIIChar(x, y, ch, cl, $00);
					DoDrawVICIIChar(x + 8, y, ch, cl, $00);
					DoDrawVICIIChar(x + 16, y, ch, cl, $00);
					end;
				mbpLeft, mbpRight:
					begin
					if  ARR_REC_BOARD_DET[i].ps = mbpRight then
						y:= ARR_REC_BOARD_DET[i].y
					else
						y:= ARR_REC_BOARD_DET[i].y - 2;

					x:= ARR_VAL_BOARD_OWN[ARR_REC_BOARD_DET[i].ps];

					DoDrawVICIIChar(x, y, ch, cl, $00);
					DoDrawVICIIChar(x, y + 8, ch, cl, $00);
					DoDrawVICIIChar(x, y + 16, ch, cl, $00);
					end;
				end;
			end;
		end;

	procedure UpdateImprove;
		var
		i: Integer;
		ch,
		cl: Byte;
		x,
		y: Integer;

		begin
		for i:= 0 to 39 do
			begin
			if  (FThisBrd[i].imprv and $0F) <> 0 then
				begin
				if  (FThisBrd[i].imprv and $08) <> 0 then
					begin
					ch:= $88;
					cl:= $0A;
					end
				else
					begin
					ch:= $B0 + (FThisBrd[i].imprv and $07);
					cl:= $0D;
					end;

				case ARR_REC_BOARD_DET[i].ps of
					mbpBottom, mbpTop:
						begin
						x:= ARR_REC_BOARD_DET[i].x;
						y:= ARR_VAL_BOARD_IMP[ARR_REC_BOARD_DET[i].ps];

						DoDrawVICIIChar(x, y, ch, cl, $00);
						end;
					mbpLeft, mbpRight:
						begin
						y:= ARR_REC_BOARD_DET[i].y;
						x:= ARR_VAL_BOARD_IMP[ARR_REC_BOARD_DET[i].ps];

						DoDrawVICIIChar(x, y, ch, cl, $00);
						end;
					end;
				end;
			end;
		end;

	procedure UpdateMortgage;
		var
		i: Integer;
		p: TC64PalToInt;

		begin
		p.arr:= GlobalC64Palette[$0B];

		for i:= 0 to 39 do
			if  (FThisBrd[i].imprv and $80) <> 0 then
				DoFillSquareSolid(i, p.int);
		end;

	procedure ResetSelection;
		var
		i: Integer;
		p: TC64PalToInt;

		begin
		for i:= 0 to 39 do
			if  (FPrevBrd[i].imprv and $20) <> 0 then
				if  ARR_REC_BOARD_DET[i].fg then
					DoCopyOrigGlyph(i)
				else
					begin
					if (FPrevBrd[i].imprv and $80) <> 0 then
						p.arr:= GlobalC64Palette[$0B]
					else
						p.arr:= GlobalC64Palette[$03];

					DoFillSquareSolid(i, p.int);
					end;
		end;

	procedure UpdateSelection;
		var
		i: Integer;
		p: TC64PalToInt;

		begin
		for i:= 0 to 39 do
			if  (FThisBrd[i].imprv and $20) <> 0 then
				if  ARR_REC_BOARD_DET[i].fg then
					DoCopySelGlyph(i)
				else
					begin
					if (FPrevBrd[i].imprv and $80) <> 0 then
						p.arr:= GlobalC64Palette[$0F]
					else
						p.arr:= GlobalC64Palette[$01];

					DoFillSquareSolid(i, p.int);
					end;
		end;

	procedure DoGetPlayerPos(const APlayer: Integer; var AX, AY: Integer);
		var
		s: Integer;
		p: Integer;

		begin
		s:= FBrdRegs.players[APlayer].square;
		p:= APlayer mod 3;

		case ARR_REC_BOARD_DET[s].ps of
			mbpBottom:
				begin
				AX:= ARR_REC_BOARD_DET[s].x + 2;
				AY:= ARR_REC_BOARD_DET[s].y + 1 + p * 9;
				if  APlayer > 2 then
					Inc(AX, 10);
				if  ARR_REC_BOARD_DET[s].fg then
					Inc(AY, 10);
				end;
			mbpLeft:
				begin
				AX:= ARR_REC_BOARD_DET[s].x + 1 + p * 9;
				AY:= ARR_REC_BOARD_DET[s].y + 2;
				if  APlayer > 2 then
					Inc(AY, 10);
				end;
			mbpTop:
				begin
				AX:= ARR_REC_BOARD_DET[s].x + 2;
				AY:= ARR_REC_BOARD_DET[s].y + 1 + p * 9;
				if  APlayer > 2 then
					Inc(AX, 10);
				end;
			mbpRight:
				begin
				AX:= ARR_REC_BOARD_DET[s].x + 1 + p * 9;
				AY:= ARR_REC_BOARD_DET[s].y + 2;
				if  APlayer > 2 then
					Inc(AY, 10);
				if  ARR_REC_BOARD_DET[s].fg then
					Inc(AX, 10);
				end;
			end;
		end;

	procedure DoDrawPlayerToken(const APlayer, AX, AY: Integer);
		var
		x,
		y: Integer;
		b,
		m: Byte;
		cl: Byte;

		begin
		cl:= FBrdRegs.players[APlayer].colour;
		if  FBrdRegs.players[APlayer].active then
			if  ARR_VAL_TOKEN_BNK[FBlnkIdx] <> $FF then
				cl:= ARR_VAL_TOKEN_BNK[FBlnkIdx];

		for y:= 0 to 7 do
			begin
			b:= ARR_VAL_TOKEN_CHR[y];
			m:= $80;
			for x:= 0 to 7 do
				begin
				if  (b and m) <> 0 then
					Move(GlobalC64Palette[cl, 0],
							FBuffer.FBP^[319 - (AY + y), AX + x, 0], 4);

				m:= m shr 1;
				end;
			end;

		end;

	procedure UpdatePlayers;
		var
		i: Integer;
		xp,
		yp: Integer;

		begin
		for i:= 5 downto 0 do
			if  (FBrdRegs.players[i].status and $01) <> 0 then
				begin
				DoGetPlayerPos(i, xp, yp);
				DoDrawPlayerToken(i, xp, yp);
				end;
		end;

	begin
	while not Terminated do
		if  RunSignal.WaitFor(1) = wrSignaled then
			begin
			DoneSignal.ResetEvent;

			FBrdRegs:= GlobalMR64BoardRegs;
			GlobalMR64BoardRegs.dirty:= mbdNone;

			p.arr:= ARR_CLR_C64ALPHA;
			DoFillInt(PInteger(FBuffer.FBP), 320 * 320, p.int);

			if  FBrdRegs.dirty <> mbdNone then
				Move(GlobalC64Memory.FRAM[FBrdRegs.address], FThisBrd[0], 80);

			if  FBrdRegs.dirty = mbdAll then
				begin
				Move(GlobalMR64Board[0], FBuffer.FBR^, 320 * 320 * 4);
				UpdateOwn;
				UpdateImprove;
				UpdateMortgage;
				end
			else
				Move(PrevMR64Board[0], FBuffer.FBR^, 320 * 320 * 4);

			if  FBrdRegs.dirty = mbdSelect then
				ResetSelection;

			if  FBrdRegs.dirty <> mbdNone then
				begin
				UpdateSelection;

				Move(FBuffer.FBR^, PrevMR64Board[0], 320 * 320 * 4);
				Move(FThisBrd[0], FPrevBrd[0], 80);
				end;

			FBlnkFlg:= not FBlnkFlg;
			if  not FBlnkFlg then
				begin
				Inc(FBlnkIdx);
				if  FBlnkIdx = 12 then
					FBlnkIdx:= 0;
				end;

			UpdatePlayers;

			DoneSignal.SetEvent;
			RunSignal.ResetEvent;
			end;
	end;

{ TC64VICIIRaster }

procedure TC64VICIIRaster.Execute;
	var
	y,
	x: Integer;
	p: TC64PalToInt;

	function SpriteOnRaster(const ASprite, ARaster: Integer): Boolean;
		begin
		Result:= False;

		if  (ARaster >= 51)
		and (ARaster <= 250) then
			if  (ARaster >= FRegs.sprites[ASprite].posY)
			and (ARaster <= (FRegs.sprites[ASprite].posY + 20)) then
				Result:= FRegs.sprites[ASprite].enabled;
		end;

	procedure DrawSpriteRaster(const ASprite, ARaster: Integer);
		var
		addr: Word;
		offs: Integer;
		b,
		m,
		ch: Byte;
		i,
		j: Integer;

		begin
		offs:= ARaster - FRegs.sprites[ASprite].posY;
		addr:= GlobalC64Memory.FRAM[$07F8 + ASprite] * 64 + offs * 3;

		for i:= 0 to 2 do
			begin
			ch:= GlobalC64Memory.FRAM[addr];
			m:= $80;
			for j:= 0 to 7 do
				begin
				b:= ch and m;
				m:= m shr 1;

				if  b <> 0 then
					Move(GlobalC64Palette[FRegs.sprites[ASprite].colour],
							FBuffer.FSP^[311 - ARaster,
							FRegs.sprites[ASprite].posX + i * 8 + j, 0], 4);
				end;

			Inc(addr);
			end;
		end;


	begin
	while not Terminated do
		if  RunSignal.WaitFor(1) = wrSignaled then
			begin
			DoneSignal.ResetEvent;

			FRegs:= C64GlobalVICIIRegs;
			y:= FRegs.rasterY;

			p.arr:= GlobalC64Palette[FRegs.borderClr];
			DoFillInt(PInteger(@FBuffer.FBG^[311 - y, 0]), 385, p.int);

			p.arr:= ARR_CLR_C64ALPHA;
			DoFillInt(PInteger(@FBuffer.FSP^[311 - y, 0]), 385, p.int);

//			for x:= 0 to 384 do
//				Move(GlobalC64Palette[FRegs.borderClr], FBuffer.FBG^[311 - y, x, 0], 4);

			for x:= 7 downto 0 do
				if  SpriteOnRaster(x, y) then
					DrawSpriteRaster(x, y);

			DoneSignal.SetEvent;
			RunSignal.ResetEvent;
			end;
	end;

{ TC64VICIIBadLine }

procedure TC64VICIIBadLine.DoDrawHiResText(AX, AY, AIndex: Integer);
	var
	chrgen: Integer;
	ch: Byte;
	cl: Byte;
	b: Byte;
	m: Byte;
	i,
	j: Integer;

	begin
	for i:= 0 to 39 do
		begin
		cl:= FColour[i];
		chrgen:= FScreen[i] * 8 + AIndex;
		ch:= GlobalC64CharGen[chrgen];
		m:= $80;
		for j:= 0 to 7 do
			begin
			b:= ch and m;
			m:= m shr 1;

			if  cl > $0F then
				Move(ARR_CLR_C64ALPHA[0],
						FBuffer.FFG^[311 - AY, AX + i * 8 + j, 0], 4)
			else if  b = 0 then
				Move(GlobalC64Palette[FRegs.backgdClr],
						FBuffer.FFG^[311 - AY, AX + i * 8 + j, 0], 4)
			else
				Move(GlobalC64Palette[cl and $0F],
						FBuffer.FFG^[311 - AY, AX + i * 8 + j, 0], 4);
			end;
		end;

	end;

procedure TC64VICIIBadLine.Execute;
	var
	i,
	x,
	y: Integer;
	addr: Word;

	begin
	while not Terminated do
		if  RunSignal.WaitFor(1) = wrSignaled then
			begin
			DoneSignal.ResetEvent;

			FRegs:= C64GlobalVICIIRegs;

			addr:= $0400 + FBuffer.FBADLine * 40;
			for i:= 0 to 39 do
				FScreen[i]:= GlobalC64Memory.FRAM[addr + i];

			addr:= $D800 + FBuffer.FBADLine * 40;
			for i:= 0 to 39 do
				FColour[i]:= GlobalC64Memory.FRAM[addr + i];

			for i:= 0 to 7 do
				begin
				y:= {51 + FBuffer.FBADLine * 8}FRaster + i;
				x:= 24;

                DoDrawHiResText(x, y, i);

//				for x:= 24 to 343 do
//					Move(GlobalC64Palette[FRegs.backgdClr{FBuffer.FBADLine mod 16}],
//							FBuffer.FFG^[311 - y, x, 0], 4);
				end;

			DoneSignal.SetEvent;
			RunSignal.ResetEvent;
			end;
	end;

end.