module ExprTree

  def self.set_tern_mode(val)
    $generate_ternary = val
  end

  def self.init_rng(seed)
    $rng = Random.new(seed)
  end

  class BadExpr < StandardError
  end

  Point = 'Pt'
  Num = 'num'

  class Node
    attr_reader :operands
    attr_reader :fn

    def generate_operand(type, level)
      case type
      when :point
        Leaf.new(Point)
      when :num
        Leaf.new(Num)
      when :tern
        Ternary.new(level + 1)
      else
        sel = ExprTree.send(type)
        ops = sel[$rng.rand(sel.size)]
        Func.new(*ops, level + 1)
      end
    end

    def initialize(level)
      if level == 50
        fail BadExpr
      end
    end

    def to_s
      fail "Impossible"
    end
  end # class Node

  class Func < Node
    PROB_RANGE = 15
    INIT_TERN = 2
    INIT_FUNC = 12

    LEAF_RANGE = 10
    LEAF_NUM = 3

    MAX_ARITY = 4

    attr_reader :fn
    attr_reader :optype
    attr_accessor :operands

    def initialize(fn, arity, optype, level, operands = nil)
      super(level)
      @fn = fn
      if operands.nil?
        @operands = []
        arity ||= $rng.rand(2..MAX_ARITY)
        arity.times do
          # Randomize node only if it is a simple function.
          # Otherwise there could be a problem with logical nodes.
          if optype == :simple_fn
            num = $rng.rand(PROB_RANGE + level)
            if num < INIT_TERN && $generate_ternary
              optype = :tern
            elsif num >= INIT_FUNC
              num = $rng.rand(LEAF_RANGE)
              optype = num < LEAF_NUM ? :num : :point
            end
          end
          @operands << generate_operand(optype, level)
        end
      else
        @operands = operands
      end
    end

    def get_inv(op, neg = false, value = nil)
      if value
        val = value
      else
        val = neg ? "-1.0" : "1.0"
      end
      Func.new("/", 2, nil, 0, [Leaf.new(val), op])
    end

    def get_sqr(op)
      Func.new("*", 2, nil, 0, [op, op])
    end

    def get_prd(op1, op2)
      Func.new("*", 2, nil, 0, [op1, op2])
    end

    def get_x_m_one(op, inv = false)
      ops = [op, Leaf.new("1.0")]
      ops = ops.reverse if inv
      Func.new("-", 2, nil, 0, ops)
    end

    def get_x_p_one(op, inv = false)
      Func.new("+", 2, nil, 0, [op, Leaf.new("1.0")])
    end

    def get_sqrt(op)
      Func.new("sqrt", 1, nil, 0, [op])
    end

    def diff
      func = @fn
      case func
      when "+", "-"
        new_ops = @operands.map{ |o| o.diff }
        res = Func.new(func, new_ops.size, nil, 0, new_ops)
      when "*"
        new_ops = Array.new
        @operands.each_with_index do |o, i|
          ops = @operands[0...i] + @operands[(i + 1)..-1]
          mult = Func.new("*", @operands.size, nil, 0, [o.diff] + ops)
          new_ops << mult
        end
        res = Func.new("+", new_ops.size, nil, 0, new_ops)
      when "/"
        # Like * but should invert all but first operands.
        if @operands.size != 2
          invops = Array.new
          invops = @operands[1..-1].map do |op|
            get_inv(op)
          end
          invops << @operands[0]
          inverted = Func.new("*", @operands.size, nil, 0, invops)
          res = inverted.diff
        else
          op1 = @operands[0]
          op2 = @operands[1]
          sqr = get_sqr(op2)
          op1d = op1.diff
          op2d = op2.diff
          lhs = get_prd(op1d, op2)
          rhs = get_prd(op1, op2d)
          diff = Func.new("-", 2, nil, 0, [lhs, rhs])
          res = Func.new("/", 2, nil, 0, [diff, sqr])
        end
      when "sin"
        op = @operands.first
        drv = Func.new("cos", 1, nil, 0, [op])
        res = get_prd(drv, op.diff)
      when "cos"
        op = @operands.first
        dcos = Func.new("sin", 1, nil, 0, [op])
        drv = Func.new("*", 2, nil, 0, [dcos, Leaf.new("-1.0")])
        res = get_prd(drv, op.diff)
      when "tan"
        op = @operands.first
        cos = Func.new("cos", 1, nil, 0, [op])
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
        drv = Func.new("cosh", 1, nil, 0, [op])
        res = get_prd(drv, op.diff)
      when "cosh"
        op = @operands.first
        drv = Func.new("sinh", 1, nil, 0, [op])
        res = get_prd(drv, op.diff)
      when "tanh"
        op = @operands.first
        cosh = Func.new("cosh", 1, nil, 0, [op])
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
        drv = Func.new("exp", 1, nil, 0, [op])
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
        log = Func.new("log", 1, nil, 0, [base])
        to_exp_ops = get_prd(log, pow)
        to_exp = Func.new("exp", 1, nil, 0, [to_exp_ops])
        res = to_exp.diff
      else
        fail "Unknown functions"
      end
      res
    end

    def to_s
      ops = @operands.map{ |o| o.to_s }
      infix = /^[a-z]/.match(@fn).nil?
      if infix
        if ExprTree.cmp_fn.map{ |c| c.first }.include?(@fn)
          ops = ops.map{ |o| "std::abs(#{o})" }
        end
        res = "(" + ops.join(" #{@fn} ") + ")"
      else
        res = @fn + "(" + ops.join(", ") + ")"
      end
      res
    end
  end # class Func

  class Ternary < Node
    def initialize(level)
      super(level)
      cond = generate_operand(:log_fn, level + 1)
      op1 = generate_operand(:simple_fn, level + 1)
      op2 = generate_operand(:simple_fn, level + 1)
      @operands = [cond, op1, op2]
    end

    def to_s
      ops = @operands.map{ |o| o.to_s }
      "((" + ops[0] + ") ? (" + ops[1] + ") : (" + ops[2] + "))"
    end
  end # class Ternary

  class Leaf < Node
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

    def diff
      case @fn
      when Point
        r = Leaf.new('1.0')
      else
        r = Leaf.new('0.0')
      end
      r
    end

    def to_s
      @fn
    end
  end # class Leaf

  def self.simple_fn
    if ExprTree.instance_variable_defined?(:@fns)
      ExprTree.instance_variable_get(:@fns)
    else
      ExprTree.instance_variable_set(:@fns, [["+", nil, :simple_fn],
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
                                             ["pow", 2, :simple_fn]])
    end
  end

  def self.cmp_fn
    if ExprTree.instance_variable_defined?(:@cmps)
      ExprTree.instance_variable_get(:@cmps)
    else
      ExprTree.instance_variable_set(:@cmps, [["<", 2, :simple_fn],
                                              [">", 2, :simple_fn],
                                              ["<=", 2, :simple_fn],
                                              [">=", 2, :simple_fn],
                                              ["==", 2, :simple_fn],
                                              ["!=", 2, :simple_fn]])
    end
  end

  def self.log_fn
    if ExprTree.instance_variable_defined?(:@logs)
      ExprTree.instance_variable_get(:@logs)
    else
      ExprTree.instance_variable_set(:@logs, [["&&", nil, :cmp_fn],
                                              ["||", nil, :cmp_fn]])
    end
  end

  class Expr
    def initialize(node = nil)
      if node
        @fn = node
      else
        if $generate_ternary
          @fn = Ternary.new(1)
        else
          sfn = ExprTree.simple_fn
          sz = sfn.size
          sz = sz < 4 ? sz : 4
          ops = sfn[$rng.rand(sz)]
          @fn = Func.new(*ops, 1)
        end
      end
    end

    def to_s
      if @expr.nil?
        @expr = @fn.to_s
      else
        @expr
      end
    end

    def diff
      Expr.new(@fn.diff)
    end
  end # class Expr

end # module ExprTree
