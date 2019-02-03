#!/usr/bin/ruby2.3

require 'time'
require 'optparse'
require 'pp'
require 'erb'
require 'fileutils'

require_relative 'Scripts/exprtree'

options = {}
OptionParser.new do |opts|
  opts.on("-s", "--seed NUM", "Generate with initial seed") { |v| options[:seed] = v }
  opts.on("-e", "--expr EXPR", "Use specified expression with fluctuations") { |v| options[:expr] = v }
  opts.on("-o", "--out-dir DIR", "Put results into specified directory") { |v| options[:dir] = v }
  opts.on("-m", "--method METHOD", "Iterative method name") { |v| options[:method] = v }
  opts.on("-c", "--disable-conditionals", "Disable ternary operators") { |v| options[:notern] = true }
  opts.on("-a", "--with-abs VAL", "Find absolute value of function, not zeros") { |v| options[:abs] = v }
  opts.on("-d", "--diff-expr EXPR", "Considered to be first derivative of expression specified in --expr") { |v| options[:diff] = v }
end.parse!

$params = []
$need_diff = false
case options[:method].to_s.downcase
when "sidi", ""
  $method = "Sidi"
  $params = ["7"]
when "sidi_error"
  $method = "SidiErroneus"
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

notern = options[:notern] == true
ExprTree.set_tern_mode(!notern)

seed = (options[:seed] || Time.now).to_i
ExprTree.init_rng(seed)

$abs = options[:abs]

# Check generator mode paramenters.
if options[:expr].nil?
  if $need_diff and (!$abs.nil? or notern != true)
    fail "Conditionals or absolute values are not allowed with methods that need derivative!"
  end
else
  if $need_diff and options[:diff].nil?
    fail "Method needs derivative of specified function!"
  end
end

$stop = false

Signal.trap("INT") do
  puts "Stopping..."
  exit(0)
end

FRACMATH = 'FracMath.cpp'

$num = seed
Dir.mkdir("Images") unless Dir.exist?("Images")
if options[:dir]
  $dir = options[:dir]
else
  $dir = File.join("Images", "#{seed.to_s}_#{$method}")
  Dir.mkdir($dir)
end
$log = File.open(File.join($dir, "last_seed.txt"), "w")
$log << "Seed: #{seed}\n"

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

DEFAULT_EXPR = "abort(); return 0.0;"

def wrap_expr(expr)
  if expr.nil?
    DEFAULT_EXPR
  else
    expr = "std::abs(#{expr}) - #{$abs}" if $abs
    "return #{expr};"
  end
end

if options[:expr].nil?
  loop do
    break if $stop
    begin
      expr_tree = ExprTree::Expr.new
      expr_tree_diff = expr_tree.diff if $need_diff
    rescue ExprTree::BadExpr => e
      next
    end
    expr = wrap_expr(expr_tree.to_s)
    if $need_diff
      expr_diff = expr_tree_diff.to_s
    else
      expr_diff = nil
    end
    expr_diff = wrap_expr(expr_diff)
    puts expr
    puts expr_diff
    generate_image(expr, expr_diff)
    $num += 1
  end
else
  expr = options[:expr]
  expr_diff = options[:diff] || DEFAULT_EXPR
  subst_num = 0.0
  loop do
    expr_subst = expr.sub("NUM", subst_num.to_s)
    generate_image(expr_subst, expr_diff)
    subst_num += 0.01
    $num += 1
  end
end

$log.close
