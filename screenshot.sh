#!/bin/sh

xvfb-run --server-args="-screen 0 1024x768x24" perl screenshot.pl "$@"

