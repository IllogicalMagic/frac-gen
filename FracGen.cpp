#include "Config.h"
#include "Drawer.h"
#include "Types.h"

#include <vector>

void getFractal(std::vector<PtColor> &ColorIdxs);

int main(int argc, char** argv) {
  std::vector<PtColor> ColorIdx;
  ColorIdx.resize(XLen * YLen);
  getFractal(ColorIdx);
  drawFractal(ColorIdx);
  return 0;
}
