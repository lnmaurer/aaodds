#!/usr/bin/ruby

# aacalc -- An odds calculator for Axis and Allies
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


require 'tkextlib/tile'
require 'yaml'
require 'aacalc_lib'

alias oldprint print
def print(s)
  $gui.print_to_console(s)
end

class BattleGUI
  def initialize
    @root = TkRoot.new(:title=>'Battle Calculator')
    tframe = TkLabelFrame.new(@root,:text=>'Technology').grid(:column=>0,:row=>0,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    aframe = TkLabelFrame.new(@root,:text=>'Attackers').grid(:column=>0,:row=>1,:padx=>5,:pady=>5)
    dframe = TkLabelFrame.new(@root,:text=>'Defenders').grid(:column=>1,:row=>1,:padx=>5,:pady=>5)
    cframe = TkLabelFrame.new(@root,:text=>'Controls').grid(:column=>0,:row=>2,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    consoleframe = TkLabelFrame.new(@root,:text=>'Console').grid(:column=>0,:row=>3,:columnspan=>2,:sticky=>'nsew',:padx=>5,:pady=>5)
    
    #console
    cyscroll = proc{|*args| @cscrollb.set(*args)}
    cscroll = proc{|*args| @console.yview(*args)}
    @console = TkText.new(consoleframe,:yscrollcommand=>cyscroll,:width=>80,:height=>10).grid(:column=>0,:row=>0,:padx=>5,:pady=>5)
    @cscrollb = TkScrollbar.new(consoleframe,:orient=>'vertical',:command=>cscroll).grid(:column=>1,:row=>0,:padx=>5,:sticky=>'ns')

    #attackers
    aclear = proc {
      @aunitsnums.each{|sbox| sbox.set("0")}
      @aupdate.call
    }
    @aunits = Array.new
    @aupdate = proc{
      if @alist.curselection.size != 0
        @alist.selection_clear(@alist.curselection[0])
      end
      self.disable_buttons(@aup,@adown)
      @aunits = Array.new
      @aunitsnums[0].get.to_i.times {@aunits.push(Infantry.new(true))}
      @aunitsnums[1].get.to_i.times {@aunits.push(Tank.new(true))}
      @aunitsnums[2].get.to_i.times {@aunits.push(Artillery.new(true))}

      @ahas_land = @aunits.any?{|unit| unit.type == :land}
      if @ahas_land or @dhas_land
        self.disable_sea
      else
        self.enable_sea
      end

      @aunitsnums[3].get.to_i.times {@aunits.push(Fighter.new(true,@jets.get_value == '1'))}
      @aunitsnums[4].get.to_i.times {@aunits.push(Bomber.new(true,@heavyBombers.get_value == '1'))}
      @aunitsnums[5].get.to_i.times {@aunits.push(Destroyer.new(true))}
      @aunitsnums[6].get.to_i.times {@aunits.push(Battleship.new(true))}
      @aunitsnums[6].get.to_i.times {@aunits.push(Bship1stHit.new(true))} unless @ahas_land or @dhas_land
      @aunitsnums[7].get.to_i.times {@aunits.push(Carrier.new(true))}
      @aunitsnums[8].get.to_i.times {@aunits.push(Transport.new(true))}
      @aunitsnums[9].get.to_i.times {@aunits.push(Sub.new(true,@superSubs.get_value == '1'))}
      
#      @aunits = @aunits.reject{|unit| unit.is_a?(Bship1stHit)} if ahas_land #if there are land units, take out the first hit
      @ahas_sea = @aunits.any?{|unit| (unit.type == :sea) and (not(unit.is_a?(Battleship) or unit.is_a?(Bship1stHit) or (unit.is_a?(Destroyer) and (@combinedBombardment.get_value == '1'))))}
      if @ahas_sea or @dhas_sea
        self.disable_land
      else
        self.enable_land
      end

      if @asort.to_s == 'value'
        @aunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @asort.value ='power' #in case it's set to 'other'
        @aunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end

      self.update_lists
    }
    row = -1
    @aunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(aframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
       sb = TkSpinbox.new(aframe,'to'=>100, 'from'=>0, 'width'=>3, 'command'=>@aupdate)
       sb.grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
       sb.bind('KeyRelease',@aupdate) #so that the units are updated if the number is typed directly in to the spinbox
    }
    TkLabel.new(aframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @asort = TkVariable.new
    @asort.set_value('power')
    TkRadioButton.new(aframe,'text'=>'Power','variable'=>@asort,'value'=>'power','command'=>@aupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Value','variable'=>@asort,'value'=>'value','command'=>@aupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(aframe,'text'=>'Other','variable'=>@asort,'value'=>'other','command'=>proc{self.enable_buttons(@aup,@adown)}).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    ayscroll = proc{|*args| @albscroll.set(*args)}
    ascroll = proc{|*args| @alist.yview(*args)}
    @anames = TkVariable.new
    @alist = TkListbox.new(aframe,'listvariable'=>@anames,'height' => 12,'yscrollcommand'=> ayscroll,:font=>'TkFixedFont').grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @alist.bind('<ListboxSelect>'){@asort.set_value('other');self.enable_buttons(@aup,@adown)}
    @albscroll = TkScrollbar.new(aframe,'orient'=>'vertical','command'=>ascroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @aup = TkButton.new(aframe,'text'=>'Up','command'=>proc {self.move_unit(@aunits,@alist,:up)}).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @adown = TkButton.new(aframe,'text'=>'Down','command'=>proc {self.move_unit(@aunits,@alist,:down)}).grid('column'=>3, 'row'=>9, 'padx'=>5)
    self.disable_buttons(@aup,@adown)
    TkButton.new(aframe,'text'=>'Clear','command'=>aclear).grid('column'=>2, 'row'=>10, 'padx'=>5)

    #defenders
    dclear = proc {
      @dunitsnums.each{|sbox| sbox.set("0")}
      @dupdate.call
    }
    @dunits = Array.new
    @dupdate = proc{
      if @dlist.curselection.size != 0
        @dlist.selection_clear(@dlist.curselection[0])
      end
      self.disable_buttons(@dup,@ddown)
      @dunits = Array.new
      @dunitsnums[0].get.to_i.times {@dunits.push(Infantry.new(false))}
      @dunitsnums[1].get.to_i.times {@dunits.push(Tank.new(false))}
      @dunitsnums[2].get.to_i.times {@dunits.push(Artillery.new(false))}
      @dunitsnums[3].get.to_i.times {@dunits.push(Fighter.new(false,@jets.get_value == '1'))}
      @dunitsnums[4].get.to_i.times {@dunits.push(Bomber.new(false,@heavyBombers.get_value == '1'))}
      @dunitsnums[5].get.to_i.times {@dunits.push(Destroyer.new(false))}
      @dunitsnums[6].get.to_i.times {@dunits.push(Battleship.new(false))}
      @dunitsnums[6].get.to_i.times {@dunits.push(Bship1stHit.new(false))}
      @dunitsnums[7].get.to_i.times {@dunits.push(Carrier.new(false))}
      @dunitsnums[8].get.to_i.times {@dunits.push(Transport.new(false))}
      @dunitsnums[9].get.to_i.times {@dunits.push(Sub.new(false,@superSubs.get_value == '1'))}
      
      if @dsort.to_s == 'value'
        @dunits.sort!{|a,b| (a.value <=> b.value) == 0 ? a.power <=> b.power : a.value <=> b.value}
      else
        @dsort.value = 'power' #in case it's set to 'other'
        @dunits.sort!{|a,b| (a.power <=> b.power) == 0 ? a.value <=> b.value : a.power <=> b.power}
      end

      @dhas_land = @dunits.any?{|unit| unit.type == :land}
      @dhas_sea = @dunits.any?{|unit| unit.type == :sea}
      if @dhas_land or @ahas_land
        self.disable_sea
      else
        self.enable_sea
      end
      if @dhas_sea or @ahas_sea
        self.disable_land
      else
        self.enable_land
      end

      self.update_lists
    }
    row = -1
    @dunitsnums = ['Infantry', 'Tank', 'Artillery', 'Fighter', 'Bomber','Destroyer','Battleship','Carrier','Transport','Sub'].collect { |label|
      TkLabel.new(dframe, 'text'=>label).grid('column'=>0,'row'=> (row +=1), 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      sb = TkSpinbox.new(dframe,'to'=>100, 'from'=>0, 'width'=>3,'command'=>@dupdate)
      sb.grid('column'=>1,'row'=> row, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
      sb.bind('KeyRelease',@dupdate) #so that the units are updated if the number is typed directly in to the spinbox
    }
    TkLabel.new(dframe,'text'=>"Sort by:").grid('column'=>2, 'row'=>0, 'padx'=>5, 'pady'=>5)
    @dsort = TkVariable.new
    @dsort.set_value('power')
    TkRadioButton.new(dframe,'text'=>'Power','variable'=>@dsort,'value'=>'power','command'=>@dupdate).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Value','variable'=>@dsort,'value'=>'value','command'=>@dupdate).grid('column'=>2, 'row'=>1, 'padx'=>5, 'pady'=>5)
    TkRadioButton.new(dframe,'text'=>'Other','variable'=>@dsort,'value'=>'other','command'=>proc{self.enable_buttons(@dup,@ddown)}).grid('column'=>3, 'row'=>1, 'padx'=>5, 'pady'=>5)
    dyscroll = proc{|*args| @dlbscroll.set(*args)}
    dscroll = proc{|*args| @dlist.yview(*args)}
    @dnames = TkVariable.new('')
    @dlist = TkListbox.new(dframe,'listvariable'=>@dnames,'height' => 12,'yscrollcommand'=> dyscroll,:font=>'TkFixedFont').grid('column'=>2, 'row'=>2,'rowspan'=>7,'columnspan'=>2, 'pady'=>5)
    @dlist.bind('<ListboxSelect>'){@dsort.set_value('other');self.enable_buttons(@dup,@ddown)}
    @dlbscroll = TkScrollbar.new(dframe,'orient'=>'vertical','command'=>dscroll).grid('column'=>4, 'row'=>2,'rowspan'=>7, 'padx'=>5,'sticky'=>'ns')
    @dup = TkButton.new(dframe,'text'=>'Up','command'=>proc {self.move_unit(@dunits,@dlist,:up)}).grid('column'=>2, 'row'=>9, 'padx'=>5)
    @ddown = TkButton.new(dframe,'text'=>'Down','command'=>proc {self.move_unit(@dunits,@dlist,:down)}).grid('column'=>3, 'row'=>9, 'padx'=>5)
    self.disable_buttons(@dup,@ddown)
    TkButton.new(dframe,'text'=>'Clear','command'=>dclear).grid('column'=>2, 'row'=>10, 'padx'=>5)
   
    #controls
    about = proc {Tk.messageBox('type' => 'ok',
      'icon' => 'info',
      'title' => 'About',
      'message' => "Aacalc revision 74\n" + 
      "Copyright (C) 2008 Leon N. Maurer\n" +
      'https://launchpad.net/aacalc' + "\n" +
      "Source code available under the \n" +
      "GNU Public License. See the\n" +
      "Readme for information about the\n" +
      "controls."
    )}
    savebattle = proc{
#NOTE: Ruby hashes have no predetermined order, so the results will get printed
#to the file in a mixed up fashion. This will be fixed in Ruby 1.9 -- for now
#we'll just have to live with it
      if defined?(@battles)
        battle_details = Hash.new
        battle_details['Summary of odds'] = {'Attacker wins'=>@pawins,
          'Defender wins'=>@pdwins,'Mutual annihilation'=>@pnwins}
        battle_details['Technologies'] = {'AAguns'=> @aaGun.get_value == '1',
         'Heavy Bombers'=> @heavyBombers.get_value == '1', 'Combined Bombardment'=>
         @combinedBombardment.get_value == '1','Jets' => @jets.get_value == '1',
         'Super Subs' => @superSubs.get_value == '1'}
        battle_details['Bomardment'] = (@bombarders != nil)
        battle_details['Bombarders'] = @bombarders.arr.collect{|u| u.class.to_s} if @bombarders != nil
        battle_details['Attacking units and odds'] = @a.arr.collect{|u| u.class.to_s}.zip(@acumprobs)
        battle_details['Defending units and odds'] = @d.arr.collect{|u| u.class.to_s}.zip(@dcumprobs)
        filename = Tk.getSaveFile("filetypes"=>[["Text", ".txt"]])
        File.open(filename, "w"){|file| file.print(battle_details.to_yaml)} unless filename == ""
      end
    }
    calc = proc{
      start = Time.now.to_f 
      self.reset_console
    
      has_land = (@aunits + @dunits).any?{|u| u.type == :land}
      has_sea = (@aunits + @dunits).any?{|u| u.type == :sea}

      @bombarders = nil
      if has_land and has_sea #then there's a bombardment coming
        @bombarders = Army.new(@aunits.select{|u| u.type == :sea})
        @oldaunits = @aunits #don't want to permantly remove ships -- just need to seperate them for computations
        @aunits = @aunits.reject{|u| u.type == :sea}
      end

      @a = Army.new(@aunits.reverse)
      @d = Army.new(@dunits.reverse)

      @battles = Array.new
      a = @a.dup
      numaircraft = @aaGun.get_value == '1' ? a.num_aircraft : 0
      aircraftindexes = Array.new
      a.arr.each_with_index{|u,i| aircraftindexes << i if u.type == :air}
      for hits in 0..numaircraft #exceutes even if numaircraft == 0
        @battles << Battle.new(a,@d,@bombarders, binom(numaircraft,hits,1.0/6.0))
        a = a.lose_one(:air)
      end

      @pawins = @battles.inject(0){|s,b|s + b.awins}
      @pdwins = @battles.inject(0){|s,b|s + b.dwins}
      @pnwins = @battles.inject(0){|s,b|s + b.nwins}
      @pswins = @pawins + @pdwins + @pnwins
      #d doesn't lose any units from aaguns, so we can just add everything together
      @dcumprobs = @battles.collect{|b|b.dcumprobs}.inject{|s,a| s.zip(a).collect{|b,c|b+c}}
      #the same is not true for a, so this takes more work
      acumprobs = Array.new
      @battles.each_with_index{|b,i|
        probs = b.acumprobs.reverse
        for j in 0..(i-1)
          probs.insert(aircraftindexes[j],0)
        end
        acumprobs << probs.reverse
      }
      @acumprobs = acumprobs.inject{|s,a| s.zip(a).collect{|b,c|b+c}}

      @attackerProb.value = @pawins.to_s
      @defenderProb.value = @pdwins.to_s
      @annihilationProb.value = @pnwins.to_s
      @sumProb.value = @pswins.to_s
      @aunits = @oldaunits if has_land and has_sea
      @anames.value = @anames.list.collect{|s|s.split[0]}.zip(@acumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}
      @dnames.value = @dnames.list.collect{|s|s.split[0]}.zip(@dcumprobs.reverse).collect{|a| sprintf("%-11s %.6f",a[0],a[1] ? a[1] : 1)}

      print "Operation completed in #{Time.now.to_f - start} seconds\n"
    }
   
    TkLabel.new(cframe, 'text'=>"Attacker wins").grid('column'=>0,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @attackerProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@attackerProb).grid('column'=>1,'row'=>0, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Defender wins").grid('column'=>0,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @defenderProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@defenderProb).grid('column'=>1,'row'=>1, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Mutual annihilation").grid('column'=>0,'row'=>2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @annihilationProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@annihilationProb).grid('column'=>1,'row'=>2, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    TkLabel.new(cframe, 'text'=>"Sum").grid('column'=>0,'row'=>3, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)
    @sumProb = TkVariable.new()
    TkEntry.new(cframe, 'width'=>30, 'relief'=>'sunken','textvariable' =>@sumProb).grid('column'=>1,'row'=>3, 'sticky'=>'w', 'padx'=>5, 'pady'=>5)

    @calculate = TkButton.new(cframe,'text'=>'Calculate','command'=>calc).grid('column'=>3, 'row'=>0, 'padx'=>5, 'pady'=>5)
    TkButton.new(cframe,:text=>'About This Program',:command=>about).grid('column'=>3, 'row'=>3, 'padx'=>5, 'pady'=>5)
    TkButton.new(cframe,:text=>'Save Last Battle',:command=>savebattle).grid('column'=>3, 'row'=>2, 'padx'=>5, 'pady'=>5)

    #techs
    @aaGun = TkCheckButton.new(tframe,:text=>"AA gun").grid(:column=>0,:row=>0,:padx=>5,:pady=>5)
    @heavyBombers = TkCheckButton.new(tframe,:text=>"Hv. Bombers",:command=>@aupdate).grid(:column=>1,:row=>0,:padx=>5,:pady=>5)
    @combinedBombardment = TkCheckButton.new(tframe,:text=>"Comb. Bom.",:command=>@aupdate).grid(:column=>2,:row=>0,:padx=>5,:pady=>5)
    @jets = TkCheckButton.new(tframe,:text=>"Jets",:command=>@dupdate).grid(:column=>3,:row=>0,:padx=>5,:pady=>5)
    @superSubs = TkCheckButton.new(tframe,:text=>"Super Subs",:command=>@aupdate).grid(:column=>4,:row=>0,:padx=>5,:pady=>5)
  end
  def disable_land
    self.disable_buttons(@aunitsnums[0..2],@dunitsnums[0..2])
  end
  def disable_sea
    if @combinedBombardment.get_value == '1'
      @aunitsnums[5].state('normal')
    else
      @aunits = @aunits.reject{|u| u.is_a?(Destroyer)}
      @aunitsnums[5].state('disabled')
      @aunitsnums[5].set(0)
    end
#      @aunitsnums[7..9].each{|sbox| sbox.state('disabled');sbox.set(0)}
    self.disable_buttons(@aunitsnums[7..9],@dunitsnums[5..9])
  end
  def enable_land
    self.enable_buttons(@aunitsnums[0..2],@dunitsnums[0..2])
  end
  def enable_sea
    self.enable_buttons(@aunitsnums[5..9],@dunitsnums[5..9])
  end
  def enable_buttons(*buttons)
    buttons.flatten.each{|b| b.state('active') if b.is_a?(TkButton)
    b.state('normal') if b.is_a?(TkSpinbox)}
  end
  def disable_buttons(*buttons)
    buttons.flatten.each{|b|b.state('disabled')}
  end
  def move_unit(units,list,direction)
    index = list.curselection[0]
    if direction == :down
      i = 1
      clear = (index != nil) && (units.size > 1) && (index < (units.size - 1)) &&
        !(units[index+1].is_a?(Battleship) and units[index].is_a?(Bship1stHit))
    else #:up
      i = -1
      clear = (index != nil) && (index > 0) &&
        !(units[index].is_a?(Battleship) and units[index-1].is_a?(Bship1stHit))
    end
    if clear
      temp = units[index+i]
      units[index+i] = units[index]
      units[index] = temp
      list.see(index + i)
      list.selection_clear(index)
      list.selection_set(index + i)
      self.update_lists
    end     
  end
  def update_lists
    @dnames.set_list(@dunits.collect{|unit|unit.class}) if defined?(@dunits)
    @anames.set_list(@aunits.collect{|unit|unit.class}) if defined?(@aunits)
  end
  def print_to_console(s)
    @console.insert('end',s)
    @console.see('end')
    Tk.update
  end
  def reset_console
    @console.delete(0.0,'end')
  end
end

if __FILE__ == $0
  $gui = BattleGUI.new
  Tk.mainloop()
end