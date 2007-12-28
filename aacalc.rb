class song
	def initialize(infantry, tanks, artillery, fighters, bombers, destroyers, battleships, carriers, transports, subs)
		@infantry = infantry
		@tanks = tanks
		@artillery = artillery
		@fighters = fighters
		@bombers = bombers
		@destroyers = destroyers
		@battleships = battleships
		@carriers = carriers
		@transports = transports
		@subs = subs
	end
	def dup
		self.new(@infantry, @tanks, @artillery, @fighters, @bombers, @destroyers, @battleships, @carriers, @transports, @subs)
	end
	def value
		@infantry*3 + @tanks*5 + @artillery*4 + @fighters*10 + @bombers*15 + @destroyers*12 + @battleships*24 + @carriers*16 + @transports*8 + @subs*8
	end
	def probability(hits)
		return 1
	end
end