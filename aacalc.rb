class Army

protected

	attr_reader :infantry, :tanks, :artillery, :fighters, :bombers, :destroyers, :battleships, :hit_battleships, :carriers, :transports, :subs
	attr_writer :infantry, :tanks, :artillery, :fighters, :bombers, :destroyers, :battleships, :hit_battleships, :carriers, :transports, :subs

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
		@attack = attack
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
				else
					puts "argh"
				end
			end
		end
		return self
	end
	
	def probability(hits)
		if hits == 0
			prob = 1
			if @attack #TODO: take Artillery in to account
				prob = prob * (1 - (1/6.0))**@infantry
			else
				prob = prob * (1 - (2/6.0))**@infantry
			end
			prob = prob * (1 - (2/6.0))**@artillery
			prob = prob * (1 - (3/6.0))**@tanks
			if @attack
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
		elsif hits > self.size #includes size == 0 case since hits!=0 or above would have take care of it
			return 0
		else
			prob = 0
			if @infantry > 0 #TODO: take Artillery in to account
				temparmy = self.dup
				temparmy.infantry = temparmy.infantry - 1
				if @attack
					prob = prob + (@infantry/self.size.to_f) * (1/6.0) * temparmy.probability(hits - 1)
					prob = prob + (@infantry/self.size.to_f) * (1 - (1/6.0)) * temparmy.probability(hits)
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
			if @fighters > 0
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