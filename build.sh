#!/bin/bash

if [ "$1" == "release" ]; then
    odin build . -show-timings -vet -o:speed
else
    odin build . -show-timings -debug -vet
fi
