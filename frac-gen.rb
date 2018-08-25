#!/usr/bin/ruby2.3

require 'time'
require 'optparse'
require 'pp'
require 'erb'
require 'fileutils'

$seed = Time.now.to_i
$rng = Random.new($seed)

NM = "std::"
FNS = [[NM + "sin", 1],
       [NM + "cos", 1],
       [NM + "tan", 1],
       [NM + "asin", 1],
       [NM + "acos", 1],
       [NM + "atan", 1],
       [NM + "sinh", 1],
       [NM + "cosh", 1],
       [NM + "tanh", 1],
       [NM + "asinh", 1],
       [NM + "acosh", 1],
       [NM + "atanh", 1],
       [NM + "exp", 1],
       [NM + "log", 1],
       [NM + "sqrt", 1],
       [NM + "pow", 2],
       ["+", nil],
       ["-", nil],
       ["*", nil],
       ["/", nil]]

class Node
  Point = 'Pt'
  Num = 'num'

  def initialize(fn, arity)
    @fn = fn
    @operands = Array.new(arity).map do |op|
      r = $rng.rand(FNS.size * 2)
      if r < FNS.size
        fn = FNS[r]
        ops = fn[1] ? fn[1] : $rng.rand(2..4)
        Node.new(fn[0], ops)
      else
        if $rng.rand() < 0.7
          Node.new(Point, 0)
        else
          Node.new(Num, 0)
        end
      end
    end
  end

  def to_s
    ops = @operands.map{ |o| o.to_s }
    res = case
          when ['*','/','+','-','**'].include?(@fn)
            ops.join(" #{@fn} ")
          when [Point, Num].include?(@fn)
            @fn
          else
            @fn + "(" + ops.join(", ") + ")"
          end
    "(" + res + ")"
  end

  def evaluate
    pt = 12.0
    expr = to_s.gsub('num') { $rng.rand().to_s }
    eval(expr, binding)
  end
end

class Expr
  def initialize()
    @fn = Node.new('+', 2)
  end

  def to_s
    if @expr.nil?
      @expr = "std::abs(#{@fn}) - 1.0"
      @expr.to_s.gsub('num'){ "ValType(#{$rng.rand()}, #{$rng.rand()})" }
    else
      @expr
    end
  end

  def evaluate(x)
    pt = x
    eval(to_s, binding)
  end
end

$stop = false

Signal.trap("INT") do
  puts "Stopping..."
  exit(0)
end

fracmath = 'FracMathSidi.cpp'

num = $seed
dir = File.join("Images", $seed.to_s)
Dir.mkdir(dir)
File.open(File.join(dir, "last_seed.txt"), "w") do |f|
  f << "Seed: #{$seed}\n"
end

loop do
  break if $stop
  expr = Expr.new.to_s
  File.open(fracmath, "w") do |f|
    f << ERB.new(File.read(fracmath + ".erb")).result(binding)
  end
  res = system("make FracGen && ./FracGen")
  if res.nil?
    fail "Bad make or fracgen"
  end
  fi = "FractalImage#{num}.png"
  File.rename("FractalImage.png", fi)
  FileUtils.mv(fi, dir)
  num += 1
end
