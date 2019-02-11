#!/usr/bin/ruby2.3

require 'time'
require 'optparse'
require 'pp'
require 'erb'
require 'fileutils'

require_relative 'Scripts/exprtree'
require_relative 'Scripts/config'

options = {}
OptionParser.new do |opts|
  opts.on("-s", "--seed NUM", "Generate with initial seed") { |v| options[:seed] = v }
  opts.on("-o", "--out-dir DIR", "Put results into specified directory") { |v| options[:dir] = v }
  opts.on("-m", "--method METHOD", "Iterative method name") { |v| options[:method] = v }
  opts.on("-c", "--disable-conditionals", "Disable ternary operators") { |v| options[:notern] = true }
  opts.on("-a", "--with-abs VAL", "Find absolute value of function, not zeros") { |v| options[:abs] = v }
  opts.on("-g", "--config CFG", "Specify configuration file") { |v| options[:cfg] = v }
  opts.on("-e", "--epsilon E", "Specify accuracy of calculation") { |v| options[:epsilon] = v }
  opts.on("-n", "--norm N", "Specify used metric norm") { |v| options[:norm] = v }
  opts.on("-l", "--scale S", "Specify scale") { |v| options[:scale] = v }
  opts.on("-i", "--iters I", "Specify number of iterations") { |v| options[:iters] = v }
  opts.on("", "--x-center X", "Specify X coordinate of center") { |v| options[:c_x] = v }
  opts.on("", "--y-center Y", "Specify Y coordinate of center") { |v| options[:c_y] = v }
  opts.on("-x", "--length L", "Specify image length in pixels") { |v| options[:xlen] = v }
  opts.on("-y", "--height H", "Specify image height in pixels") { |v| options[:ylen] = v }
end.parse!

FRACMATH_FILE = 'FracMath.raw.cpp'
CONFIG_FILE = 'Config.raw.h'
NORM_FILE = 'Norm.X.raw.h'

DEFAULT_SCALE = 20.0
DEFAULT_ITERS = 25
DEFAULT_EPSILON = 0.05
DEFAULT_C_X = 0.0
DEFAULT_C_Y = 0.0
DEFAULT_XLEN = 1000
DEFAULT_YLEN = 1000
DEFAULT_NORM = "norm2"

DEFAULT_EXPR = "abort(); return 0.0;"

def get_cfg_opts(cfg)
  opts = cfg.load_header
end

def reproduce_exprs_mode(cfg_opts, exprs, opts)
  method = cfg_opts.fetch(:method)

  if opts[:dir]
    dir = opts[:dir]
  else
    Dir.mkdir("Images") unless Dir.exist?("Images")
    dir = File.join("Images", "#{Time.now.to_i}_#{method}_reproduce")
    Dir.mkdir(dir)
  end

  fill_missed_opts(cfg_opts)

  configure_sources(cfg_opts)

  params = cfg_opts[:params] || ""
  unless params.empty?
    method += "<#{params}>"
  end

  exprs.each do |e|
    generate_image(method, e[:expr], e[:diff_expr])

    fi = "FractalImage#{e[:num]}.png"
    File.rename("FractalImage.png", fi)
    FileUtils.mv(fi, dir)
  end
end

def select_method(method)
  params = []
  need_diff = false
  case method.to_s.downcase
  when "sidi", ""
    method = "Sidi"
    params = ["7"]
  when "sidi_error"
    method = "SidiErroneus"
    params = ["7"]
  when "muller"
    method = "Muller"
  when "mixed_random"
    method = "MixedRandom"
    params = ["std::index_sequence<10, 5>", "%MSidi<4>", "%MContractor"]
  # $need_diff = true
  when "mixed"
    method = "Mixed"
    params = ["%MInvertedContractor", "%MLogContractor", "%MContractor"]
  # $need_diff = true
  when "steffensen"
    method = "Steffensen"
  when "newton"
    method = "Newton"
    need_diff = true
  when "chord"
    method = "Chord"
  when "contractor"
    method = "Contractor"
  when "inverted_contractor"
    method = "InvertedContractor"
  when "log_contractor"
    method = "LogContractor"
  else
    fail "Unknown method"
  end

  [method, params, need_diff]
end

def fill_missed_opts(opts)
  opts[:epsilon] ||= DEFAULT_EPSILON
  opts[:norm] ||= DEFAULT_NORM
  opts[:scale] ||= DEFAULT_SCALE
  opts[:iters] ||= DEFAULT_ITERS
  opts[:c_x] ||= DEFAULT_C_X
  opts[:c_y] ||= DEFAULT_C_Y
  opts[:xlen] ||= DEFAULT_XLEN
  opts[:ylen] ||= DEFAULT_YLEN
end

def configure_sources(opts)
  epsilon = opts[:epsilon]
  norm = opts[:norm]
  scale = opts[:scale]
  iters = opts[:iters]
  c_x = opts[:c_x]
  c_y = opts[:c_y]
  xlen = opts[:xlen]
  ylen = opts[:ylen]

  file = CONFIG_FILE.sub(".raw", "")
  File.open(file, "w") do |f|
    f << ERB.new(File.read(CONFIG_FILE)).result(binding)
  end

  file = NORM_FILE.sub(".raw", "")
  File.open(file, "w") do |f|
    f << ERB.new(File.read(NORM_FILE)).result(binding)
  end
end

# TODO: unite with produce_with_cfg_mode somehow.
def produce_mode(opts)
  method, params, need_diff = select_method(opts[:method])

  notern = opts[:notern] == true
  ExprTree.set_tern_mode(!notern)

  seed = (opts[:seed] || Time.now).to_i
  ExprTree.init_rng(seed)

  $abs = opts[:abs]
  # Check generator mode paramenters.
  if need_diff and (!$abs.nil? or notern != true)
    fail "Conditionals or absolute values are not allowed with methods that need derivative!"
  end

  if opts[:dir]
    dir = opts[:dir]
  else
    Dir.mkdir("Images") unless Dir.exist?("Images")
    dir = File.join("Images", "#{seed.to_s}_#{method}")
    Dir.mkdir(dir)
  end
  cfg_name = File.join(dir, "config.txt")
  cfg = Config::Config.new(file: cfg_name, read: false)

  fill_missed_opts(opts)

  unless params.empty?
    params = params.map{ |p| p.sub("%M", "CalcNext") }
  end
  params = params.join(", ")

  cfg.save_header(method: method, method_params: params,
                  opts: opts)

  configure_sources(opts)

  unless params.empty?
    method += "<#{params}>"
  end

  produce(dir, method, need_diff, seed, cfg)

  cfg.close
end

def method_need_diff?(method, params)
  method.include?("Newton") || params.include?("Newton")
end

def produce_with_cfg_mode(cfg_opts, opts)
  method = cfg_opts.fetch(:method)
  params = cfg_opts[:params] || ""
  need_diff = method_need_diff?(method, params)

  notern = opts[:notern] == true
  ExprTree.set_tern_mode(!notern)

  seed = (opts[:seed] || Time.now).to_i
  ExprTree.init_rng(seed)

  $abs = opts[:abs]
  # Check generator mode paramenters.
  if need_diff and (!$abs.nil? or notern != true)
    fail "Conditionals or absolute values are not allowed with methods that need derivative!"
  end

  if opts[:dir]
    dir = opts[:dir]
  else
    Dir.mkdir("Images") unless Dir.exist?("Images")
    dir = File.join("Images", "#{seed.to_s}_#{method}_cfg")
    Dir.mkdir(dir)
  end
  cfg_name = File.join(dir, "config.txt")
  cfg = Config::Config.new(file: cfg_name, read: false)

  fill_missed_opts(cfg_opts)

  cfg.save_header(method: method, method_params: params,
                  opts: cfg_opts)

  configure_sources(cfg_opts)

  unless params.empty?
    method += "<#{params}>"
  end

  produce(dir, method, need_diff, seed, cfg)

  cfg.close
end

def wrap_expr(expr)
  if expr.nil?
    DEFAULT_EXPR
  else
    expr = "std::abs(#{expr}) - #{$abs}" if $abs
    "return #{expr};"
  end
end

def produce(dir, method, need_diff, num, cfg)
  loop do
    break if $stop
    begin
      expr_tree = ExprTree::Expr.new
      expr_tree_diff = expr_tree.diff if need_diff
    rescue ExprTree::BadExpr => e
      next
    end
    expr = wrap_expr(expr_tree.to_s)
    if need_diff
      expr_diff = expr_tree_diff.to_s
    else
      expr_diff = nil
    end
    expr_diff = wrap_expr(expr_diff)

    puts expr
    puts expr_diff
    cfg.save_expr(num: num, expr: expr, diff_expr: expr_diff)

    generate_image(method, expr, expr_diff)

    fi = "FractalImage#{num}.png"
    File.rename("FractalImage.png", fi)
    FileUtils.mv(fi, dir)

    num += 1
  end
end

def generate_image(method, expr, expr_diff)
  fracmath = FRACMATH_FILE.sub(".raw", "")
  File.open(fracmath, "w") do |f|
    f << ERB.new(File.read(FRACMATH_FILE)).result(binding)
  end
  res = system("make FracGen && ./FracGen")
  if res.nil?
    fail "Bad make or fracgen"
  end
end

$stop = false

Signal.trap("INT") do
  puts "Stopping..."
  exit(0)
end

# Clean up directory before generation.
system("make clean")

config = options[:cfg]

if config
  cfg = Config::Config.new(file: config, read: true)
  cfg_opts = get_cfg_opts(cfg)
  exprs = cfg.load_exprs
  if exprs.empty?
    produce_with_cfg_mode(cfg_opts, options)
  else
    reproduce_exprs_mode(cfg_opts, exprs, options)
  end
  cfg.close
else
  produce_mode(options)
end

