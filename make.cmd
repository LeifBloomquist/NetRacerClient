@cls
@del *.prg
tools\dasm racer-main.asm -o!netracer.prg -lracer.list
pause
tools\exomizer.exe sfx sys "!netracer.prg" -o netracer-1.1a.prg
