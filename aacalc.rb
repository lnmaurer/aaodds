class Army

protected

	attr_reader :infantry, :tanks, :artillery, :fighters, :bombers, :destroyers, :battleships, :hit_battleships, :carriers, :transports, :subs, :pairs
	attr_writer :infantry, :tanks, :artillery, :fighters, :bombers, :destroyers, :battleships, :hit_battleships, :carriers, :transports, :subs, :pairs

public

	def initialize(attack, infantry, tanks, artillery, fighters, bombers, destroyers, battleships, hit_battleships, carriers, transports, subs)
		@infantry = infantry
		@tanks = tanks
		@artillery = artillery
		@fighters = fighters
		@bombers = bombers
		@destroyers = destroyers
		@battleships = battleships
		@hit_battleships = hit_battleships
		@carriers = carriers
		@transports = transports
		@subs = subs
		@attack = attack #true or false
		if @infantry > @artillery
			@pairs = @artillery
		else
			@pairs = @infantry
		end
	end
	
	def dup
		Army.new(@attack, @infantry, @tanks, @artillery, @fighters, @bombers, @destroyers, @battleships, @hit_battleships, @carriers, @transports, @subs)
	end
	
	def value
		@infantry*3 + @tanks*5 + @artillery*4 + @fighters*10 + @bombers*15 + @destroyers*12 + (@battleships + @hit_battleships)*24 + @carriers*16 + @transports*8 + @subs*8
	end
	
	def size
		@infantry + @tanks + @artillery + @fighters + @bombers + @destroyers + @battleships + @hit_battleships + @carriers + @transports + @subs
	end
	
	def max_hits
		self.size #TODO: modify for heavy bombers
	end
	
	def num_aircraft
		@fighters + @bombers
	end
	
	def can_bombard #TODO: modify for combined bombardment
		if @battleships > 0
			return true
		else
			return false
		end
	end
	
	def max_bombard_hits
		@battleships
	end
	
	def lose(hits)
		if self.size <= hits
			@infantry = 0
			@tanks = 0
			@artillery = 0
			@fighters = 0
			@bombers = 0
			@destroyers = 0
			@battleships = 0
			@hit_battleships = 0
			@carriers = 0
			@transports = 0
			@subs = 0
		else	
			hits.times do
				if @battleships > 0
					@battleships = @battleship - 1
					@hit_battleships = @hit_battleships + 1
				elsif @infantry > 0
					@infantry = @infantry - 1
				elsif @artillery > 0
					@artillery = @artillery - 1
				elsif @tanks > 0
					@tanks = @tanks - 1
				elsif @transports > 0
					@transports = @transports - 1
				elsif @subs > 0
					@subs = @subs - 1
				elsif @fighters > 0
					@fighters = @fighters - 1
				elsif @destroyers > 0
					@destroyers = @destroyers - 1
				elsif @bombers > 0
					@bombers = @bombers - 1
				elsif @carriers > 0
					@carriers = @carriers -1
				elsif @hit_battleships > 0
					@hit_battleships = @hit_battleships -1
				end
			end
		end
		self
	end
	
	def lose_aircraft(hits)
		if self.num_aircraft <= hits
			@fighters = 0
			@bombers = 0
		else
			hits.times do
				if @fighters > 0
					@fighters = @fighters - 1
				else
					@bombers = @bombers - 1
				end
			end
		end
	end
	
	def bombard_probability(hits) #TODO: Special rule for combined bombardment
		if hits > @battleships
			return 0
		elsif hits == 0
			return (1-(4/6.0))**@battleships
		else
			return ((1-(4/6.0))**hits) * ((4/6.0)**(@battleships - hits))
		end	
	end
	
	def probability(hits)
		if hits <= 0
			prob = 1
			
			if @attack
				prob = prob * (1 - (2/6.0))**@pairs
				prob = prob * (1 - (1/6.0))**(@infantry - @pairs)
			else
				prob = prob * (1 - (2/6.0))**@infantry
			end
			prob = prob * (1 - (2/6.0))**@artillery
			prob = prob * (1 - (3/6.0))**@tanks
			if @attack#TODO: special rule for jet fighters
				prob = prob * (1 - (3/6.0))**@fighters
			else
				prob = prob * (1 - (4/6.0))**@fighters
			end
			if @attack #TODO: special rule for heavy bomber
				prob = prob * (1 - (4/6.0))**@bombers
			else
				prob = prob * (1 - (1/6.0))**@bombers
			end
			prob = prob * (1 - (3/6.0))**@destroyers
			prob = prob * (1 - (4/6.0))**(@battleships + @hit_battleships)
			if @attack
				prob = prob * (1 - (1/6.0))**@carriers
			else
				prob = prob * (1 - (3/6.0))**@carriers
			end
			if ! @attack
				prob = prob * (1 - (1/6.0))**@transports
			end
			prob = prob * (1 - (2/6.0))**@subs #TODO: special rule for subs
		#TODO: modify 'hits > self.size' case for special rules like heavy bombers
		elsif hits > self.max_hits #includes size == 0 case since hits!=0 or above would have take care of it
			return 0
		else
			prob = 0

			if@infantry > 0 #TODO: take Artillery in to account
				temparmy = self.dup
				temparmy.infantry = temparmy.infantry - 1
				if @attack
					if pairs > 0
						temparmy.pairs = temparmy.pairs - 1
						prob = prob + (@infantry/self.size.to_f) * (2/6.0) * temparmy.probability(hits - 1)
						prob = prob + (@infantry/self.size.to_f) * (2 - (1/6.0)) * temparmy.probability(hits)
					else
						prob = prob + (@infantry/self.size.to_f) * (1/6.0) * temparmy.probability(hits - 1)
						prob = prob + (@infantry/self.size.to_f) * (1 - (1/6.0)) * temparmy.probability(hits)										
					end
				else
					prob = prob + (@infantry/self.size.to_f) * (2/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@infantry/self.size.to_f) * (1 - (2/6.0)) * temparmy.probability(hits)
				end
			end
			if @artillery > 0
				temparmy = self.dup
				temparmy.artillery = temparmy.artillery - 1
				prob = prob + (@artillery/self.size.to_f) * (2/6.0) * temparmy.probability(hits - 1)				
				prob = prob + (@artillery/self.size.to_f) * (1 - (2/6.0)) * temparmy.probability(hits)				
			end			

			if @tanks > 0
				temparmy = self.dup
				temparmy.tanks = temparmy.tanks - 1
				prob = prob + (@tanks/self.size.to_f) * (3/6.0) * temparmy.probability(hits - 1)				
				prob = prob + (@tanks/self.size.to_f) * (1 - (3/6.0)) * temparmy.probability(hits)	
			end			
			if @fighters > 0 #TODO: special rule for jet fighters
				temparmy = self.dup
				temparmy.fighters = temparmy.fighters - 1
				if @attack
					prob = prob + (@fighters/self.size.to_f) * (3/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@fighters/self.size.to_f) * (1 - (3/6.0)) * temparmy.probability(hits)
				else
					prob = prob + (@fighters/self.size.to_f) * (4/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@fighters/self.size.to_f) * (1 - (4/6.0)) * temparmy.probability(hits)
				end			
			end		
			if @bombers > 0 #TODO: special rule for heavy bombers
				temparmy = self.dup
				temparmy.bombers = temparmy.bombers - 1
				if @attack
					prob = prob + (@bombers/self.size.to_f) * (4/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@bombers/self.size.to_f) * (1 - (4/6.0)) * temparmy.probability(hits)
				else
					prob = prob + (@bombers/self.size.to_f) * (1/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@bombers/self.size.to_f) * (1 - (1/6.0)) * temparmy.probability(hits)
				end			
			end			
			if @destroyers > 0
				temparmy = self.dup
				temparmy.destroyers = temparmy.destroyers - 1
				prob = prob + (@destroyers/self.size.to_f) * (3/6.0) * temparmy.probability(hits - 1)
				prob = prob + (@destroyers/self.size.to_f) * (1 - (3/6.0)) * temparmy.probability(hits)		
			end				
			if (@battleships + @hit_battleships) > 0
				temparmy = self.dup
				if @battleships > 0
					temparmy.battleships = temparmy.battleships - 1
				else
					temparmy.hit_battleships = temparmy.hit_battleships - 1
				end
				prob = prob + ((@battleships + @hit_battleships)/self.size.to_f) * (4/6.0) * temparmy.probability(hits - 1)
				prob = prob + ((@battleships + @hit_battleships)/self.size.to_f) * (1 - (4/6.0)) * temparmy.probability(hits)		
			end	
			if @carriers > 0
				temparmy = self.dup
				temparmy.carriers = temparmy.carriers - 1
				if @attack
					prob = prob + (@carriers/self.size.to_f) * (1/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@carriers/self.size.to_f) * (1 - (1/6.0)) * temparmy.probability(hits)
				else
					prob = prob + (@carriers/self.size.to_f) * (3/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@carriers/self.size.to_f) * (1 - (3/6.0)) * temparmy.probability(hits)
				end			
			end		
			if @transports > 0
				temparmy = self.dup
				temparmy.transports = temparmy.transports - 1
				if @attack #TODO: simplify this case, something wrong with second prob = statement?
					prob = prob + (@transports/self.size.to_f) * (0/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@transports/self.size.to_f) * (1 - (0/6.0)) * temparmy.probability(hits)
				else
					prob = prob + (@transports/self.size.to_f) * (1/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@transports/self.size.to_f) * (1 - (1/6.0)) * temparmy.probability(hits)
				end			
			end	
			if @subs > 0 #TODO: impliment special rule for subs
				temparmy = self.dup
				temparmy.subs = temparmy.subs - 1
				prob = prob + (@subs/self.size.to_f) * (2/6.0) * temparmy.probability(hits - 1)
				prob = prob + (@subs/self.size.to_f) * (1 - (2/6.0)) * temparmy.probability(hits)	
			end	
			
		end
		return prob
	end
	
	def testprob
		prob = 0
		0.upto(self.size) do |x|
			prob = prob + self.probability(x)
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
				Battle.new(attacker.lose_ships,defender.lose(x),false, attacker.bombard_probability(x))
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
			@possibilities = @possibilities.reject {|item| item == nil} #get rid of the 'nil' item
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