# aaodds -- An odds calculator for Axis and Allies
#Copyright (C) 2011  Leon N. Maurer

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#version 2 as published by the Free Software Foundation;

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#A copy of the license is available at 
#<http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
#You can also receive a paper copy by writing the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#if it's available, the GNU Scientific Library can be used for matrix/vector
#multiplication, which speeds the process up greatly
$use_gsl = true
begin
  require 'gsl'
rescue Exception
  require 'matrix'
  $use_gsl = false
end

#neither gsl nor the built in matrix class includes two useful functions
if $use_gsl
  class GSL::Vector
    def each_with_index
      i = 0
      self.each{|o| yield o, i; i+=1}
    end
  end
  class GSL::Matrix
    def size
      (self.size1 == self.size2 ? self.size1 : nil)
    end
  end
else
  class Vector
    def each_with_index
      @elements.each_with_index{|o,i| yield o, i}
    end
  end
  class Matrix
    def size
      (self.column_size == self.row_size ? self.row_size : nil)
    end
  end
end

def factorial(num)
  if num <= 0
    1
  else
    (1..num).inject(1){|product,n| product * n}
  end
end

def combinations(n,k)
  #works even in nC0 situations
  ((n-k+1)..n).inject(1){|p,v| p * v} / factorial(k)
end

def binom(n,k,prob)
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
  #shifts contents n places to the right
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
  #scalar multiplication
  def mult(n)
    self.collect{|val| n * val}
  end
end

#this is needed to accont for rounding error when adding probabilities
$error = 0.001

#the base class for all units
class Unit
  attr_reader :value, :attack, :defend, :type
  def initialize(attack, defend, value, type, attacking)
    @attack = attack
    @defend = defend
    @value = value
    @type = type
    @attacking = attacking
  end
  def power
    @attacking ? @attack : @defend
  end
  def ==(other)
    (self.class == other.class) and (self.attack == other.attack) and (self.defend == other.defend)
  end
end

class Infantry < Unit
  def initialize(a)
    super(1,2,3,:land,a)
  end
  def two_power
    @attack = 2
  end
  def dup #note that attack upgrades are not dupped
    Infantry.new(@attacking)
  end
end

class Tank < Unit
  def initialize(a)
    super(3,3,5,:land,a)
  end
  def dup
    Tank.new(@attacking)
  end
end

class Artillery < Unit
  def initialize(a)
    super(2,2,4,:land,a)
  end
  def dup
    Artillery.new(@attacking)
  end
end

class Fighter < Unit
  def initialize(a,jet=false)
    if jet
      super(3,5,10,:air,a)
    else
      super(3,4,10,:air,a)
    end
  end
  def dup
    Fighter.new(@attacking,@defend == 5)
  end
end

class Bomber < Unit
  attr_reader :heavy
  def initialize(a,heavy=false)
    @heavy = heavy and a #if it's not attacking, then it can't really be heavy
    super(4,1,15,:air,a)
  end
  def dup
    Bomber.new(@attacking,@heavy)
  end
end

class Destroyer < Unit
  def initialize(a)
    super(3,3,12,:sea,a)
  end
  def dup
    Destroyer.new(@attacking)
  end
end

class Battleship < Unit
  def initialize(a)
    super(4,4,24,:sea,a)
  end
  def dup
    Battleship.new(@attacking)
  end
end

#battleship that has been damaged
class Bship1stHit < Unit
  def initialize(a)
    super(0,0,0,:sea,a)
  end
  def dup
    Bship1stHit.new(@attacking)
  end
end

class Carrier < Unit
  def initialize(a)
    super(1,3,16,:sea,a)
  end
  def dup
    Carrier.new(@attacking)
  end
end

class Transport < Unit
  def initialize(a)
    super(0,1,8,:sea,a)
  end
  def dup
    Transport.new(@attacking)
  end
end

class Sub < Unit
  def initialize(a,sup = false)
    if sup
      super(3,2,8,:sea,a)
    else
      super(2,2,8,:sea,a)
    end
  end
  def dup
    Sub.new(@attacking)
  end
end

#an army is a container for a group of units which keeps track of their loss order
class Army
  attr_reader :size, :hits, :arr
  
  def initialize(arr) #arr contains the units in reverse loss order
    @arr = arr
    @size = @arr.size
    @hits = @arr.inject(0){|sum, unit| sum + ((unit.is_a?(Bomber) and unit.heavy) ? 2 : 1)}
    #infantry pairing
    inf = @arr.find_all{|unit| unit.is_a?(Infantry)}
    numart = @arr.inject(0){|sum,unit| sum + (unit.is_a?(Artillery) ? 1 : 0)}
    inf.each_with_index{|inf,i| inf.two_power if i < numart}
  end
  
  #returns a string describing the army in reverse loss order
  #e.g. "1 Tank, 1 Fighter, 2 Tank" means first lose 2 tanks, then 1 fighter, and 1 tank last
  def to_s
    c, t, s = @arr.reverse.inject([0, nil, '']) do |(count, type, string), unit|
      if (unit.class == type) or (type == nil)
	[count+1, unit.class, string]
      else
        [1, unit.class, string + count.to_s + ' ' + type.to_s + ', ']
      end
    end
    s + c.to_s + ' ' + t.to_s
  end
  
  #return a duplicate of the array with new objects in it
  def dup_arr
    @arr.collect{|unit| unit.dup}
  end
  
  #returns a duplicate of this army with new objects for units
  def dup
    Army.new(self.dup_arr)
  end
  
  #returns a new army with one unit lost; can specify the type of unit to loose (land, air, or sea)
  def lose_one(type = nil) #
    narr = self.dup_arr
    if type == nil #if no type given, just lose least valued unit
      narr.pop
    else
      lost_one = false
      narr = self.dup_arr.reverse
      narr = narr.reject{|unit| unit.type == type && ! lost_one ? lost_one = true : false}
      Army.new(narr.reverse)
    end
    Army.new(narr)
  end
  
  #returns an array containing the probability of getting hits [P(0 hits), P(1 hits),..., P(max hits)]
  def probs
    p = Array.new(@hits + 1, 0) #p[n] will contain the probability of getting n hits
    p[0] = 1
    #powers contains the number of units at each power
    powers = Array.new(7,0)
    @arr.each{|unit|
      if unit.is_a?(Bomber) and unit.heavy #heavy bombers attack twice
        powers[unit.power] += 2
      else
        powers[unit.power] += 1
      end
    }
    #TODO: remember how this works and write it up
    powers.each_with_index{|num,power|
      pos = Array.new(num + 1,nil)
      for hits in (0..num)
        pos[hits] = p.rshift(hits).mult(binom(num,hits, power/6.0))
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
  
  #returns true if the army has aircraft
  def has_aircraft
    @arr.any?{|unit| unit.type == :air}
  end
  
  #returns the number of aircraft in the army
  def num_aircraft
    @arr.inject(0){|s,u|s + (u.type == :air).to_i}
  end
end

#A battle is a fight between two units. This object calculates the battle odds.
class Battle
  attr_reader :aprobs, :dprobs, :mat, :transmat, :state, :t, :a, :d, :bombarders
  #each state the battle (which attackers and defeners are still alive) has an
  #index in arrays and matricies to follow. The following function takes that index
  #and returns the number of attackers and defenders in the corresponding fate.
  def numcon(i)
    [@a.size - (i / (@d.size + 1)), @d.size - (i % (@d.size + 1))]
  end
  #TODO: do we still need this function?
  def ntest
    ((@a.size + 1)*(@d.size + 1)).times{|x| print numcon(x)[0]," ",numcon(x)[1],"\n"}
  end

  def initialize(a,d,bombarders,weight=1.0)
    @a = a #attackers
    @d = d #defenders
    @bombarders = bombarders
    #if this battle is (for example) part of a larger battle where AA guns are used
    #then the weight will correspond the the probability that this battle happens
    @weight = weight 
    

    start = Time.now.to_f 

    bprobs = [1] #default is for no bombard hits
    if bombarders != nil
      print "calculating bombardment probabilities\n"
      bprobs = bombarders.probs
    end

#TODO: calculate army IPCs here as well    
    print "calculating attacker probabilities\n"  
    aprobs = Array.new(a.size + 1,nil) #holds probabilities
    ahits = Array.new(a.size + 1,nil) #holds maximum number of hits for an army size
    for i in (0..@a.size)
      aprobs[i] = a.probs
      ahits[i] = a.hits
      a = a.lose_one
    end
    aprobs.reverse!
    ahits.reverse!
        
    print "calculating defender probabilities\n"  
    dprobs = Array.new(d.size + 1,nil)
    #since d doesn't have heavy bombers, hits == size always
#    dhits = Array.new(d.size + 1,nil)
    for i in (0..@d.size)
      dprobs[i] = d.probs
#      dhits[i] = d.hits
      d = d.lose_one
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

    print "creating transition matrix (#{(@a.size + 1) * (@d.size + 1)} columns)\n" 

    if $use_gsl
      @transmat = GSL::Matrix.zeros((@a.size + 1) * (@d.size + 1), (@a.size + 1) * (@d.size + 1))
    else
      @transmat = Array.new((@a.size + 1) * (@d.size + 1)){Array.new((@a.size + 1) * (@d.size + 1), 0.0)}
    end

    for col in (0..(@transmat.size - 1))
      print "#{col + 1} " 
      ra, rd = numcon(col)
      for row in (col..(@transmat.size - 1)) #only need consider lower triangle
        ca, cd = numcon(row)
      
        #since d doesn't have heavy bombers, hits == size always  
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

        #since a can get heavy bombers, we need to use ahits[] and not rely on size        
        if (cd == 0) and (ahits[ra] >= rd)
          pa = aprobs[ra][rd..-1].inject{|s,v| s + v}
        elsif ((rd - cd) >= 0) and ((rd - cd) <= ahits[ra])
          pa = aprobs[ra][rd-cd]
        else
          pa = 0
        end
     
        if (ca == ra) and (cd == rd)
         #sometimes this is the only non-zero entry in a column
         #in that case, have mag = 1 to signal that
         #due to rounding errors, sometimes pa * pd < 1 when it should be == 1
         #to avoid this problem, we introduce $error which is a small number
         mag = (((pa * pd) < 1.0 - $error) ? 1.0 / (1.0 - pa * pd) : 1.0)
        end 
        #assign value if not in a diagonal or if the diagonal is the only non-zero term
        if (col != row) or (mag == 1.0)
          if $use_gsl
            @transmat[row,col] = mag * pd * pa
          else
            @transmat[row][col] = mag * pd * pa
          end
        end
        #it's already zero otherwise
      end
    end
    print "\n" 
    unless $use_gsl
      @transmat = Matrix.rows(@transmat)
    end

#each rep will cause at least one unit to be lost, which requires @a.size + @d.size
#steps, hovever, not all units need be eliminated (only all the units of one side)
#so we can do one less battle (the '-1')
    reps = @a.size + @d.size - 1
    print "solving with matrix: 1..#{reps}\n"

    #sarr contains the initial state of the state vector -- the complicated
    #setup is to do bombardments
    #NOTE:we can simplify this logic because of how things are aranged in the
    #state vectpr -- the first @a.size states are the ones where defence has
    #lost troops but attack has not
    sarr = Array.new(@transmat.size){|i|
      na, nd = numcon(i)
      hits = @d.size - nd
      if  na == @a.size #no attackers die in bombardment
        if hits < bprobs.size
          if nd != 0
            bprobs[hits].to_f
          else #in case there are more bomarders than defending units
            bprobs[hits..-1].inject(0){|s,v|s+v}.to_f
          end
        else
          0.0
        end
      else
        0.0
      end
    }
    #state contains the solution to the markov chain
    if $use_gsl
      @state = GSL::Vector.alloc(sarr).col
    else
      @state = Vector.elements(sarr)
    end
    1.upto(reps){|i|
      print "#{i} "
      @state = @transmat * @state
    }
    print "\n"

    @t = Time.now.to_f - start
  end
  
  #returns an array where the elements correspond to the probability
  #that the corresponing unit in @arr (the array of units in Army)
  def acumprobs
    probs = Array.new(@a.size, 0.0)
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      probs[a-1] += p if (d == 0) and (a != 0)
    }
    cdf = Array.new
    for i in (0..probs.size - 1)
      cdf[i] = probs[i..-1].inject{|s,p| s + p} * @weight
    end
    cdf    
  end
  
  def dcumprobs
    probs = Array.new(@d.size, 0.0)
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      probs[d-1] += p if (a == 0) and (d != 0)
    }
    cdf = Array.new
    for i in (0..probs.size - 1)
      cdf[i] = probs[i..-1].inject{|s,p| s + p} * @weight
    end
    cdf    
  end
  
  #probabity attacker wins
  def awins
    prob = 0.0
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      prob += p if (d == 0) and (a != 0)
    }
    prob * @weight
  end
  
  def dwins
    prob = 0.0
    @state.each_with_index{|p,i|
      a, d = numcon(i)
      prob += p if (a == 0) and (d != 0)
    }
    prob * @weight
  end
  
  #the probability that no one survives the battle is stored in the last place in the array
  def nwins
    @state[-1] * @weight
  end
  
  #returns total probs (should be 1.0)
  def tprob
    (awins + dwins + nwins) * @weight
  end
end
