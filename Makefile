# Copyright(c) 2026, NSoFT Co., Ltd.
# SPDX-License-Identifier: Apache-2.0

# Makefile for jsonDic.cc jsonDic.o

CXX = g++
CXXFLAGS = -g -O2 -fno-exceptions

SRCS = jsonDic.cc
OBJS = jsonDic.o

all : $(OBJS)

clean :
	rm -f $(OBJS) $(SRCS) *.o core *~ *.exe

jsonDic.cc : jsonDic.yy jsonDic.h
	bison -o $@ $<

%.o : %.cc
	$(CXX) $(CXXFLAGS) -c $<

