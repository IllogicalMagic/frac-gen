# FracGen
Simple fractal (and more) generator.

## Prerequisites
To compile FracGen you will need the following:
* GNU make
* Any C++ compiler supporting C++17 standard
* libMagick++ (version 6)
* Ruby (tested on 2.3.0)

## How to run
Just clone sources to some directory and try `./frac-gen.rb`. Probably you will need to change interpreter version in frac-gen.rb (first line) and compiler (CXX) in Makefile. When this is done frac-gen will generate first expression and start to build FracGen to calculate image. Then FracGen will draw image and place it in Images/{seed}_{method} subdirectory. If frac-gen succeed to generate first image then it will work for every other mode.

## How to reproduce image using configuration file
To reproduce image you should get a configuration file with parameter values and expression. Once you have this file run frac-gen with following commang `./frac-gen.rb --config=<configuration file>`. Also you can specify output directory. If latter is not specified frac-gen will create directory in Images named this way: \<expr\_num\>\_\<method\>\_reproduce.

## Supported options
frac-gen.rb has some options to control what method is used, how it is used and how expressions are generated. Current list of options:
* `--help` -- contains the most recent version of list of options. This readme is not always updated.
* `--seed=NUM` -- use specified seed for expression generation.
* `--expr=expression` -- generate image for specified expression.
* `--out-dir=DIR` -- put images in specified directory.
* `--method=method` -- use specified method for generation. List of available methods can be seen in frac-gen.rb (starting from line 26).
* `--disable-conditionals` -- generate only simple expressions without ternary operators.
* `--with-abs=NUM` -- generate functions of the form `|fn| = NUM`.
* `--diff-exp=EXPR` -- considered to be derivative of expression specified in --expr parameter.

## Known issues
GCC can hang while compiling some mathematical expressions.
