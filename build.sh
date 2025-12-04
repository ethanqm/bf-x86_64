#!/usr/bin/env sh

as $1
ld a.out -o main -static -nostdlib
