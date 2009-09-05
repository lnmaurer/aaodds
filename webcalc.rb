require 'rubygems'
require 'haml'
require 'sinatra'
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

$output =''
alias oldprint print
def print(s)
  $output = $output + s
  oldprint s
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
    @heavy = heavy and a #if it's not attacking, then it can't really be heavy
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
  def has_aircraft
    @arr.any?{|unit| unit.type == 'air'}
  end
  def num_aircraft
    @arr.inject(0){|s,u|s + (u.type == 'air').to_i}
  end
end


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
    @a = a
    @d = d
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
  def nwins
    #the probability that no one survives the battle is stored in the last place in the array
    @state[-1] * @weight
  end
  def tprob
    (awins + dwins + nwins) * @weight
  end
end


get '/' do
  haml :index
end

post '/result' do

  $calcThread = Thread.new{
    #Techs
    aaGun = (params[:AAGun] != nil)
    heavyBombers = (params[:HeavyBombers] != nil)
    combinedBombardment = (params[:CombinedBombardment] != nil)
    jets = (params[:Jets] != nil)
    superSubs = (params[:SuperSubs] != nil)
    
  #DEFENDERS  
    
  #   if @dlist.curselection.size != 0
  #     @dlist.selection_clear(@dlist.curselection[0])
  #   end
  #   self.disable_buttons(@dup,@ddown)
    dunits = Array.new
    params[:dInfantry].to_i.times {dunits.push(Infantry.new(false))}
    params[:dTank].to_i.times {dunits.push(Tank.new(false))}
    params[:dArtillery].to_i.times {dunits.push(Artillery.new(false))}
    params[:dFighter].to_i.times {dunits.push(Fighter.new(false,jets))}
    params[:dBomber].to_i.times {dunits.push(Bomber.new(false,heavyBombers))}
    params[:dDestroyer].to_i.times {dunits.push(Destroyer.new(false))}
    params[:dBattleship].to_i.times {dunits.push(Battleship.new(false))}
    params[:dBattleship].to_i.times {dunits.push(Bship1stHit.new(false))}
    params[:dCarrier].to_i.times {dunits.push(Carrier.new(false))}
    params[:dTransport].to_i.times {dunits.push(Transport.new(false))}
    params[:dSub].to_i.times {dunits.push(Sub.new(false,superSubs))}

  #   if @dsort.to_s == 'value'
  #     dunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
  #   else
  #     @dsort.value = 'power' #in case it's set to 'other'
      dunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
  #   end
  # 
  #   @dhas_land = dunits.any?{|unit| unit.type == 'land'}
  #   @dhas_sea = dunits.any?{|unit| unit.type == 'sea'}
  #   if @dhas_land or @ahas_land
  #     self.disable_sea
  #   else
  #     self.enable_sea
  #   end
  #   if @dhas_sea or @ahas_sea
  #     self.disable_land
  #   else
  #     self.enable_land
  #   end
  # 
  #   self.update_lists
    
      
  #ATTACKERS    
      
  #   if @alist.curselection.size != 0
  #     @alist.selection_clear(@alist.curselection[0])
  #   end
  #   self.disable_buttons(@aup,@adown)
    aunits = Array.new
    params[:aInfantry].to_i.times {aunits.push(Infantry.new(true))}
    params[:aTank].to_i.times {aunits.push(Tank.new(true))}
    params[:aArtillery].to_i.times {aunits.push(Artillery.new(true))}

  #   @ahas_land = aunits.any?{|unit| unit.type == 'land'}
  #   if @ahas_land or @dhas_land
  #     self.disable_sea
  #   else
  #     self.enable_sea
  #   end

    params[:aFighter].to_i.times {aunits.push(Fighter.new(true,jets))}
    params[:aBomber].to_i.times {aunits.push(Bomber.new(true,heavyBombers))}
    params[:aDestroyer].to_i.times {aunits.push(Destroyer.new(true))}
    params[:aBattleship].to_i.times {aunits.push(Battleship.new(true))}
    params[:aBattleship].to_i.times {aunits.push(Bship1stHit.new(true))}
    params[:aCarrier].to_i.times {aunits.push(Carrier.new(true))}
    params[:aTransport].to_i.times {aunits.push(Transport.new(true))}
    params[:aSub].to_i.times {aunits.push(Sub.new(true,superSubs))}

    #      aunits = aunits.reject{|unit| unit.is_a?(Bship1stHit)} if ahas_land #if there are land units, take out the first hit
  #   @ahas_sea = aunits.any?{|unit| (unit.type == 'sea') and (not(unit.is_a?(Battleship) or unit.is_a?(Bship1stHit) or (unit.is_a?(Destroyer) and (@combinedBombardment.get_value == '1'))))}
  #   if @ahas_sea or @dhas_sea
  #     self.disable_land
  #   else
  #     self.enable_land
  #   end
  # 
  #   if @asort.to_s == 'value'
  #     aunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
  #   else
  #     @asort.value ='power' #in case it's set to 'other'
      aunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
  #   end
  # 
  #   self.update_lists  
    
  #CALCULATE
      
    start = Time.now.to_f 
  #  self.reset_console

    has_land = (aunits + dunits).any?{|u| u.type == 'land'}
    has_sea = (aunits + dunits).any?{|u| u.type == 'sea'}

    bombarders = nil
    if has_land and has_sea #then there's a bombardment coming
      bombarders = Army.new(aunits.select{|u| u.type == 'sea'})
      oldaunits = aunits #don't want to permantly remove ships -- just need to seperate them for computations
      aunits = aunits.reject{|u| u.type == 'sea'}
    end

    a = Army.new(aunits.reverse)
    d = Army.new(dunits.reverse)

    battles = Array.new
    a2 = a.dup
    numaircraft = aaGun ? a.num_aircraft : 0
    aircraftindexes = Array.new
    a2.arr.each_with_index{|u,i| aircraftindexes << i if u.type == 'air'}
    for hits in 0..numaircraft #exceutes even if numaircraft == 0
      battles << Battle.new(a2,d,bombarders, binom(numaircraft,hits,1.0/6.0))
      a2 = a2.lose_one_aircraft
    end

    pawins = battles.inject(0){|s,b|s + b.awins}
    pdwins = battles.inject(0){|s,b|s + b.dwins}
    pnwins = battles.inject(0){|s,b|s + b.nwins}
    pswins = pawins + pdwins + pnwins
    #d doesn't lose any units from aaguns, so we can just add everything together
    dcumprobs = battles.collect{|b|b.dcumprobs}.inject{|s,a| s.zip(a).collect{|b,c|b+c}}
    #the same is not true for a, so this takes more work
    acumprobs = Array.new
    battles.each_with_index{|b,i|
      probs = b.acumprobs.reverse
      for j in 0..(i-1)
	probs.insert(aircraftindexes[j],0)
      end
      acumprobs << probs.reverse
    }
    acumprobs = acumprobs.inject{|s,a| s.zip(a).collect{|b,c|b+c}}

  #  attackerProb.value = pawins.to_s
  #  defenderProb.value = pdwins.to_s
  #  annihilationProb.value = pnwins.to_s
  #  sumProb.value = pswins.to_s
  #  aunits = oldaunits if has_land and has_sea
  #  anames.value = anames.list.collect{|s|s.split[0]}.zip(acumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}
  #  dnames.value = dnames.list.collect{|s|s.split[0]}.zip(dcumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}

    print "Operation completed in #{Time.now.to_f - start} seconds\n"

  #DISPLAY RESULTS  
    
    $battle_details = Hash.new
    $battle_details['Summary of odds'] = {'Attacker wins'=>pawins,
      'Defender wins'=>pdwins,'Mutual annihilation'=>pnwins,'Sum'=>pawins+pdwins+pnwins}
    $battle_details['Technologies'] = {'AAguns'=> aaGun,
      'Heavy Bombers'=> heavyBombers, 'Combined Bombardment'=>
      combinedBombardment,'Jets' => jets,
      'Super Subs' => superSubs}
    $battle_details['Bomardment'] = (bombarders != nil)
    $battle_details['Bombarders'] = bombarders.arr.collect{|u| u.class.to_s + ' '} if bombarders != nil
    $battle_details['Attacking units and odds'] = a.arr.collect{|u| u.class.to_s + ' '}.zip(acumprobs)
    $battle_details['Defending units and odds'] = d.arr.collect{|u| u.class.to_s + ' '}.zip(dcumprobs)
  }
#  filename = Tk.getSaveFile("filetypes"=>[["Text", ".txt"]])
#  File.open(filename, "w"){|file| file.print(battle_details.to_yaml)} unless filename == ""  
  
  #results to be displayed
#  haml :results
#  battle_details.to_yaml
#  $res = battle_details.to_yaml.sub(/($|\n|\r)/,'<br />')
#  puts $res
  redirect "/results"
end


get '/results' do
  if $calcThread.status
    haml :calculating
  else
    haml :results
  end
end
  
__END__

@@ index
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title aacalc
  %body
    %h1='aacalc'
    %p
      Instructions: enter information, click 'Calculate', and wait.
    %form{:method => 'post', :action => "/result"}
      %table
        %tr
          %td{:colspan=>"2"}
            %h2='Tech'
            %p
              AA Gun
              %input{:type =>'checkbox', :name=>'AAGun'}
              Heavy Bombers
              %input{:type =>'checkbox', :name=>'HeavyBombers'}
              Combined Bombardment
              %input{:type =>'checkbox', :name=>'CombinedBombardment'}
              Jets
              %input{:type =>'checkbox', :name=>'Jets'}
              Super Subs
              %input{:type =>'checkbox', :name=>'SuperSubs'}
        %tr
          %td
            %h2='Attackers'
            %p
              %input{:type =>'text', :size => '3', :name=>'aInfantry'}
              Infantry
              %br
              %input{:type =>'text', :size => '3', :name=>'aTank'}
              Tanks
              %br
              %input{:type =>'text', :size => '3', :name=>'aArtillery'}
              Artillery
              %br
              %input{:type =>'text', :size => '3', :name=>'aFighter'}
              Fighter
              %br
              %input{:type =>'text', :size => '3', :name=>'aBomber'}
              Bomber
              %br
              %input{:type =>'text', :size => '3', :name=>'aDestroyer'}
              Destroyer
              %br
              %input{:type =>'text', :size => '3', :name=>'aBattleship'}
              Battleship
              %br
              %input{:type =>'text', :size => '3', :name=>'aTransport'}
              Transport
              %br
              %input{:type =>'text', :size => '3', :name=>'aSubmarine'}
              Submarine
          %td
            %h2='Defenders'
            %p
              %input{:type =>'text', :size => '3', :name=>'dInfantry'}
              Infantry
              %br
              %input{:type =>'text', :size => '3', :name=>'dTank'}
              Tanks
              %br
              %input{:type =>'text', :size => '3', :name=>'dArtillery'}
              Artillery
              %br
              %input{:type =>'text', :size => '3', :name=>'dFighter'}
              Fighter
              %br
              %input{:type =>'text', :size => '3', :name=>'dBomber'}
              Bomber
              %br
              %input{:type =>'text', :size => '3', :name=>'dDestroyer'}
              Destroyer
              %br
              %input{:type =>'text', :size => '3', :name=>'dBattleship'}
              Battleship
              %br
              %input{:type =>'text', :size => '3', :name=>'dTransport'}
              Transport
              %br
              %input{:type =>'text', :size => '3', :name=>'dSubmarine'}
              Submarine
        %tr
          %td{:colspan=>"2"}
            %input{:type => :submit, :value => "Calculate"}
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88"}  

@@ results
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Battle Results
  %body
    %h1='Results'
    %h2='Summary of odds'
    %p
      Attacker wins: #{$battle_details['Summary of odds']['Attacker wins']}
      %br
      Defender wins: #{$battle_details['Summary of odds']['Defender wins']}
      %br
      Mutual annihilation: #{$battle_details['Summary of odds']['Mutual annihilation']}
      %br
      Sum: #{$battle_details['Summary of odds']['Sum']}
    %h2='Tech'
    %ul
      - $battle_details['Technologies'].each_pair do |key,value|
        %li #{key}: #{value}
    - if $battle_details['Bomardment']
      %h2='Bombarders'
      %ul
        - $battle_details['Bombarders'].each do |s|
          %li=s
    %h2='Attacking units and odds'
    %ul
      - $battle_details['Attacking units and odds'].each do |s|
        %li=s
    %h2='Defending units and odds'
    %ul
      - $battle_details['Defending units and odds'].each do |s|
        %li=s
    %h2="Log"
    %p=$output.gsub(/\n/,'<br />')
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88"}
@@ calculating
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %meta{"http-equiv" => "refresh", :content=> "1"}
    %title Calculating
  %body
    %h1='Calculating'
    %p=$output.gsub(/\n/,'<br />')
