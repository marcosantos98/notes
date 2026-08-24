#!/bin/bash

if [ "$1" == "release" ]; then
    odin build . -show-timings -vet -o:speed -error-pos-style:unix
else
    odin build . -show-timings -debug -vet -error-pos-style:unix
fi
