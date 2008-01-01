class Unit
protected
	attr_writer :attack, :defend, :value, :can_bombard, :lives, :first_strike, :attacks, :aircraft
public
	attr_reader :attack, :defend, :value, :can_bombard, :lives, :first_strike, :attacks, :aircraft, :attacking
	attr_writer :attacking
	def initialize(attack, defend, value, can_bombard, lives, first_strike, attacks, aircraft, attacking = true)
		@attack = attack
		@defend = defend
		@value = value
		@can_bombard = can_bombard
		@lives = lives
		@first_strike = first_strike
		@attacks = attacks
		@aircraft = aircraft
		@attacking = attacking
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
		Unit.new(@attack, @defend, @value, @can_bombard, @lives, @first_strike, @attacks, @aircraft)
	end
	def take_hit
		@lives = @lives - 1
	end
end

class Infantry < Unit
	def initialize
		super(1,2,3,false,1,false,1,false)
	end
	def artillery_pair
		@attack = 2
	end
	def reset_pair
		@attack = 1
	end
	def dup #because we want to keep the Infantry type
		temp = Infantry.new
		temp.attack = @attack
		return temp
	end
end

class Tank < Unit
	def initialize
		super(3,3,5,false,1,false,1,false)
	end
	def dup
		Tank.new
	end
end

class Artillery < Unit
	def initialize
		super(2,2,4,false,1,false,1,false)
	end
	def dup #because we want to keep the Artillery type
		Artillery.new
	end
end

class Fighter < Unit
	def initialize(jet = false)
		if jet
			super(3,5,10,false,1,false,1,true)
		else
			super(3,4,10,false,1,false,1,true)
		end
	end
	def dup
		Fighter.new(@defence == 4 ? false : true)
	end
end

class Bomber < Unit
	def initialize(heavy = false)
		if heavy
			super(4,1,15,false,1,false,2,true)
		else
			super(4,1,15,false,1,false,1,true)
		end
	end
	def dup
		Bomber.new(@attacks == 1 ? false : true)
	end
end

class Destroyer < Unit
	def initialize(combined_bombardment = false)
		super(3,3,12,combined_bombardment,1,false,1,false)
	end
	def dup
		Destroyer.new(can_bombard)
	end
end

class Battleship < Unit
	def initialize
		super(4,4,24,true,2,false,1,false)
	end
	def dup
		Battleship.new
	end
end

class Carrier < Unit
	def initialize
		super(1,3,16,false,1,false,1,false)
	end
	def dup
		Carrier.new
	end
end

class Transport < Unit
	def initialize
		super(0,1,8,false,1,false,1,false)
	end
	def dup
		Transport.new
	end
end

class Sub < Unit
	def initialize(sup = false)
		if sup
			super(3,2,8,false,1,true,1,false)
		else
			super(2,2,8,false,1,true,1,false)
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

public
	def initialize(attacking,units = nil)
		@attacking = attacking
		if units == nil
			@units = Array.new
		else
			@units = Array.new(units.length){|x| units[x].dup}
			if !attacking
				@units.each{|unit| unit.attacking = false }
			else
				@units.each{|unit| unit.attacking = true }
				self.pair_infantry
			end
		end
	end
	
	def dup
		Army.new(@attacking,Array.new(@units.length){|x| @units[x].dup})
	end
	
	def value
		@units.inject(0){|value, unit| value + unit.value}
	end
	
	def size
		@units.length
	end
	
	def max_hits
		self.size #TODO: modify for heavy bombers
		#@units.inject(0){|num, unit| num + unit.attacks}
	end
	
	def num_aircraft
		@units.inject(0){|num, unit| num + (unit.aircraft ? 1 : 0)}
	end
	
	def can_bombard #TODO: modify for combined bombardment
		self.max_bombard_hits > 0
	end
	
	def max_bombard_hits
		@units.inject(0){|bombards, unit| bombards + (unit.can_bombard ? 1 : 0)}
	end
	
	def lose(hits)
		if self.size <= hits
			@units = Array.new
		else	
			hits.times do
				have_life = @units.find_all {|unit| unit.lives > 1}
				if have_life.length > 0
					have_life[0].lives = have_life[0].lives - 1 #should work since both have_life and @units have the _same_ objects
				elsif
					remove = @units.inject do |lowest,unit|
						if (unit.value < lowest.value) or ((unit.value == lowest.value) and (unit.power < lowest.power))
							lowest = unit
						end
					end
					@units.delete(remove)			
				end
			end
			self.pair_infantry
		end
		self
	end
	
	def lose_aircraft(hits)
		if self.num_aircraft <= hits
			@units.delete_if{|unit| unit.aircraft}
		else
			hits.times do
				remove = @units.inject do |lowest,unit|
					if unit.aircraft
						if (unit.value < lowest.value) or ((unit.value == lowest.value) and (unit.power < lowest.power))
							lowest = unit
						end
					end
				end
			end
		end
	end
	
	def bombard_probability(hits) #TODO: Special rule for combined bombardment
		bombarders = @units.find_all {|unit| unit.can_bombard}
		if hits > bombarders.length
			return 0
		elsif hits == 0
			return bombarders.inject(1){|prob,unit| prob * (1 - unit.prob)}
		else
			prob = 1
			1.upto(6) do |x|
				fleet = bombarders.find_all{|unit| unit.power == x}
				if fleet.length != 0
					tempfleet = Army.new(bombarders.reject{|unit| unit == fleet[0]})
					prob += (x/6.0)*(fleet.length/max_bombard_hits.to_f) * temp_fleet.bombard_probability(hits - 1)
					prob += (1 - (x/6.0))*(fleet.length/max_bombard_hits.to_f) * temp_fleet.bombard_probability(hits)
				end
			end
			return prob
		end	
	end
	
	def lose_bombard
		@units.delete_if{|unit| unit.can_bombard}
	end
	
	def probability(hits)
#puts "start", hits, self.max_hits, @units
		if hits > self.max_hits #includes size == 0 case since hits!=0 or above would have take care of it
			return 0
		elsif hits <= 0
			return @units.inject(1){|prob,unit| prob * (1 - unit.prob)}
		else
			prob = 0
			1.upto(6) do |x|
				group = @units.find_all{|unit| unit.power == x}
				if group.length != 0
					temparmy = Army.new(@attacking,@units.reject{|unit| unit == group[0]})
					prob += (x/6.0)*(group.length/max_hits.to_f) * temparmy.probability(hits - 1)
					prob += (1 - (x/6.0))*(group.length/max_hits.to_f) * temparmy.probability(hits)					
				end
			end
		end
		return prob
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
		@normalize = 1/(1 - @attacker.probability(0)*@defender.probability(0))
		
		if aagun
			@possibilities = Array.new(attacker.num_aircraft) do |x|
				Battle.new(attacker.lose_aircraft(x),defender,false, ((1/6.0)**x)*((5/6.0)**(possibilities.length - x)) )
			end
		elsif @attacker.can_bombard #TODO: make so bombardment only happens with amphibious
			@possibilities = Array.new(attacker.max_bombard_hits) do |x|
				Battle.new(attacker.lose_bombard,defender.lose(x),false, attacker.bombard_probability(x))
			end
		elsif (attacker.size != 0) and (defender.size != 0)
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

#the '/(1 - attacker.probability(0)*defender.probability(0))' in the next several functions account
#for the infinite recursion that could happen if both sides kept on not hitting each other
	

	def prob_attacker_wins
		if (@attacker.size != 0) and (@defender.size == 0)
			return 1
		elsif @attacker.size == 0
			return 0
		elsif (@attacker.size == 1) and (@defender.size == 1)
			return (@attacker.probability(1)*@defender.probability(0)) * @normalize
		else
			return (@possibilities.inject(0) {|prob, battle| prob + battle.weight*battle.prob_attacker_wins}) * @normalize
		end
	end
	
	def prob_defender_wins
		if (@attacker.size == 0) and (@defender.size != 0)
			return 1
		elsif @defender.size == 0
			return 0
		elsif (@attacker.size == 1) and (@defender.size == 1)
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
		elsif (@attacker.size == 1) and (@defender.size == 1)
			return (@attacker.probability(1)*@defender.probability(1)) * @normalize
		else
			return (@possibilities.inject(0) {|prob, battle| prob + battle.weight*battle.prob_mutual_annihilation}) * @normalize
		end
	end
	
	#TODO: add specail rules for bombardment for next four functions, since ships are removed from attacking army but not lost
	def expected_attacking_army_value
		if @attacker.size == 0
			return 0
		elsif @defender.size == 0
			return @attacker.value
		else
			(@possibilities.inject(0) {|ev,battle| ev + battle.weight*battle.expected_attacking_army_value}) * @normalize		
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