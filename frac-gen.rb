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
  opts.on("-a", "--with-abs VAL", "Find absolute value of function, not zeros") { |v| options[:abs] = v }
end.parse!

notern = options[:notern] == true
$abs = options[:abs]

$params = []
$need_diff = false
case options[:method].to_s.downcase
when "sidi", ""
  $method = "Sidi"
  $params = ["7"]
when "muller"
  $method = "Muller"
when "mixed_random"
  $method = "MixedRandom"
  $params = ["std::index_sequence<10, 5>", "%MSidi<4>", "%MContractor"]
# $need_diff = true
when "mixed"
  $method = "Mixed"
  $params = ["%MInvertedContractor", "%MLogContractor", "%MContractor"]
# $need_diff = true
when "steffensen"
  $method = "Steffensen"
when "newton"
  $method = "Newton"
  $need_diff = true
when "chord"
  $method = "Chord"
when "contractor"
  $method = "Contractor"
when "inverted_contractor"
  $method = "InvertedContractor"
when "log_contractor"
  $method = "LogContractor"
else
  fail "Unknown method"
end

if $need_diff and (!$abs.nil? or notern != true)
  fail "Conditionals or absolute values are not allowed with methods that need derivative!"
end

$seed = (options[:seed] || Time.now).to_i
$rng = Random.new($seed)

NM = "std::"

class Func
  attr_reader :fn
  attr_reader :optype
  attr_accessor :operands

  def initialize(fn, arity, optype, operands = nil)
    @fn = /^[[:alpha]]/.match(fn) ? NM + fn : fn
    @arity = arity
    @optype = optype
    @operands = operands if operands
  end

  def arity
    @arity ? @arity : $rng.rand(2..3)
  end

  def n(func)
    Node.new(func)
  end

  def get_inv(op, neg = false, value = nil)
    if value
      val = value
    else
      val = neg ? "-1.0" : "1.0"
    end
    n(Func.new("/", 2, nil, [n(Leaf.new(val)), op]))
  end

  def get_sqr(op)
    n(Func.new("*", 2, nil, [op, op]))
  end

  def get_prd(op1, op2)
    n(Func.new("*", 2, nil, [op1, op2]))
  end

  def get_x_m_one(op, inv = false)
    ops = [op, n(Leaf.new("1.0"))]
    ops = ops.reverse if inv
    n(Func.new("-", 2, nil, ops))
  end

  def get_x_p_one(op, inv = false)
    n(Func.new("+", 2, nil, [op, n(Leaf.new("1.0"))]))
  end

  def get_sqrt(op)
    n(Func.new("sqrt", 1, nil, [op]))
  end

  def diff
    func = @fn.sub(NM, "")
    case func
    when "+", "-"
      new_ops = @operands.map{ |o| o.diff }
      res = Func.new(func, new_ops.size, nil, new_ops)
    when "*"
      new_ops = Array.new
      @operands.each_with_index do |o, i|
        ops = @operands[0...i] + @operands[(i + 1)..-1]
        mult = n(Func.new("*", @operands.size, nil, [o.diff] + ops))
        new_ops << mult
      end
      res = Func.new("+", new_ops.size, nil, new_ops)
    when "/"
      # Like * but should invert all but first operands.
      if @operands.size != 2
        invops = Array.new
        invops = @operands[1..-1].map do |op|
          get_inv(op)
        end
        invops << @operands[0]
        inverted = Func.new("*", @operands.size, nil, invops)
        res = inverted.diff
      else
        op1 = @operands[0]
        op2 = @operands[1]
        sqr = get_sqr(op2)
        op1d = op1.diff
        op2d = op2.diff
        lhs = get_prd(op1d, op2)
        rhs = get_prd(op1, op2d)
        diff = n(Func.new("-", 2, nil, [lhs, rhs]))
        res = Func.new("/", 2, nil, [diff, sqr])
      end
    when "sin"
      op = @operands.first
      drv = n(Func.new("cos", 1, nil, [op]))
      res = get_prd(drv, op.diff)
    when "cos"
      op = @operands.first
      dcos = n(Func.new("sin", 1, nil, [op]))
      drv = n(Func.new("*", 2, nil, [dcos, n(Leaf.new("-1.0"))]))
      res = get_prd(drv, op.diff)
    when "tan"
      op = @operands.first
      cos = n(Func.new("cos", 1, nil, [op]))
      sqr = get_sqr(cos)
      drv = get_inv(sqr)
      res = get_prd(drv, op.diff)
    when "asin", "acos"
      op = @operands.first
      sqr = get_sqr(op)
      diff = get_x_m_one(sqr, true)
      sqrt = get_sqrt(diff)
      drv = get_inv(sqrt, func == "acos")
      res = get_prd(drv, op.diff)
    when "atan"
      op = @operands.first
      sqr = get_sqr(op)
      sum = get_x_p_one(sqr)
      drv = get_inv(sum)
      res = get_prd(drv, op.diff)
    when "sinh"
      op = @operands.first
      drv = n(Func.new("cosh", 1, nil, [op]))
      res = get_prd(drv, op.diff)
    when "cosh"
      op = @operands.first
      drv = n(Func.new("sinh", 1, nil, [op]))
      res = get_prd(drv, op.diff)
    when "tanh"
      op = @operands.first
      cosh = n(Func.new("cosh", 1, nil, [op]))
      sqr = get_sqr(cosh)
      drv = get_inv(sqr)
      res = get_prd(drv, op.diff)
    when "asinh", "acosh"
      op = @operands.first
      sqr = get_sqr(op)
      poly = func == "asinh" ? get_x_p_one(sqr) : get_x_m_one(sqr)
      sqrt = get_sqrt(poly)
      drv = get_inv(sqrt)
      res = get_prd(drv, op.diff)
    when "atanh"
      op = @operands.first
      sqr = get_sqr(op)
      diff = get_x_m_one(sqr, true)
      drv = get_inv(diff)
      res = get_prd(drv, op.diff)
    when "exp"
      op = @operands.first
      drv = n(Func.new("exp", 1, nil, [op]))
      res = get_prd(drv, op.diff)
    when "log"
      op = @operands.first
      drv = get_inv(op)
      res = get_prd(drv, op.diff)
    when "sqrt"
      op = @operands.first
      sqrt = get_sqrt(op)
      drv = get_inv(sqrt, false, "0.5")
      res = get_prd(drv, op.diff)
    when "pow"
      base = @operands[0]
      pow = @operands[1]
      log = n(Func.new("log", 1, nil, [base]))
      to_exp_ops = get_prd(log, pow)
      to_exp = n(Func.new("exp", 1, nil, [to_exp_ops]))
      res = to_exp.diff
    else
      fail "Unknown functions"
    end
    res.is_a?(Node) ? res : n(res)
  end

end

class Ternary
  def initialize
  end

  def operands
    if @operands
      @operands
    else
      cond = Node.new(log_fn[$rng.rand(log_fn.size)].clone)
      op1 = Node.new(simple_fn[$rng.rand(simple_fn.size)].clone)
      op2 = Node.new(simple_fn[$rng.rand(simple_fn.size)].clone)
      @operands = [cond, op1, op2]
    end
  end
end

Point = 'Pt'
Num = 'num'

class Leaf
  attr_reader :fn

  def initialize(fn)
    case fn
    when Point
      @fn = fn
    when Num
      @fn = "ValType(#{$rng.rand()}, #{$rng.rand()})"
    else
      @fn = fn
    end
  end

  def arity
    0
  end

  def operands
    []
  end

  def diff
    case @fn
    when Point
      r = Leaf.new('1.0')
    else
      r = Leaf.new('0.0')
    end
    Node.new(r)
  end
end

$main = self

def simple_fn
  if $main.instance_variable_defined?(:@fns)
    $main.instance_variable_get(:@fns)
  else
    $main.instance_variable_set(:@fns, [
                                  ["+", nil, :simple_fn],
                                  ["-", nil, :simple_fn],
                                  ["*", nil, :simple_fn],
                                  ["/", nil, :simple_fn],
                                  ["sin", 1, :simple_fn],
                                  ["cos", 1, :simple_fn],
                                  ["tan", 1, :simple_fn],
                                  ["asin", 1, :simple_fn],
                                  ["acos", 1, :simple_fn],
                                  ["atan", 1, :simple_fn],
                                  ["sinh", 1, :simple_fn],
                                  ["cosh", 1, :simple_fn],
                                  ["tanh", 1, :simple_fn],
                                  ["asinh", 1, :simple_fn],
                                  ["acosh", 1, :simple_fn],
                                  ["atanh", 1, :simple_fn],
                                  ["exp", 1, :simple_fn],
                                  ["log", 1, :simple_fn],
                                  ["sqrt", 1, :simple_fn],
                                  ["pow", 2, :simple_fn]
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
  sz = simple_fn.size
  sz = sz < 4 ? sz : 4
  $init_func = lambda { simple_fn[$rng.rand(sz)].clone }
  $max_prob = 2.0
else
  $tern_prob = 1.2
  $init_func = lambda { Ternary.new }
  $max_prob = 2.5
end

$level = nil

class Node
  attr_reader :operands
  attr_reader :fn

  def initialize(fn)
    if $level == 2000
      $level = 0
      fail BadExpr
    end
    $level += 1

    @fn = fn
    # If function has predefined set of operands
    # (like ternary operator) just use it.
    # Otherwise generate some new operands.
    if @fn.operands
      @operands = @fn.operands
    else
      @operands = Array.new(fn.arity).map do |op|
        if (@fn.optype != :simple_fn)
          sel = $main.send(@fn.optype)
          fn = sel[$rng.rand(sel.size)]
          Node.new(fn.clone)
        else
          r = $rng.rand(simple_fn.size * $max_prob)
          # Simple function.
          if (r < simple_fn.size)
            fn = simple_fn[$rng.rand(simple_fn.size)]
            Node.new(fn.clone)
          # Ternary.
          elsif r < simple_fn.size * $tern_prob
            Node.new(Ternary.new)
          # Leaf.
          else
            Node.new(Leaf.new($rng.rand() < 0.7 ? Point : Num))
          end
        end
      end
      @fn.operands = @operands
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
          when @fn.is_a?(Leaf)
            @fn.fn
          else
            @fn.fn + "(" + ops.join(", ") + ")"
          end
    "(" + res + ")"
  end

  def diff
    unless simple_fn.any?{ |f| f.fn == @fn.fn } || @fn.is_a?(Leaf)
      fail "Can get derivative only from simple functions"
    end
    @fn.diff
  end

  def evaluate
    pt = 12.0
    expr = to_s.gsub('num') { $rng.rand().to_s }
    eval(expr, binding)
  end
end

class Expr
  def initialize(node = nil)
    $level = 0
    if node
      @fn = node
    else
      @fn = Node.new($init_func.call)
    end
  end

  def to_s
    if @expr.nil?
      if $abs
        fn = "std::abs(#{@fn}) - ValType(#{$abs}, 0.0)"
      else
        fn = "#{@fn}"
      end
      @expr = "ValType Fn1 = #{fn};\n"
      @expr += "return Fn1;"
    else
      @expr
    end
  end

  def diff
    $level = 0
    Expr.new(@fn.diff)
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

def generate_image(expr, expr_diff)
  method = $method
  if $params.empty?
    method_params = ""
  else
    method_params = $params.map{ |p| p.sub("%M", "CalcNext") }
    method_params = method_params.join(", ")
    method_params = "<#{method_params}>"
  end
  File.open(FRACMATH, "w") do |f|
    f << ERB.new(File.read(FRACMATH + ".erb")).result(binding)
  end
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
      expr_tree_diff = expr_tree.diff if $need_diff
    rescue BadExpr => e
      next
    end
    expr = expr_tree.to_s
    if $need_diff
      expr_diff = expr_tree_diff.to_s
    else
      expr_diff = "abort(); return 0.0;"
    end
    puts expr
    puts expr_diff
    generate_image(expr, expr_diff)
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
