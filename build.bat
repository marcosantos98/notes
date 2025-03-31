@echo off

if "%1" == "release" ( 
    set release_mode=1 
) else (
    set release_mode=0
)

if %release_mode% equ 1 (
    odin build . -show-timings -vet -o:speed
) else (
    odin build . -show-timings -debug -vet
)

