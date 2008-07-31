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
  #factorial(n).to_f / (factorial(k) * factorial(n - k))
#works even in nC0 situations
((n-k+1)..n).inject(1){|p,v| p * v} / factorial(k)
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
    @arr = arr #contains a count of the powers of the units
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
    [@a.size - (i / (@d.size + 1)), @d.size - (i % (@d.size + 1))]
  end

  def ntest
    ((@a.size + 1)*(@d.size + 1)).times{|x| print numcon(x)[0]," ",numcon(x)[1],"\n"}
  end

  def initialize(a,d)
    @a = a
    @d = d
puts "calculating probabilities"    
    @aprobs = Array.new(a.size + 1,nil)
    for i in (0..@a.size)
      #the second array is to keep everything the same length
      aprobs[i] = a.probs + Array.new(max(@a.size,@d.size) - a.size, 0.0)
      a = a.loseone
    end
    aprobs.reverse!
        
    @dprobs = Array.new(d.size + 1,nil)
    for i in (0..@d.size)
      dprobs[i] = d.probs + Array.new(max(@a.size,@d.size) - d.size, 0.0)
      d = d.loseone
    end
    dprobs.reverse!

#THEORY OF OPERATION FOR REST OF FUNCTION:
#We now constuct a matrix for this markov chain, however we employ one trick
#for faster computation. In every state, there is a chance that nothing will
#change after one roll (e.g. everyone misses), so this will result in a
#non-zero entry in the diagonal elements of the matrix. However, unless all
#of one side has been eliminated, that state can not be stable, and we can
#eliminate it by setting it to zero and increasing the other values in the
#column to compensate. That way, instead of taking an infinite number of rolls
#to converge, it will coverge in finite time -- less than the number of states.

puts "creating transition matrix"

    mat = Array.new((@a.size + 1) * (@d.size + 1)){Array.new((@a.size + 1) * (@d.size + 1), 0)}
#mat2 = Array.new((@a.size + 1) * (@d.size + 1)){Array.new((@a.size + 1) * (@d.size + 1), 0)}
    for col in (0..(mat.size - 1))
      ra, rd = numcon(col)
      for row in (col..(mat.size - 1)) #only need consider lower triangle
        ca, cd = numcon(row)
        
        if (ca == 0) #consider all cases where defence gets >= ra hits
          #[ra..@d.size] returns the same thing as [ra..(d.size-1)]
          pd = @dprobs[rd][ra..@d.size].inject(0){|s,v| s + v}
        elsif (ra - ca) >= 0 #can't have more people after than before
          pd = @dprobs[rd][ra-ca]
        else
          pd = 0.0
        end
        
        if (cd == 0) #consider all cases where defence gets >= rd hits
          pa = @aprobs[ra][rd..@a.size].inject(0){|s,v| s + v}
        elsif (rd - cd) >= 0 #can't have more people after than before
          pa = @aprobs[ra][rd-cd]
        else
          pa = 0.0
        end
        
        if (ca == ra) and (cd == rd)
         #sometimes this is the only non-zero entry in a column
         #in that case, have mag = 1.0 to signal that
         mag = (((pa * pd) < 1.0) ? 1.0 / (1.0 - pa * pd) : 1.0)
if mag > 2
print pa," ", pa == 1.0," ", pd," ",pd == 1.0," ", pa*pd," ",pa*pd < 1.0,"\n"
end
        end
#mat2[row][col] = pa * pd        

#print col," ",row," ", ra," ", rd," ", ca," ", cd,"\n"
#print mag," ",pd," ",pa,"\n"        

        #assign value if not in a diagonal or if the diagonal is the only non-zero term
        if (col != row) or (mag == 1.0)
          mat[row][col] = mag * pd * pa
        end
        #it's already zero otherwise
      end
    end
    @transmat = Matrix.rows(mat)
#@transmat = Matrix.rows(mat2)
    #state contains the solution to the markov chain
#    @state = Array.new(mat.size, 0.0)
#    @state[0] = 1.0
#    state = Matrix.column_vector(@state)

puts "solving matrix"

@state = Vector.elements(Array.new(mat.size){|i| i == 0 ? 1.0 : 0.0})
    for i in 0..mat.size
#      state = @transmat * state
@state = @transmat * @state
    end
@state = @state.to_a
#    @state = state.to_a.flatten
  end
  
  def awins
    p = 0.0
    @state.each_index{|i|
      a, d = numcon(i)
      p += @state[i] if (d == 0) and (a != 0)
    }
    p
  end
  def dwins
    p = 0.0
    @state.each_index{|i|
      a, d = numcon(i)
      p += @state[i] if (a == 0) and (d != 0)
    }
    p
  end
  def nwins
    @state[@state.size - 1]
  end
end