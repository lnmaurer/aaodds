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
  def ==(other)
    (self.class == other.class) and (self.attack == other.attack) and (self.defend == other.defend)
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
    TkLabel.new(tframe, 'text'=>"Comb. Bom.").grid('column'=>4,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @combinedBombardment = TkCheckButton.new(tframe).grid('column'=>5,'row'=> 0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Jets").grid('column'=>6,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @jets = TkCheckButton.new(tframe).grid('column'=>7,'row'=> 0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    TkLabel.new(tframe, 'text'=>"Super Subs").grid('column'=>8,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @superSubs = TkCheckButton.new(tframe).grid('column'=>9,'row'=> 0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    
    #attackers
    aclear = proc {
      @aunitsnums.each{|sbox| sbox.set("0")}
      @aupdate.call
    }
    aunitup = proc{
      index = @alist.curselection[0]
      if (index != nil) and (index > 0)
        if (@aunits[index].value < @aunits[index-1].value) or (@aunits[index].power < @aunits[index-1].power) or @aunits[index].is_a?(Transport) or (@aunits[index] == @aunits[index-1])
          temp = @aunits[index-1]
          @aunits[index-1] = @aunits[index]
          @aunits[index] = temp
          @anames.set_list(@aunits.collect{|unit|unit.class})
          @alist.see(index - 1)
          @alist.selection_clear(index)
          @alist.selection_set(index - 1)
        end
      end
    }
    aunitdown = proc{
      index = @alist.curselection[0]
      if (index != nil) and (@aunits.size > 1) and (index < (@aunits.size - 1))
        if (@aunits[index].value > @aunits[index+1].value) or (@aunits[index].power > @aunits[index+1].power) or @aunits[index].is_a?(Transport) or (@aunits[index] == @aunits[index+1])
          temp = @aunits[index+1]
          @aunits[index+1] = @aunits[index]
          @aunits[index] = temp
          @anames.set_list(@aunits.collect{|unit|unit.class})
          @alist.see(index + 1)
          @alist.selection_clear(index)
          @alist.selection_set(index + 1)
        end
      end     
    }
    aenableother = proc{
      @aup.state('active')
      @adown.state('active')     
    }
    @aupdate = proc{
      if @alist.curselection.size != 0
        @alist.selection_clear(@alist.curselection[0])
      end
      @aup.state('disabled')
      @adown.state('disabled')
      @aunits = Array.new
      @aunitsnums[0].get.to_i.times {@aunits.push(Infantry.new(true))}
      @aunitsnums[1].get.to_i.times {@aunits.push(Tank.new(true))}
      @aunitsnums[2].get.to_i.times {@aunits.push(Artillery.new(true))}
      @aunitsnums[3].get.to_i.times {@aunits.push(Fighter.new(true,@jets.get_value == '1'))}
      @aunitsnums[4].get.to_i.times {@aunits.push(Bomber.new(true,@heavyBombers.get_value == '1'))}
      @aunitsnums[5].get.to_i.times {@aunits.push(Destroyer.new(true))}
      @aunitsnums[6].get.to_i.times {@aunits.push(Battleship.new(true))}
      @aunitsnums[7].get.to_i.times {@aunits.push(Carrier.new(true))}
      @aunitsnums[8].get.to_i.times {@aunits.push(Transport.new(true))}
      @aunitsnums[9].get.to_i.times {@aunits.push(Sub.new(true,@superSubs.get_value == '1'))}
      
      if @asort.to_s == 'value'
        @aunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @asort.set_value('power') #in case it's set to 'other'
        @aunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end
 
      @anames.set_list(@aunits.collect{|unit|unit.class})
    }
    row = -1
    @aunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(aframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      TkSpinbox.new(aframe,'to'=>100, 'from'=>0, 'width'=>3, 'command'=>@aupdate).grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    }
    TkLabel.new(aframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @asort = TkVariable.new
    @asort.set_value('power')
    TkRadioButton.new(aframe,'text'=>'Power','variable'=>@asort,'value'=>'power','command'=>@aupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Value','variable'=>@asort,'value'=>'value','command'=>@aupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Other','variable'=>@asort,'value'=>'other','command'=>aenableother).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    ayscroll = proc{|*args| @albscroll.set(*args)}
    ascroll = proc{|*args| @alist.yview(*args)}
    @anames = TkVariable.new
    @alist = TkListbox.new(aframe,'listvariable'=>@anames,'height' => 12,'yscrollcommand'=> ayscroll).grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @alist.bind('<ListboxSelect>'){@asort.set_value('other');aenableother.call}
    @albscroll = TkScrollbar.new(aframe,'orient'=>'vertical','command'=>ascroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @aup = TkButton.new(aframe,'text'=>'Up','command'=>aunitup).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @adown = TkButton.new(aframe,'text'=>'Down','command'=>aunitdown).grid('column'=>3, 'row'=>9, 'padx'=>5)
    @aup.state('disabled')
    @adown.state('disabled')
    TkButton.new(aframe,'text'=>'Clear','command'=>aclear).grid('column'=>2, 'row'=>10, 'padx'=>5)

    #defenders
    dclear = proc {
      @dunitsnums.each{|sbox| sbox.set("0")}
      @dupdate.call
    }
    dunitup = proc{
      index = @dlist.curselection[0]
      if (index != nil) and (index > 0)
        if (@dunits[index].value < @dunits[index-1].value) or (@dunits[index].power < @dunits[index-1].power) or @dunits[index].is_a?(Transport) or (@dunits[index] == @dunits[index-1])
          temp = @dunits[index-1]
          @dunits[index-1] = @dunits[index]
          @dunits[index] = temp
          @dnames.set_list(@dunits.collect{|unit|unit.class})
          @dlist.see(index - 1)
          @dlist.selection_clear(index)
          @dlist.selection_set(index - 1)
        end
      end
    }
    dunitdown = proc{
      index = @dlist.curselection[0]
      if (index != nil) and (@dunits.size > 1) and (index < (@dunits.size - 1))
        if (@dunits[index].value > @dunits[index+1].value) or (@dunits[index].power > @dunits[index+1].power) or @dunits[index].is_a?(Transport) or (@dunits[index] == @dunits[index+1])
          temp = @dunits[index+1]
          @dunits[index+1] = @dunits[index]
          @dunits[index] = temp
          @dnames.set_list(@dunits.collect{|unit|unit.class})
          @dlist.see(index + 1)
          @dlist.selection_clear(index)
          @dlist.selection_set(index + 1)
        end
      end     
    }
    denableother = proc{
      @dup.state('active')
      @ddown.state('active')     
    }
    @dupdate = proc{
      if @dlist.curselection.size != 0
        @dlist.selection_clear(@dlist.curselection[0])
      end
      @dup.state('disabled')
      @ddown.state('disabled')
      @dunits = Array.new
      @dunitsnums[0].get.to_i.times {@dunits.push(Infantry.new(false))}
      @dunitsnums[1].get.to_i.times {@dunits.push(Tank.new(false))}
      @dunitsnums[2].get.to_i.times {@dunits.push(Artillery.new(false))}
      @dunitsnums[3].get.to_i.times {@dunits.push(Fighter.new(false,@jets.get_value == '1'))}
      @dunitsnums[4].get.to_i.times {@dunits.push(Bomber.new(false,@heavyBombers.get_value == '1'))}
      @dunitsnums[5].get.to_i.times {@dunits.push(Destroyer.new(false))}
      @dunitsnums[6].get.to_i.times {@dunits.push(Battleship.new(false))}
      @dunitsnums[7].get.to_i.times {@dunits.push(Carrier.new(false))}
      @dunitsnums[8].get.to_i.times {@dunits.push(Transport.new(false))}
      @dunitsnums[9].get.to_i.times {@dunits.push(Sub.new(false,@superSubs.get_value == '1'))}
      
      if @dsort.to_s == 'value'
        @dunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @dsort.set_value('power') #in case it's set to 'other'
        @dunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end
      @dnames.set_list(@dunits.collect{|unit|unit.class})
    }
    row = -1
    @dunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(dframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      TkSpinbox.new(dframe,'to'=>100, 'from'=>0, 'width'=>3,'command'=>@dupdate).grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    }
    TkLabel.new(dframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @dsort = TkVariable.new
    @dsort.set_value('power')
    TkRadioButton.new(dframe,'text'=>'Power','variable'=>@dsort,'value'=>'power','command'=>@dupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Value','variable'=>@dsort,'value'=>'value','command'=>@dupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Other','variable'=>@dsort,'value'=>'other','command'=>denableother).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    dyscroll = proc{|*args| @dlbscroll.set(*args)}
    dscroll = proc{|*args| @dlist.yview(*args)}
    @dnames = TkVariable.new('')
    @dlist = TkListbox.new(dframe,'listvariable'=>@dnames,'height' => 12,'yscrollcommand'=> dyscroll).grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @dlist.bind('<ListboxSelect>'){@dsort.set_value('other');denableother.call}
    @dlbscroll = TkScrollbar.new(dframe,'orient'=>'vertical','command'=>dscroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @dup = TkButton.new(dframe,'text'=>'Up','command'=>dunitup).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @ddown = TkButton.new(dframe,'text'=>'Down','command'=>dunitdown).grid('column'=>3, 'row'=>9, 'padx'=>5)
    @dup.state('disabled')
    @ddown.state('disabled')
    TkButton.new(dframe,'text'=>'Clear','command'=>dclear).grid('column'=>2, 'row'=>10, 'padx'=>5)
   
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