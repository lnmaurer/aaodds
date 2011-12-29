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

#the key to the following three hashes will be the object_id of the thread
#used for a particular battle
$battleDetails = Hash.new #will store the results of each battle
$calcThreads = Hash.new #stores the threades used to calculate each battle
$output = Hash.new('') #will hold the output made during calculation -- starts off with an empty string

#the new print function just stores the output in a string for the appropriate battle
alias oldprint print
def print(s)
  $output[Thread.current.object_id] += s
#  oldprint s
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
    (1..num).inject(1){|product,n| product * n}
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
    super(1,2,3,:land,a)
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
    super(3,3,5,:land,a)
  end
  def dup
    Tank.new(@attacking)
  end
end

class Artillery < Unit
  def initialize(a)
    super(2,2,4,:land,a)
  end
  def dup
    Artillery.new(@attacking)
  end
end

class Fighter < Unit
  def initialize(a,jet=false)
    if jet
      super(3,5,10,:air,a)
    else
      super(3,4,10,:air,a)
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
    super(4,1,15,:air,a)
  end
  def dup
    Bomber.new(@attacking,@heavy)
  end
end

class Destroyer < Unit
  def initialize(a)
    super(3,3,12,:sea,a)
  end
  def dup
    Destroyer.new(@attacking)
  end
end

class Battleship < Unit
  def initialize(a)
    super(4,4,24,:sea,a)
  end
  def dup
    Battleship.new(@attacking)
  end
end

class Bship1stHit < Unit
  def initialize(a)
    super(0,0,0,:sea,a)
  end
  def dup
    Bship1stHit.new(@attacking)
  end
end

class Carrier < Unit
  def initialize(a)
    super(1,3,16,:sea,a)
  end
  def dup
    Carrier.new(@attacking)
  end
end

class Transport < Unit
  def initialize(a)
    super(0,1,8,:sea,a)
  end
  def dup
    Transport.new(@attacking)
  end
end

class Sub < Unit
  def initialize(a,sup = false)
    if sup
      super(3,2,8,:sea,a)
    else
      super(2,2,8,:sea,a)
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
  def dup_arr
    @arr.collect{|unit| unit.dup}
  end
  def dup
    Army.new(self.dup_arr)
  end
  def lose_one(type = nil)
    narr = self.dup_arr
    if type == nil
      narr.pop
    else
      lost_one = false
      narr = self.dup_arr.reverse
      narr = narr.reject{|unit| unit.type == type && ! lost_one ? lost_one = true : false}
      Army.new(narr.reverse)
    end
    Army.new(narr)
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
    @arr.any?{|unit| unit.type == :air}
  end
  def num_aircraft
    @arr.inject(0){|s,u|s + (u.type == :air).to_i}
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
  
  aunits = Array.new
  dunits = Array.new
  attackers = Array.new
  defenders = Array.new
  
  params[:attackers].split.each_with_index{|s,i|
    if (i % 2 ) == 0 #should be a number
      attackers << Array.new
      redirect "/inputerror/nan/#{params[:attackers].gsub(/\s+/,'_')}/#{s}" unless /\A\d+\z/ === s
      attackers[i/2] << s.to_i
    else #should be a unit
      redirect "/inputerror/ian/#{params[:attackers].gsub(/\s+/,'_')}/#{s}" if /\A\d+\z/ === s
      attackers[i/2] << s
    end
  }
  redirect "/inputerror/wn/#{params[:attackers].gsub(/\s+/,'_')}/nil" if attackers[-1].size == 1

  params[:defenders].split.each_with_index{|s,i|
    if (i % 2 ) == 0 #should be a number
      defenders << Array.new
      redirect "/inputerror/nan/#{params[:defenders].gsub(/\s+/,'_')}/#{s}" unless /\A\d+\z/ === s
      defenders[i/2] << s.to_i
    else #should be a unit
      redirect "/inputerror/ian/#{params[:defenders].gsub(/\s+/,'_')}/#{s}" if /\A\d+\z/ === s
      defenders[i/2] << s
    end
  }
  redirect "/inputerror/wn/#{params[:defenders].gsub(/\s+/,'_')}/nil" if defenders[-1].size == 1  
  
  aaGun = (params[:AAGun] != nil)
  heavyBombers = (params[:HeavyBombers] != nil)
  combinedBombardment = (params[:CombinedBombardment] != nil)
  jets = (params[:Jets] != nil)
  superSubs = (params[:SuperSubs] != nil)
  
  attackers.each{|num,unit|
    case unit
    when /\A(i)/i
      num.times {aunits.push(Infantry.new(true))}
    when /\A(ar)/i
      num.times {aunits.push(Artillery.new(true))}
    when /\A(ta)/i
      num.times {aunits.push(Tank.new(true))}
    when /\A(f)/i
      num.times {aunits.push(Fighter.new(true,jets))}
    when /\A(bo)/i
      num.times {aunits.push(Bomber.new(true,heavyBombers))}
    when /\A(d)/i
      num.times {aunits.push(Destroyer.new(true))}
    when /\A(ba)/i, /\A(bs)/i
      num.times {aunits.push(Battleship.new(true))}
      num.times {aunits.push(Bship1stHit.new(true))}
    when /\A(ai)/i, /\A(ac)/i, /\A(c)/i
      num.times {aunits.push(Carrier.new(true))}
    when /\A(tr)/i
      num.times {aunits.push(Transport.new(true))}
    when /\A(s)/i
      num.times {aunits.push(Sub.new(true,superSubs))}
    else
      redirect "/inputerror/unit/#{params[:attackers].gsub(/\s+/,'_')}/#{unit}"
    end              
  }
  aunits = aunits.sort_by{|u| u.is_a?(Bship1stHit) ? 0 : 1}
puts aunits.size
  defenders.each{|num,unit|
    case unit
    when /\A(i)/i
      num.times {dunits.push(Infantry.new(false))}
    when /\A(ar)/i
      num.times {dunits.push(Artillery.new(false))}
    when /\A(ta)/i
      num.times {dunits.push(Tank.new(false))}
    when /\A(f)/i
      num.times {dunits.push(Fighter.new(false,jets))}
    when /\A(bo)/i
      num.times {dunits.push(Bomber.new(false,heavyBombers))}
    when /\A(d)/i
      num.times {dunits.push(Destroyer.new(false))}
    when /\A(ba)/i, /\A(bs)/i
      num.times {dunits.push(Battleship.new(false))}
      num.times {dunits.push(Bship1stHit.new(false))}
    when /\A(ai)/i, /\A(ac)/i, /\A(c)/i
      num.times {dunits.push(Carrier.new(false))}
    when /\A(tr)/i
      num.times {dunits.push(Transport.new(false))}
    when /\A(s)/i
      num.times {dunits.push(Sub.new(false,superSubs))}
    else
      redirect "/inputerror/unit/#{params[:defenders].gsub(/\s+/,'_')}/#{unit}"        
    end              
  }              
  
  dunits = dunits.sort_by{|u| u.is_a?(Bship1stHit) ? 0 : 1}
                
  calcThread = Thread.new{
  #CALCULATE
      
    start = Time.now.to_f 
  #  self.reset_console

    has_land = (aunits + dunits).any?{|u| u.type == :land}
    has_sea = (aunits + dunits).any?{|u| u.type == :sea}

    bombarders = nil
    if has_land and has_sea #then there's a bombardment coming
      bombarders = Army.new(aunits.select{|u| u.type == :sea})
      oldaunits = aunits #don't want to permantly remove ships -- just need to seperate them for computations
      aunits = aunits.reject{|u| u.type == :sea}
    end

    a = Army.new(aunits.reverse)
    d = Army.new(dunits.reverse)

    battles = Array.new
    a2 = a.dup
    numaircraft = aaGun ? a.num_aircraft : 0
    aircraftindexes = Array.new
    a2.arr.each_with_index{|u,i| aircraftindexes << i if u.type == :air}
    for hits in 0..numaircraft #exceutes even if numaircraft == 0
      battles << Battle.new(a2,d,bombarders, binom(numaircraft,hits,1.0/6.0))
      a2 = a2.lose_one(:air)
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
    
    battle_details = Hash.new
    battle_details['Summary of odds'] = {'Attacker wins'=>pawins,
      'Defender wins'=>pdwins,'Mutual annihilation'=>pnwins,'Sum'=>pawins+pdwins+pnwins}
    battle_details['Technologies'] = {'AAguns'=> aaGun,
      'Heavy Bombers'=> heavyBombers, 'Combined Bombardment'=>
      combinedBombardment,'Jets' => jets,
      'Super Subs' => superSubs}
    battle_details['Bomardment'] = (bombarders != nil)
    battle_details['Bombarders'] = bombarders.arr.collect{|u| u.class.to_s + ' '} if bombarders != nil
    battle_details['Attacking units and odds'] = a.arr.collect{|u| u.class.to_s + ' '}.zip(acumprobs)
    battle_details['Defending units and odds'] = d.arr.collect{|u| u.class.to_s + ' '}.zip(dcumprobs)
    battle_details['Time Complete'] = Time.now
    battle_details['Attackers'] = params[:attackers]
    battle_details['Defenders'] = params[:defenders]
    $battleDetails[calcThread.object_id] = battle_details
  }
  $calcThreads[calcThread.object_id] = calcThread
  
  
  unless defined?($cleanUp)
    $cleanUp = Thread.new{
      while true
        if $battleDetails.size > 500 #keep 500 old battles in memory
          #sort by age and select the oldest
          delete_id = $battleDetails.sort{|a,b| a[1]['Time Complete'] <=> b[1]['Time Complete']}[0][0]
          #delete all references to the old battle
          $calcThreads.delete(delete_id)
          $battleDetails.delete(delete_id)
          $output.delete(delete_id)
        else
          #if there weren't too many battles, take a break before looking again.
          Kernel.sleep(60)
        end
      end
      }
  end
#  filename = Tk.getSaveFile("filetypes"=>[["Text", ".txt"]])
#  File.open(filename, "w"){|file| file.print(battle_details.to_yaml)} unless filename == ""  
  
  #results to be displayed
#  haml :results
#  battle_details.to_yaml
#  $res = battle_details.to_yaml.sub(/($|\n|\r)/,'<br />')
#  puts $res
  redirect "/results/#{calcThread.object_id}"
end


get '/results/:thread_id' do
  @thread_id = params[:thread_id].to_i
  if not $calcThreads.has_key?(@thread_id)
    redirect "/battlenotfound"
  elsif $calcThreads[@thread_id].status
    haml :calculating
  else
    haml :results
  end
end

get '/calculated' do
  haml :calculated
end

get '/inputerror/:type/:input/:error' do
  case params[:type]
    when 'unit'  
      text = 'There was a problem with your input. The text in bold and italics is not a recognized unit type.'
    when 'nan'
      text = 'There was a problem with your input. Something other than a number was given when a number was expected. The text in bold and italics may help identify the problem.'
    when 'ian'
      text = 'There was a problem with your input. A number was given instead of a unit type. The text in bold and italics may help identify the problem.'
    when 'wn' 
      text = 'There was a problem with your input. An even number of arguments was expected, but an odd number was received. Perhaps you forgot a number or unit type.'
  end
  input = params[:input].gsub(/(_)/,' ')
  haml <<inputerror
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Input Error
  %body
    %h1 Input Error
    %p
      #{input.gsub(/(#{params[:error]})/i,'<em><strong>' + params[:error] + '</strong></em>')}
    %p
      #{text}
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter
inputerror
end

get '/battlenotfound' do
  haml <<'nobattle'
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Battle Not Found
  %body
    %h1 The battle you are looking for cannot be found
    %p
      Are you sure you entered the correct URL? If you are looking for an old battle, note that they may be deleted periodically.
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter
nobattle
end

get '/whatitmean' do
  haml <<'whatitmean'
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title What it means
  %body
    %h1 What does it all mean?
    %p Probabilities are shown as numbers between 0 and 1.
    %p The "Summary of odds" shows the probabilities of the overall outcomes. In this setting, the attacker or defender wins if they have at least one unit survive the battle. Mutual annihilation means that no units survive the battle (this is technically a win for the defender). The sum of these three should be exactly 1.0. However, rounding errors may produce results like "1.00000000000003". This is normal result of using floating point numbers (which cannot exactly express numbers like one third). If you get a result that differs from 1.0 by a more significant extent, feel free to send the information about the battle to me so that I can look in to it.
    %p For the units and odds sections, the number to the right of a unit is the probability that that unit, and the ones above it, survive the battle.
    %p Note that the results of a battle will be available (from the previous page) for a while, but may eventually be deleted.
    %p Use your browser's back button to return to the battle results.
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter
whatitmean
end

__END__

@@ index
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title aacalc
  %body
    %div{:style=>"float:left;margin:4px;"}
      %img{:src => "aacalc192.png",:height=>"192",:width=>"192",:alt=>"Logo"}
    %h1='aacalc'
    %p
      This web application calculates the exact odds for battles in the revised edition of the board game Axis and Allies -- it does not estimate the results using randomness. All rules are implemented except special submarine rules (first strike, cannot attack aircraft).
    %p
      %strong
        Instructions:
      enter information, click 'Calculate', and wait. If you enter a nonsensical battle, you may get a nonsensical result. If you include both land and sea units in an attack, then the sea units will bombard. The order units are lost in can effect the odds in the battle. Units entered further to the left will be lost first. Battleships will always take their first hit before other units are hit.
    %p
      Units are entered by number then type (e.g. "3 infantry 2 artillery 5 tanks"). Any space free character sequence starting with 'i' will work for infantry (for example, 'i', 'inf', 'infantry', and 'iOMG' will all work -- 'i n f' will not). Similarly, 'ar' for artillery, 'ta' for tank, 'f' for fighter, 'bo' for bomber, 'd' for destroyer, 'ba' or 'bs' for battleship, 'ai' or 'ac' or 'c' for the aircraft carrier, and 's' for submarines. The case of the letters does not matter.
    %p
      An offline version of this program exists. Its interface is nicer, and the program will likely run faster (since this application is being hosted by a slow computer). Here are some links for more information:
    %ul
      %li
        The
        %a{:href=>"https://launchpad.net/aacalc"}home page
        for development of this program. The source code is available under the GPL.
      %li
        My general
        %a{:href=>"https://mywebspace.wisc.edu/lnmaurer/web/"}home page.
        It has my contact information.
      %li
        There is another similar program with the
        %a{:href=>"http://frood.net/aacalc/2.0/"}same name.
        It estimates battle outcomes using randomness. I have no relation to that project -- the name collision was unintentional.
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
              %input{:type =>'text', :size => '40', :name=>'attackers'}
          %td
            %h2='Defenders'
            %p
              %input{:type =>'text', :size => '40', :name=>'defenders'}
        %tr
          %td{:colspan=>"2"}
            %input{:type => :submit, :value => "Calculate"}
    %p
      A list of battles already calculated and currently stored in memory is available
      %a{:href=>"/calculated"}here.
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter

@@ results
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Battle Results
  %body
    %h1='Results'
    %p
      %a{:href=>"/whatitmean"} What does all this mean?
    %h2='Summary of odds'
    %p
      Attacker wins: #{$battleDetails[@thread_id]['Summary of odds']['Attacker wins']}
      %br
      Defender wins: #{$battleDetails[@thread_id]['Summary of odds']['Defender wins']}
      %br
      Mutual annihilation: #{$battleDetails[@thread_id]['Summary of odds']['Mutual annihilation']}
      %br
      Sum: #{$battleDetails[@thread_id]['Summary of odds']['Sum']}
    %h2='Tech'
    %ul
      - $battleDetails[@thread_id]['Technologies'].each_pair do |key,value|
        %li #{key}: #{value}
    - if $battleDetails[@thread_id]['Bomardment']
      %h2='Bombarders'
      %ul
        - $battleDetails[@thread_id]['Bombarders'].each do |s|
          %li=s
    %h2='Attacking units and odds'
    %ul
      - $battleDetails[@thread_id]['Attacking units and odds'].each do |s|
        %li=s
    %h2='Defending units and odds'
    %ul
      - $battleDetails[@thread_id]['Defending units and odds'].each do |s|
        %li=s
    %h2="Log"
    %p=$output[@thread_id].gsub(/\n/,'<br />')
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter

@@ calculating
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %meta{"http-equiv" => "refresh", :content=> "1"}
    %title Calculating
  %body
    %h1 Calculating
    %p=$output[@thread_id].gsub(/\n/,'<br />')
    
@@ calculated
!!! Strict
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Calculated Battles
  %body
    %h1='Calculated Battles'
    %ul
      - $calcThreads.reject{|thread_id,thread| thread.status}.each_key do |thread_id|
        %li
          %a{:href => "results/#{thread_id}"}#{thread_id},
          Attackers: #{$battleDetails[thread_id]['Attackers']},
          Defenders: #{$battleDetails[thread_id]['Defenders']},
          Completed: #{$battleDetails[thread_id]['Time Complete']}
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter