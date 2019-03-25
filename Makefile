calc.exe: calc.asm
	fasm calc.asm

clean:
	rm calc.exe

test: calc.exe
	dosbox calc.exe

debug: calc.exe
	dosbox .
