#include "Config.h"
#include "Drawer.h"
#include "Types.h"

#include <vector>

std::vector<PtColor> getFractal();

int main(int argc, char** argv) {
  drawFractal(getFractal());
  return 0;
}
