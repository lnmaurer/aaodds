#!/usr/bin/ruby

# aaodds -- An odds calculator for Axis and Allies
#Copyright (C) 2011  Leon N. Maurer

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#version 2 as published by the Free Software Foundation;

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#A copy of the license is available at 
#<http://www.gnu.org/licenses/old-licenses/gpl-2.0.html>
#You can also receive a paper copy by writing the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require_relative 'aaodds_lib'
require 'rubygems'
require 'haml'
require 'sinatra'

#the key to the following three hashes will be the object_id of the thread
#used for a particular battle
$battleDetails = Hash.new #will store the results of each battle
$calcThreads = Hash.new #stores the threades used to calculate each battle
$output = Hash.new('') #will hold the output made during calculation -- starts off with an empty string

#the new print function just stores the output in a string for the appropriate battle
alias oldprint print
def print(s)
  $output[Thread.current.object_id] += s
end

#make a thread to delete old battles
$cleanUp = Thread.new do
  while true
    if $battleDetails.size > 500 #keep 500 old battles in memory
      #sort by age and select the oldest
      delete_id = $battleDetails.sort{|a,b| a[1][:TimeComplete] <=> b[1][:TimeComplete]}[0][0]
      #delete all references to the old battle
      $calcThreads.delete(delete_id)
      $battleDetails.delete(delete_id)
      $output.delete(delete_id)
    else
      #if there weren't too many battles, take a break before looking again.
      Kernel.sleep(60)
    end
  end
end

#the index page
get '/' do
  haml :index
end

#after a battle is entered on the index page, we post the details here, where we start the calculation
post '/result' do
  #make a thread to handle the calculation so that we can do more than one at once
  calcThread = Thread.new do
    start = Time.now #keep track of start time
    
    aunits = Array.new
    dunits = Array.new
    attackers = Array.new
    defenders = Array.new
    
    #read the attachers from parameters and go to the error page if the input isn't good
    #attackers is an array of the form [[#units, unit type],...]
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

    #read the defenders from parameters and go to the error page if the input isn't good
    #defenders is an array of the form [[#units, unit type],...]
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
    
    #look at the checkbox parameters
    aaGun = (params[:AAGun] != nil)
    heavyBombers = (params[:HeavyBombers] != nil)
    combinedBombardment = (params[:CombinedBombardment] != nil)
    jets = (params[:Jets] != nil)
    superSubs = (params[:SuperSubs] != nil)

    #now, take attckers and defenders arrays and push them in to arrays of units
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

    has_land = (aunits + dunits).any?{|u| u.type == :land}
    has_sea = (aunits + dunits).any?{|u| u.type == :sea}

    #is a bombardment going to happen? Assume it will if there are both land and sea attacking units
    bombarders = nil
    if has_land and has_sea #then there's a bombardment coming
      bombarders = Army.new(aunits.select{|u| u.type == :sea})
      oldaunits = aunits #don't want to permantly remove ships -- just need to seperate them for computations
      aunits = aunits.reject{|u| u.type == :sea}
    end

    #make the armies from the unit arrays; note that we really want the array's order reduced
    attackingArmy = Army.new(aunits.reverse)
    defendingArmy = Army.new(dunits.reverse)
    #if there are aaguns, then that can screw up the loss order, so we need multiple battles to handle them
    numaircraft = attackingArmy.num_aircraft
    battles = Array.new
    if aaGun and (numaircraft > 0) #we have to deal with other battles
      battles << Battle.new(attackingArmy, defendingArmy, bombarders, binom(numaircraft,0,1.0/6.0))
      a = attackingArmy.dup #so we can remove air units but not screw up attackingArmy
      #find where the aircraft are in the array
      aircraftindexes = Array.new
      a.arr.each_with_index{|u,i| aircraftindexes << i if u.type == :air}
      numaircraft.times do |i|
	hits = i + 1
	a = a.lose_one(:air)
	battles << Battle.new(a, defendingArmy, bombarders, binom(numaircraft,hits,1.0/6.0))
	end
    else #only one battle to worry about
      battles << Battle.new(attackingArmy, defendingArmy, bombarders)
    end
    #find the probabilities for winning. Can just add up multiple battles since they're already appropriately weighted
    pawins = battles.inject(0){|s,b|s + b.awins}
    pdwins = battles.inject(0){|s,b|s + b.dwins}
    pnwins = battles.inject(0){|s,b|s + b.nwins}
    pswins = pawins + pdwins + pnwins
  
    #now, find cumulative probabilities

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
    print "Battle calculated in #{Time.now.to_f - start.to_f} seconds\n"

    battle_details = Hash.new
    battle_details[:SummaryOfOdds] = {:AttackerWins=>pawins,
				      :DefenderWins=>pdwins,
                                      :MutualAnnihilation=>pnwins,
                                      :Sum=>pswins}
    battle_details[:Technologies] = {:AAguns=> aaGun,
				     :HeavyBombers=> heavyBombers,
                                     :CombinedBombardment=>combinedBombardment,
                                     :Jets => jets,
				     :SuperSubs => superSubs}
    battle_details[:Bomardment] = (bombarders != nil)
    battle_details[:Bombarders] = bombarders.arr.collect{|u| u.class.to_s + ' '} if bombarders != nil
    battle_details[:DefendingUnitsAndOdds] = defendingArmy.arr.collect{|u| u.class.to_s + ' '}.zip(dcumprobs)
    battle_details[:AttackingUnitsAndOdds] = attackingArmy.arr.collect{|u| u.class.to_s + ' '}.zip(acumprobs)
    battle_details[:TimeStarted] = start
    battle_details[:TimeComplete] = Time.now
    battle_details[:Attackers] = params[:attackers]
    battle_details[:Defenders] = params[:defenders]
    $battleDetails[Thread.current.object_id] = battle_details
  end
  $calcThreads[calcThread.object_id] = calcThread
  redirect "/results/#{calcThread.object_id}"
end


get '/results/:thread_id' do
  @thread_id = params[:thread_id].to_i
  if not $calcThreads.has_key?(@thread_id)
    redirect "/battlenotfound"
  elsif $calcThreads[@thread_id].status
    haml :calculating
  elsif $calcThreads[@thread_id].status == nil #the calc thread ran in to an error
    redirect "/calcthreaderror"
  else #if the status is false, that means it has completed sucessfully
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

get '/calcthreaderror' do
  haml <<'error'
%html{:xmlns => "http://www.w3.org/1999/xhtml", "xml:lang" => "en", :lang => "en"}
  %head
    %meta{"http-equiv" => "Content-type", :content =>" text/html;charset=UTF-8"}
    %title Calculation Error
  %body
    %h1 There has been an error during calculation.
    %p
      This is probably a problem with my program. You can try running the battle again from the main page, but feel free to contact me if this error persists.
    %p
      %a{:href=>"&#109;&#97;&#105;&#108;&#116;&#111;&#58;&#108;&#101;&#111;&#110;&#46;&#109;&#97;&#117;&#114;&#101;&#114;&#64;&#103;&#109;&#97;&#105;&#108;&#46;&#99;&#111;&#109;"}
        Email me
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter
error
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
    %p The Summary Of Odds shows the probabilities of the overall outcomes. In this setting, the attacker or defender wins if they have at least one unit survive the battle. Mutual annihilation means that no units survive the battle (this is technically a win for the defender). The sum of these three should be exactly 1.0. However, rounding errors may produce results like "1.00000000000003". This is normal result of using floating point numbers (which cannot exactly express numbers like one third). If you get a result that differs from 1.0 by a more significant extent, feel free to send the information about the battle to me so that I can look in to it.
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
    %title aaodds
  %body
    %div{:style=>"float:left;margin:4px;"}
      %img{:src => "aaodds192.png",:height=>"192",:width=>"192",:alt=>"Logo"}
    %h1='aaodds'
    %p
      This web application calculates the exact odds for battles in the revised edition of the board game Axis and Allies -- it does not estimate the results using randomness. All rules are implemented except special submarine rules (first strike, cannot attack aircraft).
    %p
      %strong
        Instructions:
      enter information, click 'Calculate', and wait. If you enter a nonsensical battle, you may get a nonsensical result. If you include both land and sea units in an attack, then the sea units will bombard. The order units are lost in can effect the odds in the battle. Units entered further to the left will be lost first. Battleships will always take their first hit before other units are hit.
    %p
      Units are entered by number then type (e.g. "3 infantry 2 artillery 5 tanks"). Any space free character sequence starting with 'i' will work for infantry (for example, 'i', 'inf', 'infantry', and 'iOMG' will all work -- 'i n f' will not). Similarly, 'ar' for artillery, 'ta' for tank, 'f' for fighter, 'bo' for bomber, 'd' for destroyer, 'ba' or 'bs' for battleship, 'ai' or 'ac' or 'c' for the aircraft carrier, and 's' for submarines. The case of the letters does not matter.
    %p
      An offline version of this program exists. Its interface is nicer, and the program may run faster (since this application is being hosted by a slow computer). Here are some links for more information:
    %ul
      %li
        The
        %a{:href=>"https://github.com/lnmaurer/aaodds"}home page
        for development of this program. The source code is available under the GPL.
      %li
        My general
        %a{:href=>"https://mywebspace.wisc.edu/lnmaurer/web/"}home page.
        It has my contact information.
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
    %a{:href=>"../"}
      Main Page
    %h1='Results'
    %p
      %a{:href=>"/whatitmean"} What does all this mean?
    %h2='Summary Of Odds'
    %p
      Attacker wins: #{$battleDetails[@thread_id][:SummaryOfOdds][:AttackerWins]}
      %br
      Defender wins: #{$battleDetails[@thread_id][:SummaryOfOdds][:DefenderWins]}
      %br
      Mutual annihilation: #{$battleDetails[@thread_id][:SummaryOfOdds][:MutualAnnihilation]}
      %br
      Sum: #{$battleDetails[@thread_id][:SummaryOfOdds][:Sum]}
    %h2='Tech'
    %ul
      - $battleDetails[@thread_id][:Technologies].each_pair do |key,value|
        %li #{key}: #{value}
    - if $battleDetails[@thread_id][:Bomardment]
      %h2='Bombarders'
      %ul
        - $battleDetails[@thread_id][:Bombarders].each do |s|
          %li=s
    %h2='Attacking units and odds'
    %ul
      - $battleDetails[@thread_id][:AttackingUnitsAndOdds].each do |s|
        %li=s
    %h2='Defending units and odds'
    %ul
      - $battleDetails[@thread_id][:DefendingUnitsAndOdds].each do |s|
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
          Attackers: #{$battleDetails[thread_id][:Attackers]},
          Defenders: #{$battleDetails[thread_id][:Defenders]},
          Completed: #{$battleDetails[thread_id][:TimeComplete]}
    %p
      %a{:href=>"../"}
        Main Page
    %p
      %a{:href=>"http://validator.w3.org/check?uri=referer"}
        %img{:src => "http://www.w3.org/Icons/valid-xhtml10-blue",:alt=>"Valid XHTML 1.0 Strict",:height=>"31",:width=>"88",:style=>"border-style:none"}
    / Site Meter XHTML Strict 1.0
    %script{:type => 'text/javascript', :src=> 'http://s27.sitemeter.com/js/counter.js?site=s27webap'}
    / Copyright (c)2006 Site Meter