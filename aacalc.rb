require 'tk'

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

class Unit
	attr_reader :value, :can_bombard, :lives, :first_strike, :attacks, :attacking
	attr_writer :attacking
	def initialize(attack, defend, value, can_bombard, type, attacking = true)
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
	def dup #because we want to keep the Artillery type
		Artillery.new
	end
end

class Fighter < Unit
	def initialize(jet = false)
		if jet
			super(3,5,10,false,2)
		else
			super(3,4,10,false,2)
		end
	end
	def dup
		Fighter.new(@defence == 4 ? false : true)
	end
end

class Bomber < Unit
	attr_reader :heavy
	def initialize(heavy = false)
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
end

class Destroyer < Unit
	def initialize(combined_bombardment = false)
		super(3,3,12,combined_bombardment,1)
	end
	def dup
		Destroyer.new(can_bombard)
	end
end

class Battleship < Unit
	attr_reader :lives
	def initialize(lives = 2)
		@lives = lives
		super(4,4,24,true,1)
	end
	def dup
		Battleship.new(@lives)
	end
	def take_hit
		@lives = @lives - 1
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
end

class Army
protected
	def pair_infantry
		infantry = @units.find_all{|unit| unit.is_a?(Infantry)}
		infantry.each{|unit| unit.reset_pair}
		num_artillery = @units.inject(0){|num, unit| num + (unit.is_a?(Artillery) ? 1 : 0)}
		(num_artillery > infantry.length ? infantry.length : num_artillery).times do |x|
			infantry[x].artillery_pair
		end
	end
	
	def conditional_loss (hits)
		num = @units.inject(0){|sum, unit| sum + (yield(unit) ? 1 : 0)}
		if num <= hits
			@units.delete_if{|item| yield(item)}
		else	
			hits.times do
				has_life = @units.find {|unit| yield(unit) and unit.is_a?(Battleship) and (unit.lives > 1)}
				if has_life != nil
					has_life.take_hit
				else
					remove = @units.inject(@units.find{|unit| yield(unit)}) do |lowest,unit|
						if yield(unit)
							if (unit.value < lowest.value) or ((unit.value == lowest.value) and (unit.power < lowest.power))
								unit
							else
								lowest #inject needs something returned to it
							end
						end
					end
					@units.delete(remove)			
				end
			end
		end
	end

	def conditional_probability(hits)
		max_hits = @units.inject(0){|sum, unit| sum + (yield(unit) ? 1 : 0)}
		if hits <= 0
			return @units.inject(1){|prob,unit| prob * (1 - unit.prob)}
		elsif hits > max_hits
			return 0
		else
			prob = 0
			1.upto(6) do |x|
				group = @units.find_all{|unit| yield(unit) and (unit.power == x)}
				if group.length != 0
					temparmy = Army.new(@attacking,false,@units.reject{|unit| unit == group[0]})
					prob += (x/6.0)*(group.length/max_hits.to_f) * temparmy.probability(hits - 1)
					prob += (1 - (x/6.0))*(group.length/max_hits.to_f) * temparmy.probability(hits)					
				end
			end
		end
		return prob
	end

public

attr_reader :units
	def initialize(attacking,unpaired,units = nil)
		@attacking = attacking
		if units == nil
			@units = Array.new
		else
			@units = Array.new(units.length){|x| units[x].dup}
			@units.each{|unit| unit.attacking = attacking }
			if attacking and unpaired
				self.pair_infantry
			end
		end
	end
	
	def add_array(units)
		units.each{|unit| unit.attacking = attacking }
		@units.concat(units)
		self.pair_infantry
		self
	end
	
	def dup
		Army.new(@attacking,false,@units)
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
		@units.inject(0){|num, unit| num + (unit.air ? 1 : 0)}
	end	
	
	def max_hits
		self.size + @units.inject(0){|sum,unit| sum + ((unit.is_a?(Bomber) and unit.heavy) ? 1 : 0)}
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
	
	def can_bombard
		@units.find{|unit| unit.can_bombard} != nil
	end
	
	def max_bombard_hits
		@units.inject(0){|bombards, unit| bombards + (unit.can_bombard ? 1 : 0)}
	end
	
	def remove_sea
		@units.delete_if{|unit| unit.sea}
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
			@units.delete_if {|unit| unit.is_a?(Bomber) and (not hbombers.include?(unit))}
		end
		return prob
	end	
	
	def bombard_probability(hits) #TODO: Special rule for combined bombardment
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
	attr_reader :weight
	def initialize(attacker, defender, aagun, weight = 1.0)
		@attacker = attacker.dup
		@defender = defender.dup
		@weight = weight
		@fireAA = aagun and @attacker.has_air
		if (@attacker.size > 0) and (@defender.size > 0)
			@normalize = 1/(1 - @attacker.probability(0)*@defender.probability(0))
		else
			@normalize = 1.0
		end
		
		if @fireAA
			@possibilities = Array.new(attacker.num_aircraft + 1) do |x| #TODO: is the below weight calculation correct?
				Battle.new(attacker.dup.lose_aircraft(x),defender.dup,false, binom(attacker.num_aircraft,x, 1 / 6.0))
				#combinations(attacker.num_aircraft,x) * ((1 / 6.0)**x) * ((5 / 6.0)**(attacker.num_aircraft - x)) )
			end
			@normalize = 1.0 #if we're firing AA, then the probabilities add to 1, so there's no need to normalize
		#bombardment happens if there are units that can bombars, and if there are land units
		elsif @attacker.can_bombard and @attacker.has_land
			@possibilities = Array.new(attacker.max_bombard_hits) do |x|
				Battle.new(attacker.dup.remove_sea,defender.dup.lose(x),false, attacker.bombard_probability(x))
			end
		elsif (attacker.size != 0) and (defender.size != 0) #TODO: change to size > 1 ?
			@possibilities = Array.new(attacker.max_hits + 1) do |x|
				Array.new(defender.max_hits + 1) do |y|
					if (x == 0) and (y == 0)
						nil #to prevent infinite recursion
					else				
						Battle.new(attacker.dup.lose(y), defender.dup.lose(x), false, attacker.probability(x)*defender.probability(y))
					end
				end
			end
			@possibilities.flatten! #@possibilities consists of nested arrays, we don't want it that way
			@possibilities.delete(nil) #get rid of the 'nil' item
		end
	end

	def prob_attacker_wins
		if (@attacker.size != 0) and (@defender.size == 0)
			return 1
		elsif @attacker.size == 0
			return 0
		elsif (@attacker.size == 1) and (@defender.size == 1) and (not @fireAA)
			return ((@attacker.probability(1)+@attacker.probability(2))*@defender.probability(0)) * @normalize
		else
			return (@possibilities.inject(0) {|prob, battle| prob + battle.weight*battle.prob_attacker_wins}) * @normalize
		end
	end
	
	def prob_defender_wins
		if (@attacker.size == 0) and (@defender.size != 0)
			return 1
		elsif @defender.size == 0
			return 0
		elsif (@attacker.size == 1) and (@defender.size == 1) and (not @fireAA)
#if aa guns fired, then there are multiple options even though the battle might have only one unit per side
			return (@attacker.probability(0)*@defender.probability(1)) * @normalize
		else
			return (@possibilities.inject(0) {|prob, battle| prob + battle.weight*battle.prob_defender_wins}) * @normalize
		end	
	end
	def prob_mutual_annihilation
		if (@attacker.size == 0) and (@defender.size == 0)
			return 1
		elsif ((@attacker.size == 0) and (@defender.size != 0)) or ((@attacker.size != 0) and (@defender.size == 0))
			return 0
		elsif (@attacker.size == 1) and (@defender.size == 1) and (not @aagun)
#if aa guns fired, then there are multiple options even though the battle might have only one unit per side
			return ((@attacker.probability(1)+@attacker.probability(2))*@defender.probability(1)) * @normalize
		else
			return (@possibilities.inject(0) {|prob, battle| prob + battle.weight*battle.prob_mutual_annihilation}) * @normalize
		end
	end
	
	def testprob
		return self.prob_attacker_wins + self.prob_defender_wins + self.prob_mutual_annihilation
	end
	
	def expected_attacking_army_value
		if @attacker.size == 0
			return 0
		elsif @defender.size == 0
			return @attacker.value
		else
			ex = (@possibilities.inject(0) {|ev,battle| ev + battle.weight*battle.expected_attacking_army_value}) * @normalize
			if @attacker.can_bombard and @attacker.has_land
				ex += @attacker.sea_value #since ships are removed after bombardment
			end
			return ex
		end
	end
	def expected_defending_army_value
		if @defender.size == 0
			return 0
		elsif @attacker.size == 0
			return @defender.value
		else
			(@possibilities.inject(0) {|ev,battle| ev + battle.weight*battle.expected_defending_army_value}) * @normalize
		end	
	end
	
	def expected_IPC_loss_attacker
		@attacker.value - self.expected_attacking_army_value
	end
	def expected_IPC_loss_defender
		@defender.value - self.expected_defending_army_value
	end
end

class BattleCalc
	def initialize
		@root = TkRoot.new() {title 'Battle Calculator'}

		TkLabel.new(@root, 'text'=>"AA gun").grid('column'=>0,'row'=>0, 'sticky'=>'w')
		@aaGun = TkCheckButton.new(@root).grid('column'=>1,'row'=> 0, 'sticky'=>'w', 'padx'=>5)
		TkLabel.new(@root, 'text'=>"Hv. Bombers").grid('column'=>2,'row'=>0, 'sticky'=>'w')
		@heavyBombers = TkCheckButton.new(@root).grid('column'=>3,'row'=> 0, 'sticky'=>'w', 'padx'=>5)
		TkLabel.new(@root, 'text'=>"Comb. Bom.").grid('column'=>0,'row'=>1, 'sticky'=>'w')
		@combinedBombardment = TkCheckButton.new(@root).grid('column'=>1,'row'=> 1, 'sticky'=>'w', 'padx'=>5)
		TkLabel.new(@root, 'text'=>"Jets").grid('column'=>2,'row'=>1, 'sticky'=>'w')
		@jets = TkCheckButton.new(@root).grid('column'=>3,'row'=> 1, 'sticky'=>'w', 'padx'=>5)
		TkLabel.new(@root, 'text'=>"Super Subs").grid('column'=>0,'row'=>2, 'sticky'=>'w')
		@superSubs = TkCheckButton.new(@root).grid('column'=>1,'row'=> 2, 'sticky'=>'w', 'padx'=>5)


		unitStartRow = 4
		TkLabel.new(@root, 'text'=>"Attacker").grid('column'=>0,'row'=>unitStartRow - 1, 'sticky'=>'w')
		TkLabel.new(@root, 'text'=>"Defender").grid('column'=>2,'row'=>unitStartRow - 1, 'sticky'=>'w')		
		alabels = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
			TkLabel.new(@root, 'text'=>label)}
		dlabels = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
			TkLabel.new(@root, 'text'=>label)}
		alabels.each_index { |i| alabels[i].grid('column'=>0,'row'=>i + unitStartRow, 'sticky'=>'w')}
		dlabels.each_index { |i| dlabels[i].grid('column'=>2,'row'=>i + unitStartRow, 'sticky'=>'w')}
		num_units = (0..20).to_a
		@aunits = Array.new(10) {TkVariable.new()}
		aunitOptionMenus = Array.new(10) {|i| TkOptionMenubutton.new(@root, @aunits[i], *num_units) {width   1}.grid('column'=>1, 'row'=>i + unitStartRow,'sticky'=>'w', 'padx'=>5)}
		@dunits = Array.new(10) {TkVariable.new()}
		dunitOptionMenus = Array.new(10) {|i| TkOptionMenubutton.new(@root, @dunits[i], *num_units) {width   1}.grid('column'=>3, 'row'=>i + unitStartRow,'sticky'=>'w', 'padx'=>5)}
	
		calc = proc {self.doBattle}	
		TkButton.new(@root) {
			text    'Clalculate'
			command calc
		}.grid('column'=>1, 'row'=>10 + unitStartRow,'sticky'=>'w', 'padx'=>5)

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
	end
	def doBattle
		attackers = Array.new
		defenders = Array.new

		@aunits[0].to_i.times {attackers.push(Infantry.new)}
		@aunits[1].to_i.times {attackers.push(Tank.new)}
		@aunits[2].to_i.times {attackers.push(Artillery.new)}
		@aunits[3].to_i.times {attackers.push(Fighter.new)}
		@aunits[4].to_i.times {attackers.push(Bomber.new)}
		@aunits[5].to_i.times {attackers.push(Destroyer.new)}
		@aunits[6].to_i.times {attackers.push(Battleship.new)}
		@aunits[7].to_i.times {attackers.push(Carrier.new)}
		@aunits[8].to_i.times {attackers.push(Transport.new)}
		@aunits[9].to_i.times {attackers.push(Sub.new)}

		@dunits[0].to_i.times {defenders.push(Infantry.new)}
		@dunits[1].to_i.times {defenders.push(Tank.new)}
		@dunits[2].to_i.times {defenders.push(Artillery.new)}
		@dunits[3].to_i.times {defenders.push(Fighter.new)}
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
	end
end

BattleCalc.new
Tk.mainloop()