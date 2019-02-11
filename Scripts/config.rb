module Config

  class Config

    def initialize(file:,read:)
      mode = read ? "r" : "w"
      @file = File.open(file, mode)
    end

    PARAM_TO_SYM = {"Method" => :method,
                    "Method parameters" => :method_params,
                    "Epsilon" => :epsilon,
                    "Norm" => :norm,
                    "Scale" => :scale,
                    "Iterations" => :iters,
                    "X of center" => :c_x,
                    "Y of center" => :c_y,
                    "Length of image" => :xlen,
                    "Height of image" => :ylen}
    def load_header
      hdr = @file.gets.rstrip
      fail "No header in config" if hdr != "--- HEADER ---"
      config = Hash.new
      line = @file.gets
      begin
        param, value = line.split(":", 2).map(&:strip)
        # value = value.to_s
        if param.nil? || value.nil?
          fail "Bad line '#{line}' in config"
        end

        sym = PARAM_TO_SYM[param]
        if sym.nil?
          fail "Unknown parameter '#{param}' in config"
        end
        config[sym] = value

        line = @file.gets
        fail "Bad config" if line.nil?
      end while line.rstrip != "--- HEADER ---"

      config
    end

    def load_exprs
      exprs = Array.new
      line = @file.gets
      loop do
        break if line.nil?
        fail "Bad expression" if line.rstrip != "--- EXPR ---"

        # Num: num
        line = @file.gets
        fail "Missing num in expression" if line.nil?
        param, num = line.split(": ").map(&:strip)
        if param != "Num" || num.nil?
          fail "Bad num parameter in expresion"
        end

        # Expr: expr
        expr = ""
        line = @file.gets
        while !line.start_with?("Diff expr: ")
          fail "Missing expr in expression" if line.nil?
          expr += line
          line = @file.gets
        end
        if !expr.start_with?("Expr: ")
          fail "Bad expr parameter in expression"
        end
        expr = expr.sub("Expr: ", "")

        # Diff expr: expr
        diff_expr = ""
        while !line.start_with?("--- EXPR ---")
          diff_expr += line
          line = @file.gets
          break if line.nil?
        end
        if !diff_expr.start_with?("Diff expr: ")
          fail "Bad diff expr parameter in expression"
        end
        diff_expr = diff_expr.sub("Diff expr: ", "")

        exprs << {num: num, expr: expr, diff_expr: diff_expr}
      end

      exprs
    end

    def save_header(method:, method_params:, opts:)
      @file.puts("--- HEADER ---")
      @file.puts("Method: #{method}")
      @file.puts("Method parameters: #{method_params}")
      @file.puts("Epsilon: #{opts.fetch(:epsilon)}")
      @file.puts("Norm: #{opts.fetch(:norm)}")
      @file.puts("Scale: #{opts.fetch(:scale)}")
      @file.puts("Iterations: #{opts.fetch(:iters)}")
      @file.puts("X of center: #{opts.fetch(:c_x)}")
      @file.puts("Y of center: #{opts.fetch(:c_y)}")
      @file.puts("Length of image: #{opts.fetch(:xlen)}")
      @file.puts("Height of image: #{opts.fetch(:ylen)}")
      @file.puts("--- HEADER ---")
    end

    def save_expr(num:, expr:, diff_expr:)
      @file.puts("--- EXPR ---")
      @file.puts("Num: #{num}")
      @file.puts("Expr: #{expr}")
      @file.puts("Diff expr: #{diff_expr}")
    end

    def close
      @file.close
    end

  end # class Config

end # module Config
