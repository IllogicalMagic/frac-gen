CXX=/usr/local/gcc-7.2.0/bin/g++
CC=$(CXX)
MAGICKFLAGS?=-DMAGICKCORE_HDRI_ENABLE=0 -DMAGICKCORE_QUANTUM_DEPTH=16 -I/usr/include/x86_64-linux-gnu//ImageMagick-6 -I/usr/include/ImageMagick-6
CXXFLAGS?=-std=c++17 -Wall -Werror --pedantic-errors -Wno-unused-function -O3 -march=native $(MAGICKFLAGS)
MAGICLIBS?=-lMagick++-6.Q16 -lMagickWand-6.Q16 -lMagickCore-6.Q16
LDLIBS?=-lmpc -lmpfr $(MAGICLIBS)

all: FracGen

Drawer.o: Drawer.cpp Drawer.h Config.h

FracGen.o: FracGen.cpp

FracMathSidi.o: FracMathSidi.cpp

FracGen: FracGen.o FracMathSidi.o Drawer.o
	$(CXX) $(LDFLAGS) $(LDLIBS) $^ -o $@

clean:
	rm -rf *.o *~ Frac FracGen
