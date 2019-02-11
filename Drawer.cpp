#include "Color.h"
#include "Config.h"
#include "Drawer.h"

#include <Magick++.h>

#include <cstdio>
#include <cmath>

using namespace Magick;

auto drawFractal(const std::vector<PtColor> ColorIdxs) -> void {
  Image Fractal(Geometry(XLen, YLen), "black");
  Fractal.magick("png");

  for (int i = 0; i < XLen; ++i)
    for (int j = 0; j < YLen; ++j) {
      const auto &PixelProps = ColorIdxs[i * YLen + j];
      if (PixelProps.first) {
        auto ColorVals = PixelProps.second.getRGB();
        ColorRGB C("black");
        C.red(std::get<0>(ColorVals));
        C.green(std::get<1>(ColorVals));
        C.blue(std::get<2>(ColorVals));
        Fractal.pixelColor(i, j, C);
      }
    }

  Fractal.enhance();
  Fractal.write("FractalImage.png");
}
