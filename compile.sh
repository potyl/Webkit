#!/bin/bash

WebKit=$HOME/Downloads/webkit-1.6.1

g++ \
  -I$WebKit/Source/WebKit/gtk/webkit \
  -I$WebKit/DerivedSources/webkit \
  -I$WebKit/DerivedSources \
  -I$WebKit/Source/WebCore/{editing,xml,bindings} \
  -I$WebKit/Source/WebCore/platform/network \
  -I$WebKit/Source/WebCore/platform/network/soup \
  -I$WebKit/Source/WebCore/loader \
  -I$WebKit/Source/WebCore/loader/cache \
  -I$WebKit/Source/WebCore/bindings/gobject \
  -I$WebKit/Source/WebCore/{css,html,page} \
  -I$WebKit/Source/JavaScriptCore/API \
  -I$WebKit/Source/JavaScriptCore/assembler \
  -I$WebKit/Source/JavaScriptCore/wtf \
  -I$WebKit/Source/JavaScriptCore/heap \
  -I$WebKit/Source/JavaScriptCore/jit \
  -I$WebKit/Source/JavaScriptCore/dfg \
  -I$WebKit/Source/JavaScriptCore/runtime \
  -I$WebKit/Source/JavaScriptCore/interpreter \
  -I$WebKit/Source/WebCore/bindings/js/ \
  -I$WebKit/Source/WebCore/rendering/style/ \
  -I$WebKit/Source/WebCore/platform/graphics/ \
  -I$WebKit/Source/WebCore/dom/ \
  -I$WebKit/Source/WebCore/platform \
  -I$WebKit/Source/WebCore/platform/text \
  -I$WebKit/Source/WebCore/rendering \
  -I$WebKit/Source/JavaScriptCore \
  -I$WebKit/Downloads/webkit-1.6.1/DerivedSources \
  -I$WebKit/Source/JavaScriptCore/wtf/gobject \
  `pkg-config --cflags --libs webkitgtk-3.0` \
  -o test test.cpp
