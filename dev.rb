require 'matrix'

def factorial(num)
  if num <= 0
    1
  else
    (1..num).to_a.inject(1){|product,n| product * n}
  end
end

#TODO: there's a faster way to do this... doesn't explicitly use factorial
def combinations(n,k)
  factorial(n).to_f / (factorial(k) * factorial(n - k))
end

def binom (n,k,prob)
  combinations(n,k) * (prob**k) * ((1 - prob)**(n - k))
end

def max(n,m)
  n > m ? n : m
end

def min(n,m)
  n < m ? n : m
end

class TrueClass
  def to_i
    1
  end
end

class FalseClass
  def to_i
    0
  end
end

class Array
  def rshift(n)
    i = 0
    self.collect{|blah|
      if i < n
        t = 0
      else
        t = self[i-n]
      end
      i += 1
      t
    }
  end
  def mult(n)
    self.collect{|val| n * val}
  end
end


class Army
  attr_reader :size
  
  def initialize(arr)
    @arr = arr
    @size = @arr.inject(0){|sum, num| sum + num}
  end
  
  def loseone
    removed = false
    narr = @arr.collect{|n|
      if (n > 0) and (! removed)
        removed = true
        n - 1
      else
        n
      end
    }
    Army.new(narr)
  end
  
  def probs
    p = Array.new(@size + 1, 0.0)
    p[0] = 1.0
    @arr.each_with_index{|num,power|
      pos = Array.new(num + 1,nil)
      for hits in (0..num)
        pos[hits] = p.rshift(hits).mult(binom(num,hits, (power+1)/6.0))
      end
      p.size.times{|x|
        p[x] = 0
        pos.size.times{|y|
          p[x] += pos[y][x]
        }
      }
    }
    p
  end
end


class Battle
  attr_reader :aprobs, :dprobs, :mat, :transmat, :state
  def numcon(i)
    [@a.size - (i / @a.size), @d.size - (i % (@d.size + 1))]
  end

  def initialize(a,d)
    @a = a
    @d = d
    aprobs = Array.new(a.size + 1,nil)
    for i in (0..@a.size)
      aprobs[i] = a.probs + Array.new(@a.size - a.size, 0.0)
      a = a.loseone
    end
    aprobs.reverse!
        
    dprobs = Array.new(d.size + 1,nil)
    for i in (0..@d.size)
      dprobs[i] = d.probs + Array.new(@d.size - d.size, 0.0)
      d = d.loseone
    end
    dprobs.reverse!

    mat = Array.new((@a.size + 1) * (@d.size + 1)){Array.new((@a.size + 1) * (@d.size + 1), 0)}
    for col in (0..(mat.size - 1))
      for row in (col..(mat.size - 1)) #only need consider lower triangle
        ra, rd = numcon(col)
        ca, cd = numcon(row)
        if (ca == 0) #consider all cases where defence gets >= ra hits
          pd = dprobs[rd][ra..@d.size].inject(0){|s,v| s + v}
        else
          pd = dprobs[rd][ra-ca]
        end
        if (cd == 0) #consider all cases where defence gets >= rd hits
          pa = aprobs[ra][rd..@a.size].inject(0){|s,v| s + v}
        else
          pa = aprobs[ra][rd-cd]
        end
        mat[row][col] = pd * pa if ((rd - cd) >= 0) and ((ra - ca) >= 0)
      end
    end
    @transmat = Matrix.rows(mat)
    state = Array.new(mat.size, 0.0)
    oldstate = Matrix.column_vector(state.dup)
    state[0] = 1.0
    @state = Matrix.column_vector(state)
 count = 0
    while (((oldstate.transpose * @state)[0,0] / (@state.transpose * @state)[0,0])< 0.99999999)
 puts count
      oldstate = @state
      @state = @transmat * @state
      
 count += 1
    end
  end
end