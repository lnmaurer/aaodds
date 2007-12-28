class Army
	def initialize(infantry, tanks, artillery, fighters, bombers, destroyers, battleships, hit_battleships, carriers, transports, subs)
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
	end
	
	def dup
		Army.new(@infantry, @tanks, @artillery, @fighters, @bombers, @destroyers, @battleships, @hit_battleships, @carriers, @transports, @subs)
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
		return 1
	end
end