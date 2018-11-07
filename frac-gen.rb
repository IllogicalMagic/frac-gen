#!/usr/bin/ruby2.3

require 'time'
require 'optparse'
require 'pp'
require 'erb'
require 'fileutils'

options = {}
OptionParser.new do |opts|
  opts.on("-s", "--seed NUM", "Generate with initial seed") { |v| options[:seed] = v }
  opts.on("-e", "--expr EXPR", "Use specified expression with fluctuations") { |v| options[:expr] = v }
  opts.on("-o", "--out-dir DIR", "Put results into specified directory") { |v| options[:dir] = v }
  opts.on("-m", "--method METHOD", "Iterative method name") { |v| options[:method] = v }
  opts.on("-c", "--disable-conditionals", "Disable ternary operators") { |v| options[:notern] = true }
end.parse!

notern = options[:notern] == true

$params = []
case options[:method].to_s.downcase
when "sidi", ""
  $method = "Sidi"
  $params = ["7"]
when "muller"
  $method = "Muller"
when "mixed"
  $method = "Mixed"
  $params = ["std::index_sequence<10, 5, 5>", "Sidi<4>", "Muller", "Steffenson"]
when "steffenson"
  $method = "Steffenson"
else
  fail "Unknown method"
end

$seed = (options[:seed] || Time.now).to_i
$rng = Random.new($seed)

class Func
  attr_reader :fn
  attr_reader :optype

  def initialize(fn, arity, optype)
    @fn = fn
    @arity = arity
    @optype = optype
  end

  def arity
    @arity ? @arity : $rng.rand(2..3)
  end
end

class Ternary
  def initialize
  end

  def operands
    if @operands
      @operands
    else
      cond = Node.new(log_fn[$rng.rand(log_fn.size)])
      op1 = Node.new(simple_fn[$rng.rand(simple_fn.size)])
      op2 = Node.new(simple_fn[$rng.rand(simple_fn.size)])
      @operands = [cond, op1, op2]
    end
  end
end

class Leaf
  attr_reader :fn

  def initialize(fn)
    @fn = fn
  end

  def arity
    0
  end
end

NM = "std::"

$main = self

def simple_fn
  if $main.instance_variable_defined?(:@fns)
    $main.instance_variable_get(:@fns)
  else
    $main.instance_variable_set(:@fns, [["+", nil, :simple_fn],
                                        ["-", nil, :simple_fn],
                                        ["*", nil, :simple_fn],
                                        ["/", nil, :simple_fn],
                                        [NM + "sin", 1, :simple_fn],
                                        [NM + "cos", 1, :simple_fn],
                                        [NM + "tan", 1, :simple_fn],
                                        [NM + "asin", 1, :simple_fn],
                                        [NM + "acos", 1, :simple_fn],
                                        [NM + "atan", 1, :simple_fn],
                                        [NM + "sinh", 1, :simple_fn],
                                        [NM + "cosh", 1, :simple_fn],
                                        [NM + "tanh", 1, :simple_fn],
                                        [NM + "asinh", 1, :simple_fn],
                                        [NM + "acosh", 1, :simple_fn],
                                        [NM + "atanh", 1, :simple_fn],
                                        [NM + "exp", 1, :simple_fn],
                                        [NM + "log", 1, :simple_fn],
                                        [NM + "sqrt", 1, :simple_fn],
                                        [NM + "pow", 2, :simple_fn]
                                       ].map{ |args| Func.new(*args) })
  end
end

def cmp_fn
  if $main.instance_variable_defined?(:@cmps)
    $main.instance_variable_get(:@cmps)
  else
    $main.instance_variable_set(:@cmps, [["<", 2, :simple_fn],
                                         [">", 2, :simple_fn],
                                         ["<=", 2, :simple_fn],
                                         [">=", 2, :simple_fn],
                                         ["==", 2, :simple_fn],
                                         ["!=", 2, :simple_fn],
                                        ].map{ |args| Func.new(*args) })
  end
end

def log_fn
  if $main.instance_variable_defined?(:@logs)
    $main.instance_variable_get(:@logs)
  else
    $main.instance_variable_set(:@logs, [["&&", nil, :cmp_fn],
                                         ["||", nil, :cmp_fn],
                                        ].map{ |args| Func.new(*args) })
  end
end

class BadExpr < StandardError
end

if notern
  $tern_prob = 1.0
  $init_func = lambda { simple_fn[$rng.rand(4)] }
  $max_prob = 2.0
else
  $tern_prob = 1.2
  $init_func = lambda { Ternary.new }
  $max_prob = 2.5
end

$level = nil

class Node
  Point = 'Pt'
  Num = 'num'

  def initialize(fn)
    if $level == 1000
      $level = 0
      fail BadExpr
    end
    $level += 1

    @fn = fn
    # If function has predefined set of operands
    # (like ternary operator) just use it.
    # Otherwise generate some new operands.
    if @fn.respond_to?(:operands)
      @operands = @fn.operands
    else
      @operands = Array.new(fn.arity).map do |op|
        if (@fn.optype != :simple_fn)
          sel = $main.send(@fn.optype)
          fn = sel[$rng.rand(sel.size)]
          Node.new(fn)
        else
          r = $rng.rand(simple_fn.size * $max_prob)
          # Simple function.
          if (r < simple_fn.size)
            fn = simple_fn[$rng.rand(simple_fn.size)]
            Node.new(fn)
          # Ternary.
          elsif r < simple_fn.size * $tern_prob
            Node.new(Ternary.new)
          # Leaf.
          else
            Node.new(Leaf.new($rng.rand() < 0.7 ? Point : Num))
          end
        end
      end
    end
  end

  def to_s
    ops = @operands.map{ |o| o.to_s }
    res = case
          when @fn.is_a?(Ternary)
            ops[0].to_s + " ? " + ops[1].to_s + " : "  + ops[2].to_s
          when ['*','/','+','-','**'].include?(@fn.fn)
            ops.join(" #{@fn.fn} ")
          when log_fn.map{ |f| f.fn }.include?(@fn.fn)
            ops.map{ |o| o.to_s }.join(" #{@fn.fn} ")
          when cmp_fn.map{ |f| f.fn }.include?(@fn.fn)
            ops.map{ |o| "std::abs(#{o.to_s})" }.join(" #{@fn.fn} ")
          when [Point, Num].include?(@fn.fn)
            @fn.fn
          else
            @fn.fn + "(" + ops.join(", ") + ")"
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
    $level = 0
    @fn = Node.new($init_func.call)
    $level = 0
    @fn2 = Node.new($init_func.call)
  end

  def to_s
    if @expr.nil?
      @expr = "ValType Fn1 = #{@fn};\n"
      @expr += "ValType Fn2 = #{@fn2};\n"
      @expr += "return std::abs(Fn1 - Fn2) - 1.0;"
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

FRACMATH = 'FracMath.cpp'

$num = $seed
Dir.mkdir("Images") unless Dir.exist?("Images")
if options[:dir]
  $dir = options[:dir]
else
  $dir = File.join("Images", "#{$seed.to_s}_#{$method}")
  Dir.mkdir($dir)
end
$log = File.open(File.join($dir, "last_seed.txt"), "w")
$log << "Seed: #{$seed}\n"

def generate_image(expr)
  method = $method
  if $params.empty?
    method_params = ""
  else
    method_params = [$params[0]] + $params[1..-1].map{ |p| "CalcNext#{p}" }
    method_params = method_params.join(", ")
    method_params = "<#{method_params}>"
  end
  File.open(FRACMATH, "w") do |f|
    f << ERB.new(File.read(FRACMATH + ".erb")).result(binding)
  end
  puts expr
  $log.puts("#{$num}: #{expr}")
  res = system("make FracGen && ./FracGen")
  if res.nil?
    fail "Bad make or fracgen"
  end
  fi = "FractalImage#{$num}.png"
  File.rename("FractalImage.png", fi)
  FileUtils.mv(fi, $dir)
end

if options[:expr].nil?
  loop do
    break if $stop
    begin
      expr_tree = Expr.new
    rescue BadExpr => e
      next
    end
    expr = expr_tree.to_s
    generate_image(expr)
    $num += 1
  end
else
  expr = options[:expr]
  subst_num = 0.0
  loop do
    expr_subst = expr.sub("NUM", subst_num.to_s)
    generate_image(expr_subst)
    subst_num += 0.01
    $num += 1
  end
end

$log.close
