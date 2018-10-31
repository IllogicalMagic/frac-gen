CXX=/usr/local/gcc-7.2.0/bin/g++
CC=$(CXX)
MAGICKFLAGS?=$(shell pkg-config --cflags Magick++)
CXXFLAGS?=-std=c++17 -Wall -Werror --pedantic-errors -Wno-unused-function -O3 -march=native $(MAGICKFLAGS) -DNDEBUG
MAGICLIBS?=$(shell pkg-config --libs Magick++)
LDLIBS?=$(MAGICLIBS)

all: FracGen

Drawer.o: Drawer.cpp Drawer.h Config.h

FracGen.o: FracGen.cpp Types.h

FracMath.o: FracMath.cpp Config.h Types.h Methods.hpp

FracGen: FracGen.o FracMath.o Drawer.o
	$(CXX) $(LDFLAGS) $(LDLIBS) $^ -o $@

clean:
	rm -rf *.o *~ Frac FracGen
