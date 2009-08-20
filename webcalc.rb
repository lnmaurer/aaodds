require 'rubygems'
require 'haml'
require 'sinatra'



get '/' do
  haml :index
end

post '/' do
  
end

  
__END__

@@ index
%h1='Test'
%form{:method => 'POST', :action => "/"}
  %table
    %tr
      %td{:colspan=>"2"}
        %h2='Tech'
        %p
          %input{:type =>'checkbox', :name=>'tech', :value=>'AAGun'} AA Gun
          %input{:type =>'checkbox', :name=>'tech', :value=>'HeavyBombers'} Heavy Bombers
          %input{:type =>'checkbox', :name=>'tech', :value=>'CombinedBombardment'} Combined Bombardment
          %input{:type =>'checkbox', :name=>'tech', :value=>'Jets'} Jets
          %input{:type =>'checkbox', :name=>'tech', :value=>'SuperSubs'} Super Subs
    %tr
      %td
        %h2='Attackers'
        %p
          %input{:type =>'text', :name=>'aInfantry'} Infantry
          %br
          %input{:type =>'text', :name=>'aTanks'} Tanks
          %br
          %input{:type =>'text', :name=>'aArtillery'} Artillery
          %br
          %input{:type =>'text', :name=>'aFighter'} Fighter
          %br
          %input{:type =>'text', :name=>'aBomber'} Bomber
          %br
          %input{:type =>'text', :name=>'aDestroyer'} Destroyer
          %br
          %input{:type =>'text', :name=>'aBattleship'} Battleship
          %br
          %input{:type =>'text', :name=>'Transport'} Transport
          %br
          %input{:type =>'text', :name=>'Submarine'} Submarine
      %td
        %h2='Defenders'
        %p
          %input{:type =>'text', :name=>'dInfantry'} Infantry
          %br
          %input{:type =>'text', :name=>'dTanks'} Tanks
          %br
          %input{:type =>'text', :name=>'dArtillery'} Artillery
          %br
          %input{:type =>'text', :name=>'dFighter'} Fighter
          %br
          %input{:type =>'text', :name=>'dBomber'} Bomber
          %br
          %input{:type =>'text', :name=>'dDestroyer'} Destroyer
          %br
          %input{:type =>'text', :name=>'dBattleship'} Battleship
          %br
          %input{:type =>'text', :name=>'dransport'} Transport
          %br
          %input{:type =>'text', :name=>'dubmarine'} Submarine
    %tf
      %td{:colspan=>"2"}
        %input{:type => :submit, :value => "Calculate"}
