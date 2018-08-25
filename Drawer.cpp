#include "Config.h"
#include "Drawer.h"

#include <Magick++.h>

#include <cstdio>
#include <cmath>

using namespace Magick;

static constexpr double pi23 = 2.094395102;

void drawFractal(const std::vector<PtColor> &ColorIdxs) {
  Image Fractal(Geometry(XLen, YLen), "black");
  Fractal.magick("png");

  for (int i = 0; i < XLen; ++i)
    for (int j = 0; j < YLen; ++j) {
      auto PixelProps = ColorIdxs[i * XLen + j];
      if (PixelProps.first) {
        double Arg = PixelProps.second;
        ColorRGB C("black");
        // Red - blue, blue - green, green - red
        if (std::cos(Arg) >= 0.5) {
          double Norm = Arg / pi23 + 1.5;
          C.red(Norm);
          C.blue(1.0 - Norm);
        } else if (Arg <= 0) {
          double Norm = Arg / pi23 + 0.5;
          C.blue(Norm);
          C.green(1.0 - Norm);
        } else {
          double Norm = Arg / pi23 - 0.5;
          C.green(Norm);
          C.red(1.0 - Norm);
        }
        Fractal.pixelColor(i, j, C);
      }
    }

  Fractal.enhance();
  Fractal.write("FractalImage.png");
}
