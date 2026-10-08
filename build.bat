@echo off
if not exist build mkdir build
C:\cc65\bin\ca65.exe src\maze_mayhem.asm -o build\maze_mayhem.o
if errorlevel 1 exit /b 1
C:\cc65\bin\ld65.exe -C config\nes.cfg build\maze_mayhem.o -o build\maze_mayhem.nes
if errorlevel 1 exit /b 1
echo Built build\maze_mayhem.nes