require 'tk'
#require 'generator'

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

class Counter
  attr_reader :value
  attr_writer :value
  def initialize(num=0)
    @value = num
  end

  def inc
    old_value = @value
    @value += 1
    return old_value
  end
end

class Unit
  attr_reader :value, :can_bombard, :lives, :first_strike, :attacking, :attack, :defend
  attr_writer :attacking
  def initialize(attack, defend, value, can_bombard, type, attacking=true)
    @attack = attack
    @defend = defend
    @value = value
    @can_bombard = can_bombard
    @type = type
    @attacking = attacking
  end
  def land
    @type == 0
  end
  def sea
    @type == 1
  end
  def air
    @type == 2
  end
  def power
    if @attacking
      @attack
    else
      @defend
    end
  end  
  def prob
    if @attacking
      @attack/6.0
    else
      @defend/6.0
    end
  end
  def dup
    Unit.new(@attack, @defend, @value, @can_bombard, @type, @attacking)
  end
  def ==(other)
    (self.class == other.class) and (attacking == other.attacking)
  end
end

class Infantry < Unit
  def initialize
    super(1,2,3,false,0)
  end
  def artillery_pair
    @attack = 2
  end
  def reset_pair
    @attack = 1
  end
  def dup #because we want to keep the Infantry type
    temp = Infantry.new
    if @attack == 2
      temp.artillery_pair
    end
    return temp
  end
  def ==(other)
    super(other) and (@attack == other.attack)
  end
end

class Tank < Unit
  def initialize
    super(3,3,5,false,0)
  end
  def dup
    Tank.new
  end
end

class Artillery < Unit
  def initialize
    super(2,2,4,false,0)
  end
  def dup
    Artillery.new
  end
end

class Fighter < Unit
  def initialize(jet=false)
    if jet
      super(3,5,10,false,2)
    else
      super(3,4,10,false,2)
    end
  end
  def dup
    Fighter.new(@defend == 5)
  end
  def ==(other)
    super(other) and (@defend == other.defend)
  end
end

class Bomber < Unit
  attr_reader :heavy
  def initialize(heavy=false)
    @heavy = heavy
    super(4,1,15,false,2)
  end
  def dup
    Bomber.new(@heavy)
  end
  def make_heavy
    @heavy = true
  end
  def make_normal
    @heavy = false
  end
  def ==(other)
    super(other) and (@heavy == other.heavy)
  end
end

class Destroyer < Unit
  def initialize(combined_bombardment=false)
    super(3,3,12,combined_bombardment,1)
  end
  def dup
    Destroyer.new(@can_bombard)
  end
  def ==(other)
    super(other) and (@can_bombard == other.can_bombard)
  end
end

class Battleship < Unit
  attr_reader :lives
  def initialize
    @lives = 2
    super(4,4,24,true,1)
  end
  def dup
    temp = Battleship.new
    temp.take_hit if @lives == 1
    temp
  end
  def take_hit
    @lives = @lives - 1
  end
  def ==(other)
    super(other) and (@lives == other.lives)
  end
end

class Carrier < Unit
  def initialize
    super(1,3,16,false,1)
  end
  def dup
    Carrier.new
  end
end

class Transport < Unit
  def initialize
    super(0,1,8,false,1)
  end
  def dup
    Transport.new
  end
end

class Sub < Unit
  def initialize(sup = false)
    if sup
      super(3,2,8,false,1)
    else
      super(2,2,8,false,1)
    end
  end
  def dup
    Sub.new(@attack == 2 ? false : true)
  end
  def ==(other)
    super(other) and (@attack == other.attack)
  end
end

class Army
protected
#  attr_reader :units

  def pair_infantry
    infantry = @units.find_all{|unit| unit.is_a?(Infantry)}
    infantry.each{|unit| unit.reset_pair}
    num_artillery = @units.inject(0){|num, unit| num + unit.is_a?(Artillery).to_i}
    min(num_artillery,infantry.length).times{|x| infantry[x].artillery_pair}
  end
  
  def conditional_loss (hits)
    units = @units.find_all{|unit| yield(unit)}
    battle_ships_with_lives = units.find_all{|unit| unit.is_a?(Battleship) and (unit.lives > 1)}
    if hits >= (units.size + battle_ships_with_lives.size)
      @units.delete_if{|item| yield(item)}
    else
      min(hits,battle_ships_with_lives.size).times do |x|
	battle_ships_with_lives[x].take_hit
      end
      (hits - min(hits,battle_ships_with_lives.size)).times do
        remove = units.inject do |lowest,unit|
          if (unit.value < lowest.value) or ((unit.value == lowest.value) and (unit.power < lowest.power))
            unit
          else
            lowest #inject needs something returned to it
          end
        end
        units.delete_if{|unit| unit.object_id == remove.object_id}
        @units.delete_if{|unit| unit.object_id == remove.object_id}
      end
    end
  end

  def conditional_probability(hits)
    units = @units.find_all{|unit| yield(unit)}
    if hits <= 0
      return units.inject(1){|prob,unit| prob * (1 - unit.prob)}
    elsif hits > units.size
      return 0
    else
      prob = 0
      1.upto(6) do |x|
        group = units.find_all{|unit| unit.power == x}
        if group.length != 0
          nunits = Array.new
          units.each{|unit| nunits.push(unit) if unit.object_id != group[0].object_id}
          temparmy = Army.new(@attacking,false,nunits)
          max_hits = conditional_max_hits{|unit| yield(unit)}.to_f
#temparmy already only has units that satisfy the condition, so we can have {|unit| true}
          prob += (x / 6.0)*(group.length / max_hits) * temparmy.conditional_probability(hits - 1) {|unit| true}
          prob += (1 - (x / 6.0))*(group.length / max_hits) * temparmy.conditional_probability(hits) {|unit| true}
        end
      end
    end
    return prob
  end

  def conditional_max_hits
    @units.inject(0) do |sum,unit|
      if yield(unit) and unit.is_a?(Bomber) and unit.heavy
        sum += 2
      elsif yield(unit) and (unit.power > 0) #to filter out transports
        sum += 1
      else
        sum
      end
    end
  end

  def num
    @units.inject(0){|sum, unit| sum + yield(unit).to_i}
  end

public
attr_reader :units #for debuging only!
  def initialize(attacking,unpaired,units=nil)
    @attacking = attacking
    if units == nil
      @units = Array.new
    else
      @units = units
      @units.each{|unit| unit.attacking = attacking }
      if attacking and unpaired
        self.pair_infantry
      end
    end
  end

  def ==(other)
     if self.class == other.class
       temp = other.units.dup
       count = 0
       @units.each do |unit|
         i = temp.index(unit) #TODO: use object_id instead
         if i != nil
           temp.delete_at(i)
           count += 1
         end
       end
       (temp.size == 0) and (count == @units.size)
     else
       false
     end 
  end
  
  def dup
    Army.new(@attacking,false,Array.new(units.length){|x| units[x].dup})
  end
  
  def value
    @units.inject(0){|value, unit| value + unit.value}
  end
  
  def sea_value
    @units.inject(0){|value, unit| value + (unit.sea ? unit.value : 0)}
  end
  
  def size
    @units.length
  end
  
  def num_aircraft
    @units.inject(0){|num, unit| num + unit.air.to_i}
  end  
  
  def max_hits
    self.conditional_max_hits{|unit| true}
  end
  
  def has_land
    @units.find{|unit| unit.land} != nil
  end
  
  def has_sea
    @units.find{|unit| unit.sea} != nil
  end

  def has_air
    @units.find{|unit| unit.air} != nil
  end

  def has_battleship
    @units.find{|unit| unit.is_a?(Battleship)} != nil
  end

  def can_bombard
    @units.find{|unit| unit.can_bombard} != nil
  end
  
  def max_bombard_hits
    self.conditional_max_hits{|unit| unit.can_bombard}
  end
  
  def remove_sea
    @units.delete_if{|unit| unit.sea}
    self
  end  
  
  def lose(hits)
    self.conditional_loss(hits) {|unit| true}
    self.pair_infantry
    self
  end
  
  def lose_aircraft(hits)
    self.conditional_loss(hits) {|unit| unit.air}
    self
  end
  
  def probability(hits)
    hbombers = @units.find_all {|unit| unit.is_a?(Bomber) and unit.heavy}
    if @attacking and hbombers.length > 0
      hbombers.each do |bomber|
        bomber.make_normal
        @units.push(bomber.dup)
      end
    end
    prob = self.conditional_probability(hits) {|unit| true}
    if @attacking and hbombers.length > 0
      hbombers.each {|bomber| bomber.make_heavy}
      @units.delete_if {|unit| unit.is_a?(Bomber) and (not unit.heavy)}
    end
    return prob
  end  
  
  def bombard_probability(hits)
    self.conditional_probability(hits) {|unit| unit.can_bombard}
  end
  
  def testprob
    prob = 0
    0.upto(self.max_hits) do |x|
      prob += self.probability(x)
    end
    return prob
  end
end

class Battle
protected
  attr_reader :attacker, :defender, :aagun
  @@battles = Array.new
  def ==(other)
    (self.object_id == other.object_id) and (@attacker == other.attacker) and (@defender == other.defender) and (@aagun == other.aagun)
  end
 
  def same_as(a,d)
    (@attacker == a) and (@defender == d)
  end

  def find_or_add(a, d)
    found_or_new = @@battles.find{|battle| battle.same_as(a,d)}
    if found_or_new == nil
      found_or_new = Battle.new(a,d)
      @@battles.push(found_or_new)
    end
    found_or_new
  end

public
  def Battle.battles_calculated
    @@battles.size
  end

  def initialize(attacker, defender, aagun = false)
    @attacker = attacker.dup
    @defender = defender.dup
    @aagun = aagun
    @fireAA = (aagun and @attacker.has_air)
    #bombardment happens if there are units that can bombars, and if there are land units
    @bombard = (@attacker.can_bombard and @attacker.has_land)
    #AAgun fire and Bombards are already normazlied
    @normalize = 1.0
    #if there are battleships, then 1v1 combat is not good
    @battleship = (@attacker.has_battleship or @defender.has_battleship)
    #can we calculate one on one combat?
#if aa guns fired, then there are multiple options even though the battle might have only one unit per side 
#@attacker.max_hits because one heavy bomber has size 1 but can hit twice
    @can_single = ((not @fireAA) and (not @battleship) and (@attacker.max_hits == 1) and (@defender.size == 1))

    if @fireAA
      @possibilities = Array.new(attacker.num_aircraft + 1) do |x|
#        Battle.new(attacker.dup.lose_aircraft(x),defender.dup,false, binom(attacker.num_aircraft,x, 1 / 6.0))
        find_or_add(attacker.dup.lose_aircraft(x),defender.dup)
      end
      @probabilities = Array.new(attacker.num_aircraft + 1) do |x|
        binom(attacker.num_aircraft,x, 1 / 6.0)
      end
    elsif @bombard
      @possibilities = Array.new(attacker.max_bombard_hits + 1) do |x|
        find_or_add(attacker.dup.remove_sea,defender.dup.lose(x))
      end
      @probabilities = Array.new(attacker.max_bombard_hits + 1) do |x|
        attacker.bombard_probability(x)
      end
    elsif (attacker.size > 0) and (defender.size > 0)
      @possibilities = Array.new(attacker.max_hits + 1) do |x|
        Array.new(defender.max_hits + 1) do |y|
          if (x == 0) and (y == 0)
            nil #to prevent infinite recursion
          else
            find_or_add(attacker.dup.lose(y), defender.dup.lose(x))
          end
        end
      end
      @probabilities = Array.new(attacker.max_hits + 1) do |x|
        Array.new(defender.max_hits + 1) do |y|
          if (x == 0) and (y == 0)
            nil
          else
            attacker.probability(x)*defender.probability(y)
          end
        end
      end
      @possibilities.flatten! #@possibilities consists of nested arrays, we don't want it that way
      @possibilities.delete(nil) #get rid of the 'nil' item
      @probabilities.flatten!
      @probabilities.delete(nil)
      @normalize = 1 / (1 - @attacker.probability(0)*@defender.probability(0))

#puts "weights"
#@possibilities.each{|battle| puts battle.weight(self.object_id) }
    end
  end

  def prob_attacker_wins
    unless defined?(@paw)
      if (@attacker.size != 0) and (@defender.size == 0)
        @paw = 1
      elsif @attacker.size == 0
        @paw = 0
      elsif @can_single
        @paw = @attacker.probability(1) * @defender.probability(0) * @normalize
      else
        @paw = @possibilities.zip(@probabilities).inject(0){|sum,args| sum + args[0].prob_attacker_wins * args[1]} * @normalize
#        gen = SyncEnumerator.new(@possibilities,@probabilities)
#        gen.inject(0){|sum,args| sum + args[0].prob_attacker_wins * args[1]} * @normalize
      end
    end
    @paw
  end
  
  def prob_defender_wins
    unless defined?(@pdw)
      if (@attacker.size == 0) and (@defender.size != 0)
        @pdw = 1
      elsif @defender.size == 0
        @pdw = 0
      elsif @can_single
        @pdw = @attacker.probability(0) * @defender.probability(1) * @normalize
      else
        @pdw = @possibilities.zip(@probabilities).inject(0){|sum,args| sum + args[0].prob_defender_wins * args[1]} * @normalize
#        gen = SyncEnumerator.new(@possibilities,@probabilities)
#        gen.inject(0){|sum,args| sum + args[0].prob_defender_wins * args[1]} * @normalize
      end  
    end
    @pdw
  end
  def prob_mutual_annihilation
    unless defined?(@pma)
      if (@attacker.size == 0) and (@defender.size == 0)
        @pma = 1
      elsif ((@attacker.size == 0) and (@defender.size != 0)) or ((@attacker.size != 0) and (@defender.size == 0))
        @pma = 0
      elsif @can_single
        @pma = @attacker.probability(1) * @defender.probability(1) * @normalize
      else
        @pma = @possibilities.zip(@probabilities).inject(0){|sum,args| sum + args[0].prob_mutual_annihilation * args[1]} * @normalize
#        gen = SyncEnumerator.new(@possibilities,@probabilities)
#        gen.inject(0){|sum,args| sum + args[0].prob_mutual_annihilation * args[1]} * @normalize
      end
    end
    @pma
  end
  
  def testprob
    return self.prob_attacker_wins + self.prob_defender_wins + self.prob_mutual_annihilation
  end
  
  def expected_attacking_army_value
    if @attacker.size == 0
      0
    elsif @defender.size == 0
      @attacker.value
    else
      ex = @possibilities.inject(0){|ev,battle| ev + battle.weight(self.object_id) * battle.expected_attacking_army_value} * @normalize
      if @bombard
        ex += @attacker.sea_value #since ships are removed after bombardment
      end
    end
  end

  def expected_defending_army_value
    if @defender.size == 0
      0
    elsif @attacker.size == 0
      @defender.value
    else
      @possibilities.inject(0){|ev,battle| ev + battle.weight(self.object_id)*battle.expected_defending_army_value} * @normalize
    end
  end

  def expected_IPC_loss_attacker
    @attacker.value - self.expected_attacking_army_value
  end
  def expected_IPC_loss_defender
    @defender.value - self.expected_defending_army_value
  end
end

class BattleGUI
  def initialize
    @root = TkRoot.new() {title 'Battle Calculator'}

    row = Counter.new

    TkLabel.new(@root, 'text'=>"AA gun").grid('column'=>0,'row'=>row.value, 'sticky'=>'w')
    @aaGun = TkCheckButton.new(@root).grid('column'=>1,'row'=> row.value, 'sticky'=>'w')
    TkLabel.new(@root, 'text'=>"Hv. Bombers").grid('column'=>2,'row'=>row.value, 'sticky'=>'w')
    @heavyBombers = TkCheckButton.new(@root).grid('column'=>3,'row'=> row.inc, 'sticky'=>'w')
    TkLabel.new(@root, 'text'=>"Comb. Bom.").grid('column'=>0,'row'=>row.value, 'sticky'=>'w')
    @combinedBombardment = TkCheckButton.new(@root).grid('column'=>1,'row'=> row.value, 'sticky'=>'w')
    TkLabel.new(@root, 'text'=>"Jets").grid('column'=>2,'row'=>row.value, 'sticky'=>'w')
    @jets = TkCheckButton.new(@root).grid('column'=>3,'row'=> row.inc, 'sticky'=>'w')
    TkLabel.new(@root, 'text'=>"Super Subs").grid('column'=>0,'row'=>row.value, 'sticky'=>'w')
    @superSubs = TkCheckButton.new(@root).grid('column'=>1,'row'=> row.inc, 'sticky'=>'w')


    unitStartRow = 4
    TkLabel.new(@root, 'text'=>"Attacker").grid('column'=>0,'row'=>row.value, 'sticky'=>'w','pady'=>5)
    TkLabel.new(@root, 'text'=>"Defender").grid('column'=>2,'row'=>row.inc, 'sticky'=>'w','pady'=>5)
    @aunits = Array.new(10) {TkVariable.new()}
    @dunits = Array.new(10) {TkVariable.new()}
    num_units = (0..20).to_a
    alabels = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(@root, 'text'=>label)}
    dlabels = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(@root, 'text'=>label)}
    10.times do |i|
      alabels[i].grid('column'=>0,'row'=> row.value, 'sticky'=>'w')
      TkOptionMenubutton.new(@root, @aunits[i], *num_units) {width   1}.grid('column'=>1, 'row'=>row.value,'sticky'=>'w')
      dlabels[i].grid('column'=>2,'row'=> row.value, 'sticky'=>'w')
      TkOptionMenubutton.new(@root, @dunits[i], *num_units) {width   1}.grid('column'=>3, 'row'=>row.inc,'sticky'=>'w')
    end

    calc = proc {self.doBattle}  
    TkButton.new(@root) {
      text    'Clalculate'
      command calc
    }.grid('column'=>1, 'row'=>10 + unitStartRow,'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    reset = proc {
      @aunits.each{|var| var.value = 0}
      @dunits.each{|var| var.value = 0}
      @aaGun.set_value('0')
      @heavyBombers.set_value('0')
      @combinedBombardment.set_value('0')
      @jets.set_value('0')
      @superSubs.set_value('0')
    }  
    TkButton.new(@root) {
      text    'Reset'
      command reset
    }.grid('column'=>2, 'row'=>10 + unitStartRow,'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(@root, 'text'=>"Attacker wins").grid('column'=>0,'row'=> 11 + unitStartRow, 'sticky'=>'w')
    @attackerProb = TkVariable.new()
    attackerProbDisp = TkEntry.new(@root) {
      width 30
      relief  'sunken'
    }.grid('column'=>1,'row'=> 11 + unitStartRow, 'sticky'=>'w', 'padx'=>5)
    attackerProbDisp.textvariable(@attackerProb)

    TkLabel.new(@root, 'text'=>"Defender wins").grid('column'=>0,'row'=> 12 + unitStartRow, 'sticky'=>'w')
    @defenderProb = TkVariable.new()
    defenderProbDisp = TkEntry.new(@root) {
      width 30
      relief  'sunken'
    }.grid('column'=>1,'row'=> 12 + unitStartRow, 'sticky'=>'w', 'padx'=>5)
    defenderProbDisp.textvariable(@defenderProb)

    TkLabel.new(@root, 'text'=>"Mutual annihilation").grid('column'=>0,'row'=> 13 + unitStartRow, 'sticky'=>'w')
    @annihilationProb = TkVariable.new()
    annihilationProbDisp = TkEntry.new(@root) {
      width 30
      relief  'sunken'
    }.grid('column'=>1,'row'=> 13 + unitStartRow, 'sticky'=>'w', 'padx'=>5)
    annihilationProbDisp.textvariable(@annihilationProb)

    TkLabel.new(@root, 'text'=>"Sum").grid('column'=>0,'row'=> 14 + unitStartRow, 'sticky'=>'w')
    @sum = TkVariable.new()
    sumDisp = TkEntry.new(@root) {
      width 30
      relief  'sunken'
    }.grid('column'=>1,'row'=> 14 + unitStartRow, 'sticky'=>'w', 'padx'=>5)
    sumDisp.textvariable(@sum)

    TkLabel.new(@root, 'text'=>"Battles").grid('column'=>0,'row'=> 15 + unitStartRow, 'sticky'=>'w')
    @battles = TkVariable.new()
    battleDisp = TkEntry.new(@root) {
      width 30
      relief  'sunken'
    }.grid('column'=>1,'row'=> 15 + unitStartRow, 'sticky'=>'w', 'padx'=>5)
    battleDisp.textvariable(@battles)
  end
  def doBattle
    attackers = Array.new
    defenders = Array.new

    @aunits[0].to_i.times {attackers.push(Infantry.new)}
    @aunits[1].to_i.times {attackers.push(Tank.new)}
    @aunits[2].to_i.times {attackers.push(Artillery.new)}
    @aunits[3].to_i.times {attackers.push(Fighter.new)}
    @aunits[4].to_i.times {attackers.push(Bomber.new(@heavyBombers.get_value == '1'))}
    @aunits[5].to_i.times {attackers.push(Destroyer.new(@combinedBombardment.get_value == '1'))}
    @aunits[6].to_i.times {attackers.push(Battleship.new)}
    @aunits[7].to_i.times {attackers.push(Carrier.new)}
    @aunits[8].to_i.times {attackers.push(Transport.new)}
    @aunits[9].to_i.times {attackers.push(Sub.new(@superSubs.get_value == '1'))}

    @dunits[0].to_i.times {defenders.push(Infantry.new)}
    @dunits[1].to_i.times {defenders.push(Tank.new)}
    @dunits[2].to_i.times {defenders.push(Artillery.new)}
    @dunits[3].to_i.times {defenders.push(Fighter.new(@jets.get_value == '1'))}
    @dunits[4].to_i.times {defenders.push(Bomber.new)}
    @dunits[5].to_i.times {defenders.push(Destroyer.new)}
    @dunits[6].to_i.times {defenders.push(Battleship.new)}
    @dunits[7].to_i.times {defenders.push(Carrier.new)}
    @dunits[8].to_i.times {defenders.push(Transport.new)}
    @dunits[9].to_i.times {defenders.push(Sub.new)}

    aarmy = Army.new(true,true,attackers)
    darmy = Army.new(false,true,defenders)
    @battle = Battle.new(aarmy,darmy,@aaGun.get_value == '1')
    @attackerProb.value = @battle.prob_attacker_wins.to_s
    @defenderProb.value = @battle.prob_defender_wins.to_s
    @annihilationProb.value = @battle.prob_mutual_annihilation.to_s
    @sum.value = @battle.testprob
    @battles.value = Battle.battles_calculated
  end
end

if __FILE__ == $0
  BattleGUI.new
  Tk.mainloop()
end