require 'matrix'
require 'rational'
require 'tkextlib/tile'

def Integer.to_r
  Rational(self,1)
end

class Vector
  def each_with_index
    @elements.each_with_index{|o,i| yield o, i}
  end
end

def factorial(num)
  if num <= 0
    1
  else
    (1..num).to_a.inject(1){|product,n| product * n}
  end
end

def combinations(n,k)
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


class Unit
  attr_reader :value, :attack, :defend
  def initialize(attack, defend, value, attacking)
    @attack = attack
    @defend = defend
    @value = value
    @attacking = attacking
  end
  def power
    @attacking ? @attack : @defend
  end
end

class Infantry < Unit
  def initialize(a)
    super(1,2,3,a)
  end
  def two_power
    @attack = 2
  end
  def dup
    Infantry.new(@attacking)
  end
end

class Tank < Unit
  def initialize(a)
    super(3,3,5,a)
  end
  def dup
    Tank.new(@attacking)
  end
end

class Artillery < Unit
  def initialize(a)
    super(2,2,4,a)
  end
  def dup
    Artillery.new(@attacking)
  end
end

class Fighter < Unit
  def initialize(a,jet=false)
    if jet
      super(3,5,10,a)
    else
      super(3,4,10,a)
    end
  end
  def dup
    Fighter.new(@attacking,@defence == 5)
  end
end

class Bomber < Unit
  attr_reader :heavy
  def initialize(a,heavy=false)
    @heavy = heavy and a
    super(4,1,15,a)
  end
  def dup
    Bomber.new(@attacking,@heavy)
  end
end

class Destroyer < Unit
  def initialize(a)
    super(3,3,12,a)
  end
  def dup
    Destroyer.new(@attacking)
  end
end

class Battleship < Unit
  def initialize(a)
    super(4,4,24,a)
  end
  def dup
    Battleship.new(@attacking)
  end
end

class Carrier < Unit
  def initialize(a)
    super(1,3,16,a)
  end
  def dup
    Carrier.new(@attacking)
  end
end

class Transport < Unit
  def initialize(a)
    super(0,1,8,a)
  end
  def dup
    Transport.new(@attacking)
  end
end

class Sub < Unit
  def initialize(a,sup = false)
    if sup
      super(3,2,8,a)
    else
      super(2,2,8,a)
    end
  end
  def dup
    Sub.new(@attacking)
  end
end

class Army
  attr_reader :size, :hits
  
  def initialize(arr)
    @arr = arr #contains the units in reverse loss order
    @size = @arr.size
    @hits = @arr.inject(0){|sum, unit| sum + ((unit.is_a?(Bomber) and unit.heavy) ? 2 : 1)}
#TODO: infantry pairing
  end
  
  def loseone
    narr = @arr.collect{|unit| unit.dup}
    narr.pop
    Army.new(narr)
  end
  
  def probs
#TODO: change over to using hits instead of size
    p = Array.new(@size + 1, 0)
    p[0] = 1
    powers = Array.new(7,0)
    @arr.each{|unit| powers[unit.power] += 1}
    powers.each_with_index{|num,power|
      pos = Array.new(num + 1,nil)
      for hits in (0..num)
        #Rational is used to avoid an annoying rounding error that can occour when calculating mag
        pos[hits] = p.rshift(hits).mult(binom(num,hits, Rational(power, 6)))
      end
      p.size.times{|x|
        p[x] = 0.to_r 
        pos.size.times{|y|
          p[x] += pos[y][x]
        }
      }
    }
    p
  end
end


class Battle
  attr_reader :aprobs, :dprobs, :mat, :transmat, :state, :t
  def numcon(i)
    [@a.size - (i / (@d.size + 1)), @d.size - (i % (@d.size + 1))]
  end

  def ntest
    ((@a.size + 1)*(@d.size + 1)).times{|x| print numcon(x)[0]," ",numcon(x)[1],"\n"}
  end

  def initialize(a,d)
    @a = a
    @d = d
    
    start = Time.now.to_f

#TODO: calculate army IPCs here as well    
    puts "calculating attacker probabilities"    
    aprobs = Array.new(a.size + 1,nil)
    for i in (0..@a.size)
      aprobs[i] = a.probs
      a = a.loseone
    end
    aprobs.reverse!
        
    puts "calculating defender probabilities"
    dprobs = Array.new(d.size + 1,nil)
    for i in (0..@d.size)
      dprobs[i] = d.probs
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

    puts "creating transition matrix (#{(@a.size + 1) * (@d.size + 1)} columns)"

    mat = Array.new((@a.size + 1) * (@d.size + 1)){Array.new((@a.size + 1) * (@d.size + 1), 0.0)}
    for col in (0..(mat.size - 1))
      print "#{col + 1} "
      ra, rd = numcon(col)
      for row in (col..(mat.size - 1)) #only need consider lower triangle
        ca, cd = numcon(row)
        
        #consider all cases where defence gets >= ra hits if they can get that many
        if (ca == 0) and (rd >= ra)
          pd = dprobs[rd][ra..-1].inject{|s,v| s + v}
        #make sure that the battle is possible -- there aren't more units
        #before than after and the defence can get enough hits
        elsif ((ra - ca) >= 0) and ((ra - ca) <= rd)
          pd = dprobs[rd][ra-ca]
        else #if neither of the above cases work, it can't happen
          pd = 0
        end
              
        if (cd == 0) and (ra >= rd)
          pa = aprobs[ra][rd..-1].inject{|s,v| s + v}
        elsif ((rd - cd) >= 0) and ((rd - cd) <= ra)
          pa = aprobs[ra][rd-cd]
        else
          pa = 0
        end
     
        if (ca == ra) and (cd == rd)
         #sometimes this is the only non-zero entry in a column
         #in that case, have mag = 1 to signal that
         mag = (((pa * pd) < 1) ? 1 / (1 - pa * pd) : 1)
        end 

        #assign value if not in a diagonal or if the diagonal is the only non-zero term
        if (col != row) or (mag == 1)
          mat[row][col] = (mag * pd * pa).to_f
        end
        #it's already zero otherwise
      end
    end
    print "\n"
    @transmat = Matrix.rows(mat)

#each rep will cause at least one unit to be lost, which requires @a.size + @d.size
#steps, hovever, not all units need be eliminated (only all the units of one side)
#so we can do one less battle (the '-1')
    reps = @a.size + @d.size - 1
    puts "solving with matrix: 1..#{reps}"

    #state contains the solution to the markov chain
    @state = Vector.elements(Array.new(mat.size){|i| i == 0 ? 1.0 : 0.0})
    1.upto(reps){|i|
      print i, " "
      @state = @transmat * @state
    }
    print "\n"

@t = Time.now.to_f - start
    puts "Operation completed in #{@t} seconds"
  end
  
  def awins
    prob = 0.0
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      prob += p if (d == 0) and (a != 0)
    }
    prob
  end
  def dwins
    prob = 0.0
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      prob += p if (a == 0) and (d != 0)
    }
    prob
  end
  def nwins
    @state[-1]
  end
  def tprob
    awins + dwins + nwins
  end
end

class BattleGUI
  def initialize
    @root = TkRoot.new() {title 'Battle Calculator'}
    tframe = TkLabelFrame.new(@root){ text 'Technology' }.grid('column'=>0,'row'=> 0,'columnspan'=>2, 'sticky'=>'nsew', 'padx'=>5, 'pady'=>5)
    aframe = TkLabelFrame.new(@root){ text 'Attackers' }.grid('column'=>0,'row'=> 1, 'padx'=>5, 'pady'=>5)
    dframe = TkLabelFrame.new(@root){ text 'Defenders' }.grid('column'=>1,'row'=> 1, 'padx'=>5, 'pady'=>5)
    cframe = TkLabelFrame.new(@root){ text 'Controls' }.grid('column'=>0,'row'=> 2,'columnspan'=>2, 'sticky'=>'nsew', 'padx'=>5, 'pady'=>5)

    #techs
    TkLabel.new(tframe, 'text'=>"AA gun").grid('column'=>0,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @aaGun = TkCheckButton.new(tframe).grid('column'=>1,'row'=> 0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Hv. Bombers").grid('column'=>2,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @heavyBombers = TkCheckButton.new(tframe).grid('column'=>3,'row'=> 0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Comb. Bom.").grid('column'=>0,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @combinedBombardment = TkCheckButton.new(tframe).grid('column'=>1,'row'=> 1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Jets").grid('column'=>2,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @jets = TkCheckButton.new(tframe).grid('column'=>3,'row'=> 1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Super Subs").grid('column'=>0,'row'=>2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @superSubs = TkCheckButton.new(tframe).grid('column'=>1,'row'=> 2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    
    #attackers
    row = -1
    @aunits = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(aframe, 'text'=>label).grid('column'=>1,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      TkSpinbox.new(aframe,'to'=>100, 'from'=>0, 'width'=>3).grid('column'=>2,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    }
    @alist = TkListbox.new(aframe,'height' => 12).grid('column'=>3, 'row'=>0,'rowspan'=>8, 'padx'=>5, 'pady'=>5)
    @aup = TkButton.new(aframe,'text'=>'Up').grid('column'=>3, 'row'=>8, 'padx'=>5, 'pady'=>5)
    @adown = TkButton.new(aframe,'text'=>'Down').grid('column'=>3, 'row'=>9, 'padx'=>5, 'pady'=>5)

    #defenders
    row = -1
    @dunits = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(dframe, 'text'=>label).grid('column'=>1,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      TkSpinbox.new(dframe,'to'=>100, 'from'=>0, 'width'=>3).grid('column'=>2,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    }
    @dlist = TkListbox.new(dframe,'height' => 12).grid('column'=>3, 'row'=>0,'rowspan'=>8, 'padx'=>5, 'pady'=>5)
    @dup = TkButton.new(dframe,'text'=>'Up').grid('column'=>3, 'row'=>8, 'padx'=>5, 'pady'=>5)
    @ddown = TkButton.new(dframe,'text'=>'Down').grid('column'=>3, 'row'=>9, 'padx'=>5, 'pady'=>5)
   
    #controls
    TkLabel.new(cframe, 'text'=>"Attacker wins").grid('column'=>0,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @attackerProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@attackerProb).grid('column'=>1,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Defender wins").grid('column'=>0,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @defenderProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@defenderProb).grid('column'=>1,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Mutual annihilation").grid('column'=>0,'row'=>2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @annihilationProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@annihilationProb).grid('column'=>1,'row'=>2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Sum").grid('column'=>0,'row'=>3, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @sumProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@sumProb).grid('column'=>1,'row'=>3, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    @calculate = TkButton.new(cframe,'text'=>'Calculate').grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)

  end

end

if __FILE__ == $0
  BattleGUI.new
  Tk.mainloop()
end