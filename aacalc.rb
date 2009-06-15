#!/usr/bin/ruby

# aacalc -- An odds calculator for Axis and Allies
#Copyright (C) 2008  Leon N. Maurer

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


require 'tkextlib/tile'
require 'yaml'

#if it's available, the GNU Scientific Library can be used for matrix/vector
#multiplication, which speeds the process up greatly
$use_gsl = true
begin
  require 'gsl'
rescue Exception
  require 'matrix'
  $use_gsl = false
end

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

alias oldprint print
#TODO: give this all the functionality of the old print
def print(s)
  if __FILE__ == $0
    $gui.print_to_console(s)
  else
    oldprint(s)
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
    (1..num).to_a.inject(1){|product,n| product * n}
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

#this is needed to accont for rounding error when adding probabilities
$error = 0.001

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
    super(1,2,3,"land",a)
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
    super(3,3,5,"land",a)
  end
  def dup
    Tank.new(@attacking)
  end
end

class Artillery < Unit
  def initialize(a)
    super(2,2,4,"land",a)
  end
  def dup
    Artillery.new(@attacking)
  end
end

class Fighter < Unit
  def initialize(a,jet=false)
    if jet
      super(3,5,10,"air",a)
    else
      super(3,4,10,"air",a)
    end
  end
  def dup
    Fighter.new(@attacking,@defend == 5)
  end
end

class Bomber < Unit
  attr_reader :heavy
  def initialize(a,heavy=false)
    @heavy = heavy and a
    super(4,1,15,"air",a)
  end
  def dup
    Bomber.new(@attacking,@heavy)
  end
end

class Destroyer < Unit
  def initialize(a)
    super(3,3,12,"sea",a)
  end
  def dup
    Destroyer.new(@attacking)
  end
end

class Battleship < Unit
  def initialize(a)
    super(4,4,24,"sea",a)
  end
  def dup
    Battleship.new(@attacking)
  end
end

class Bship1stHit < Unit
  def initialize(a)
    super(0,0,0,"sea",a)
  end
  def dup
    Bship1stHit.new(@attacking)
  end
end

class Carrier < Unit
  def initialize(a)
    super(1,3,16,"sea",a)
  end
  def dup
    Carrier.new(@attacking)
  end
end

class Transport < Unit
  def initialize(a)
    super(0,1,8,"sea",a)
  end
  def dup
    Transport.new(@attacking)
  end
end

class Sub < Unit
  def initialize(a,sup = false)
    if sup
      super(3,2,8,"sea",a)
    else
      super(2,2,8,"sea",a)
    end
  end
  def dup
    Sub.new(@attacking)
  end
end

class Army
  attr_reader :size, :hits, :arr
  
  def initialize(arr)
    @arr = arr #contains the units in reverse loss order
    @size = @arr.size
    @hits = @arr.inject(0){|sum, unit| sum + ((unit.is_a?(Bomber) and unit.heavy) ? 2 : 1)}
    #infantry pairing
    inf = @arr.find_all{|unit| unit.is_a?(Infantry)}
    numart = @arr.inject(0){|sum,unit| sum + (unit.is_a?(Artillery) ? 1 : 0)}
    inf.each_with_index{|inf,i| inf.two_power if i < numart}
  end
  def dup
    Army.new(@arr.collect{|unit| unit.dup})
  end
  def lose_one
    narr = @arr.collect{|unit| unit.dup}
    narr.pop
    Army.new(narr)
  end
  def lose_one_aircraft
    lost_one = false
    narr = @arr.reverse.collect{|unit| unit.dup}
    narr = narr.reject{|unit| unit.type == 'air' && ! lost_one ? lost_one = true : false}
    Army.new(narr.reverse)
  end
  def probs
    p = Array.new(@hits + 1, 0)
    p[0] = 1
    powers = Array.new(7,0)
    @arr.each{|unit|
      if unit.is_a?(Bomber) and unit.heavy
        powers[unit.power] += 2
      else
        powers[unit.power] += 1
      end
    }
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
  def has_aircraft
    @arr.any?{|unit| unit.type == 'air'}
  end
  def num_aircraft
    @arr.inject(0){|s,u|s + (u.type == 'air').to_i}
  end
end


class Battle
  attr_reader :aprobs, :dprobs, :mat, :transmat, :state, :t, :a, :d, :bombarders
  def numcon(i)
    [@a.size - (i / (@d.size + 1)), @d.size - (i % (@d.size + 1))]
  end

  def ntest
    ((@a.size + 1)*(@d.size + 1)).times{|x| print numcon(x)[0]," ",numcon(x)[1],"\n"}
  end

  def initialize(a,d,bombarders,weight=1.0)
    @a = a
    @d = d
    @bombarders = bombarders
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

        #since a can get heavy bombers, we need to us ahits[] and not rely on size        
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
          else #in case there are more bomarders than defendign units
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
  def nwins
    @state[-1] * @weight
  end
  def tprob
    (awins + dwins + nwins) * @weight
  end
end

class BattleGUI
  def initialize
    @root = TkRoot.new(:title=>'Battle Calculator')
    tframe = TkLabelFrame.new(@root,:text=>'Technology').grid(:column=>0,:row=>0,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    aframe = TkLabelFrame.new(@root,:text=>'Attackers').grid(:column=>0,:row=>1,:padx=>5,:pady=>5)
    dframe = TkLabelFrame.new(@root,:text=>'Defenders').grid(:column=>1,:row=>1,:padx=>5,:pady=>5)
    cframe = TkLabelFrame.new(@root,:text=>'Controls').grid(:column=>0,:row=>2,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    consoleframe = TkLabelFrame.new(@root,:text=>'Console').grid(:column=>0,:row=>3,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    
    #console
    cyscroll = proc{|*args| @cscrollb.set(*args)}
    cscroll = proc{|*args| @console.yview(*args)}
    @console = TkText.new(consoleframe,:yscrollcommand=>cyscroll,:width=>80,:height=>10).grid(:column=>0,:row=>0,:padx=>5,:pady=>5)
    @cscrollb = TkScrollbar.new(consoleframe,:orient=>'vertical',:command=>cscroll).grid(:column=>1,:row=>0,:padx=>5,:sticky=>'ns')

    #attackers
    aclear = proc {
      @aunitsnums.each{|sbox| sbox.set("0")}
      @aupdate.call
    }
    @aunits = Array.new
    @aupdate = proc{
      if @alist.curselection.size != 0
        @alist.selection_clear(@alist.curselection[0])
      end
      self.disable_buttons(@aup,@adown)
      @aunits = Array.new
      @aunitsnums[0].get.to_i.times {@aunits.push(Infantry.new(true))}
      @aunitsnums[1].get.to_i.times {@aunits.push(Tank.new(true))}
      @aunitsnums[2].get.to_i.times {@aunits.push(Artillery.new(true))}

      @ahas_land = @aunits.any?{|unit| unit.type == 'land'}
      if @ahas_land or @dhas_land
        self.disable_sea
      else
        self.enable_sea
      end

      @aunitsnums[3].get.to_i.times {@aunits.push(Fighter.new(true,@jets.get_value == '1'))}
      @aunitsnums[4].get.to_i.times {@aunits.push(Bomber.new(true,@heavyBombers.get_value == '1'))}
      @aunitsnums[5].get.to_i.times {@aunits.push(Destroyer.new(true))}
      @aunitsnums[6].get.to_i.times {@aunits.push(Battleship.new(true))}
      @aunitsnums[6].get.to_i.times {@aunits.push(Bship1stHit.new(true))} unless @ahas_land or @dhas_land
      @aunitsnums[7].get.to_i.times {@aunits.push(Carrier.new(true))}
      @aunitsnums[8].get.to_i.times {@aunits.push(Transport.new(true))}
      @aunitsnums[9].get.to_i.times {@aunits.push(Sub.new(true,@superSubs.get_value == '1'))}
      
#      @aunits = @aunits.reject{|unit| unit.is_a?(Bship1stHit)} if ahas_land #if there are land units, take out the first hit
      @ahas_sea = @aunits.any?{|unit| (unit.type == 'sea') and (not(unit.is_a?(Battleship) or unit.is_a?(Bship1stHit) or (unit.is_a?(Destroyer) and (@combinedBombardment.get_value == '1'))))}
      if @ahas_sea or @dhas_sea
        self.disable_land
      else
        self.enable_land
      end

      if @asort.to_s == 'value'
        @aunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @asort.value ='power' #in case it's set to 'other'
        @aunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end

      self.update_lists
    }
    row = -1
    @aunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(aframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
       sb = TkSpinbox.new(aframe,'to'=>100, 'from'=>0, 'width'=>3, 'command'=>@aupdate)
       sb.grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
       sb.bind('KeyRelease',@aupdate)
    }
    TkLabel.new(aframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @asort = TkVariable.new
    @asort.set_value('power')
    TkRadioButton.new(aframe,'text'=>'Power','variable'=>@asort,'value'=>'power','command'=>@aupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Value','variable'=>@asort,'value'=>'value','command'=>@aupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Other','variable'=>@asort,'value'=>'other','command'=>proc{self.enable_buttons(@aup,@adown)}).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    ayscroll = proc{|*args| @albscroll.set(*args)}
    ascroll = proc{|*args| @alist.yview(*args)}
    @anames = TkVariable.new
    @alist = TkListbox.new(aframe,'listvariable'=>@anames,'height' => 12,'yscrollcommand'=> ayscroll,:font=>'TkFixedFont').grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @alist.bind('<ListboxSelect>'){@asort.set_value('other');self.enable_buttons(@aup,@adown)}
    @albscroll = TkScrollbar.new(aframe,'orient'=>'vertical','command'=>ascroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @aup = TkButton.new(aframe,'text'=>'Up','command'=>proc {self.move_unit(@aunits,@alist,:up)}).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @adown = TkButton.new(aframe,'text'=>'Down','command'=>proc {self.move_unit(@aunits,@alist,:down)}).grid('column'=>3, 'row'=>9, 'padx'=>5)
    self.disable_buttons(@aup,@adown)
    TkButton.new(aframe,'text'=>'Clear','command'=>aclear).grid('column'=>2, 'row'=>10, 'padx'=>5)

    #defenders
    dclear = proc {
      @dunitsnums.each{|sbox| sbox.set("0")}
      @dupdate.call
    }
    @dunits = Array.new
    @dupdate = proc{
      if @dlist.curselection.size != 0
        @dlist.selection_clear(@dlist.curselection[0])
      end
      self.disable_buttons(@dup,@ddown)
      @dunits = Array.new
      @dunitsnums[0].get.to_i.times {@dunits.push(Infantry.new(false))}
      @dunitsnums[1].get.to_i.times {@dunits.push(Tank.new(false))}
      @dunitsnums[2].get.to_i.times {@dunits.push(Artillery.new(false))}
      @dunitsnums[3].get.to_i.times {@dunits.push(Fighter.new(false,@jets.get_value == '1'))}
      @dunitsnums[4].get.to_i.times {@dunits.push(Bomber.new(false,@heavyBombers.get_value == '1'))}
      @dunitsnums[5].get.to_i.times {@dunits.push(Destroyer.new(false))}
      @dunitsnums[6].get.to_i.times {@dunits.push(Battleship.new(false))}
      @dunitsnums[6].get.to_i.times {@dunits.push(Bship1stHit.new(false))}
      @dunitsnums[7].get.to_i.times {@dunits.push(Carrier.new(false))}
      @dunitsnums[8].get.to_i.times {@dunits.push(Transport.new(false))}
      @dunitsnums[9].get.to_i.times {@dunits.push(Sub.new(false,@superSubs.get_value == '1'))}
      
      if @dsort.to_s == 'value'
        @dunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @dsort.value = 'power' #in case it's set to 'other'
        @dunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end

      @dhas_land = @dunits.any?{|unit| unit.type == 'land'}
      @dhas_sea = @dunits.any?{|unit| unit.type == 'sea'}
      if @dhas_land or @ahas_land
        self.disable_sea
      else
        self.enable_sea
      end
      if @dhas_sea or @ahas_sea
        self.disable_land
      else
        self.enable_land
      end

      self.update_lists
    }
    row = -1
    @dunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(dframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      sb = TkSpinbox.new(dframe,'to'=>100, 'from'=>0, 'width'=>3,'command'=>@dupdate)
      sb.grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      sb.bind('KeyRelease',@dupdate)
    }
    TkLabel.new(dframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @dsort = TkVariable.new
    @dsort.set_value('power')
    TkRadioButton.new(dframe,'text'=>'Power','variable'=>@dsort,'value'=>'power','command'=>@dupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Value','variable'=>@dsort,'value'=>'value','command'=>@dupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Other','variable'=>@dsort,'value'=>'other','command'=>proc{self.enable_buttons(@dup,@ddown)}).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    dyscroll = proc{|*args| @dlbscroll.set(*args)}
    dscroll = proc{|*args| @dlist.yview(*args)}
    @dnames = TkVariable.new('')
    @dlist = TkListbox.new(dframe,'listvariable'=>@dnames,'height' => 12,'yscrollcommand'=> dyscroll,:font=>'TkFixedFont').grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @dlist.bind('<ListboxSelect>'){@dsort.set_value('other');self.enable_buttons(@dup,@ddown)}
    @dlbscroll = TkScrollbar.new(dframe,'orient'=>'vertical','command'=>dscroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @dup = TkButton.new(dframe,'text'=>'Up','command'=>proc {self.move_unit(@dunits,@dlist,:up)}).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @ddown = TkButton.new(dframe,'text'=>'Down','command'=>proc {self.move_unit(@dunits,@dlist,:down)}).grid('column'=>3, 'row'=>9, 'padx'=>5)
    self.disable_buttons(@dup,@ddown)
    TkButton.new(dframe,'text'=>'Clear','command'=>dclear).grid('column'=>2, 'row'=>10, 'padx'=>5)
   
    #controls
    about = proc {Tk.messageBox('type' => 'ok',
      'icon' => 'info',
      'title' => 'About',
      'message' => "Aacalc revision 73\n" + 
      "Copyright (C) 2008 Leon N. Maurer\n" +
      'https://launchpad.net/aacalc' + "\n" +
      "Source code available under the \n" +
      "GNU Public License. See the\n" +
      "Readme for information about the\n" +
      "controls."
    )}
    savebattle = proc{
#NOTE: Ruby hashes have no predetermined order, so the results will get printed
#to the file in a mixed up fashion. This will be fixed in Ruby 1.9 -- for now
#we'll just have to live with it
      if defined?(@battles)
        battle_details = Hash.new
        battle_details['Summary of odds'] = {'Attacker wins'=>@pawins,
          'Defender wins'=>@pdwins,'Mutual annihilation'=>@pnwins}
        battle_details['Technologies'] = {'AAguns'=> @aaGun.get_value == '1',
         'Heavy Bombers'=> @heavyBombers.get_value == '1', 'Combined Bombardment'=>
         @combinedBombardment.get_value == '1','Jets' => @jets.get_value == '1',
         'Super Subs' => @superSubs.get_value == '1'}
        battle_details['Bomardment'] = (@bombarders != nil)
        battle_details['Bombarders'] = @bombarders.arr.collect{|u| u.class.to_s} if @bombarders != nil
        battle_details['Attacking units and odds'] = @a.arr.collect{|u| u.class.to_s}.zip(@acumprobs)
        battle_details['Defending units and odds'] = @d.arr.collect{|u| u.class.to_s}.zip(@dcumprobs)
        filename = Tk.getSaveFile("filetypes"=>[["Text", ".txt"]])
        File.open(filename, "w"){|file| file.print(battle_details.to_yaml)} unless filename == ""
      end
    }
    calc = proc{
#TODO: aa guns and bombard
      start = Time.now.to_f 
      self.reset_console
    
      has_land = (@aunits + @dunits).any?{|u| u.type == 'land'}
      has_sea = (@aunits + @dunits).any?{|u| u.type == 'sea'}

      @bombarders = nil
      if has_land and has_sea #then there's a bombardment coming
        @bombarders = Army.new(@aunits.select{|u| u.type == 'sea'})
        @oldaunits = @aunits #don't want to permantly remove ships -- just need to seperate them for computations
        @aunits = @aunits.reject{|u| u.type == 'sea'}
      end

      @a = Army.new(@aunits.reverse)
      @d = Army.new(@dunits.reverse)

      @battles = Array.new
      a = @a.dup
      numaircraft = @aaGun.get_value == '1' ? a.num_aircraft : 0
      aircraftindexes = Array.new
      a.arr.each_with_index{|u,i| aircraftindexes << i if u.type == 'air'}
      for hits in 0..numaircraft #exceutes even if numaircraft == 0
        @battles << Battle.new(a,@d,@bombarders, binom(numaircraft,hits,1.0/6.0))
        a = a.lose_one_aircraft
      end

      @pawins = @battles.inject(0){|s,b|s + b.awins}
      @pdwins = @battles.inject(0){|s,b|s + b.dwins}
      @pnwins = @battles.inject(0){|s,b|s + b.nwins}
      @pswins = @pawins + @pdwins + @pnwins
      #d doesn't lose any units from aaguns, so we can just add everything together
      @dcumprobs = @battles.collect{|b|b.dcumprobs}.inject{|s,a| s.zip(a).collect{|b,c|b+c}}
      #the same is not true for a, so this takes more work
      acumprobs = Array.new
      @battles.each_with_index{|b,i|
        probs = b.acumprobs.reverse
        for j in 0..(i-1)
          probs.insert(aircraftindexes[j],0)
        end
        acumprobs << probs.reverse
      }
      @acumprobs = acumprobs.inject{|s,a| s.zip(a).collect{|b,c|b+c}}

      @attackerProb.value = @pawins.to_s
      @defenderProb.value = @pdwins.to_s
      @annihilationProb.value = @pnwins.to_s
      @sumProb.value = @pswins.to_s
      @aunits = @oldaunits if has_land and has_sea
      @anames.value = @anames.list.collect{|s|s.split[0]}.zip(@acumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}
      @dnames.value = @dnames.list.collect{|s|s.split[0]}.zip(@dcumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}

      print "Operation completed in #{Time.now.to_f - start} seconds\n"
    }
   
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

    @calculate = TkButton.new(cframe,'text'=>'Calculate','command'=>calc).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkButton.new(cframe,:text=>'About This Program',:command=>about).grid('column'=>3, 'row'=>3, 'padx'=>5, 'pady'=>5)
    TkButton.new(cframe,:text=>'Save Last Battle',:command=>savebattle).grid('column'=>3, 'row'=>2, 'padx'=>5, 'pady'=>5)

    #techs
    @aaGun = TkCheckButton.new(tframe,:text=>"AA gun").grid(:column=>0,:row=>0,:padx=>5,:pady=>5)
    @heavyBombers = TkCheckButton.new(tframe,:text=>"Hv. Bombers",:command=>@aupdate).grid(:column=>1,:row=>0,:padx=>5,:pady=>5)
    @combinedBombardment = TkCheckButton.new(tframe,:text=>"Comb. Bom.",:command=>@aupdate).grid(:column=>2,:row=>0,:padx=>5,:pady=>5)
    @jets = TkCheckButton.new(tframe,:text=>"Jets",:command=>@dupdate).grid(:column=>3,:row=>0,:padx=>5,:pady=>5)
    @superSubs = TkCheckButton.new(tframe,:text=>"Super Subs",:command=>@aupdate).grid(:column=>4,:row=>0,:padx=>5,:pady=>5)
  end
  def disable_land
    self.disable_buttons(@aunitsnums[0..2],@dunitsnums[0..2])
  end
  def disable_sea
    if @combinedBombardment.get_value == '1'
      @aunitsnums[5].state('normal')
    else
      @aunits = @aunits.reject{|u| u.is_a?(Destroyer)}
      @aunitsnums[5].state('disabled')
      @aunitsnums[5].set(0)
    end
#      @aunitsnums[7..9].each{|sbox| sbox.state('disabled');sbox.set(0)}
    self.disable_buttons(@aunitsnums[7..9],@dunitsnums[5..9])
  end
  def enable_land
    self.enable_buttons(@aunitsnums[0..2],@dunitsnums[0..2])
  end
  def enable_sea
    self.enable_buttons(@aunitsnums[5..9],@dunitsnums[5..9])
  end
  def enable_buttons(*buttons)
    buttons.flatten.each{|b| b.state('active') if b.is_a?(TkButton)
    b.state('normal') if b.is_a?(TkSpinbox)}
  end
  def disable_buttons(*buttons)
    buttons.flatten.each{|b|b.state('disabled')}
  end
  def move_unit(units,list,direction)
    index = list.curselection[0]
    if direction == :down
      i = 1
      clear = (index != nil) && (units.size > 1) && (index < (units.size - 1)) &&
        !(units[index+1].is_a?(Battleship) and units[index].is_a?(Bship1stHit))
    else #:up
      i = -1
      clear = (index != nil) && (index > 0) &&
        !(units[index].is_a?(Battleship) and units[index-1].is_a?(Bship1stHit))
    end
    if clear
      temp = units[index+i]
      units[index+i] = units[index]
      units[index] = temp
      list.see(index + i)
      list.selection_clear(index)
      list.selection_set(index + i)
      self.update_lists
    end     
  end
  def update_lists
    @dnames.set_list(@dunits.collect{|unit|unit.class}) if defined?(@dunits)
    @anames.set_list(@aunits.collect{|unit|unit.class}) if defined?(@aunits)
  end
  def print_to_console(s)
    @console.insert('end',s)
    @console.see('end')
    Tk.update
  end
  def reset_console
    @console.delete(0.0,'end')
  end
end

if __FILE__ == $0
  $gui = BattleGUI.new
  Tk.mainloop()
end