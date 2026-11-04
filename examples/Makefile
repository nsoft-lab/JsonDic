# Copyright(c) 2026, NSoFT Co., Ltd.
# SPDX-License-Identifier: Apache-2.0

# Makefile for examples

CXX = g++
CXXFLAGS = -I../ -g -O2 -fno-exceptions

LIBS = ../jsonDic.o
HDRS = ../jsonDic.h

PROGS = ex-dump ex-string ex-mmap

all : $(PROGS)

clean :
	rm -f $(PROGS) *.o core *~ *.exe

$(PROGS) : % : %.cc $(HDRS)
	@$(MAKE) -C ..
	$(CXX) $(CXXFLAGS) -o $@ $< $(LIBS)
