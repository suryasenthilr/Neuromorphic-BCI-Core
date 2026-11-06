@echo off
call "C:\Users\surya\.oss-cad-suite\oss-cad-suite\environment.bat"
start "" gtkwave "%~dp0sim\dump.vcd" "%~dp0sim\view_wave.gtkw"
