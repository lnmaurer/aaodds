require 'rubygems'
require 'haml'
require 'sinatra'



get '/' do
  haml :index
end

post '/result' do
  puts params[:tech]
  params[:tech]
end

  
__END__

@@ index
%h1='aacalc'
%p
  Instructions: enter information, click 'Calculate', and wait.
%form{:method => 'POST', :action => "/result"}
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
          %input{:type =>'text', :size => '3', :name=>'aInfantry'} Infantry
          %br
          %input{:type =>'text', :size => '3', :name=>'aTanks'} Tanks
          %br
          %input{:type =>'text', :size => '3', :name=>'aArtillery'} Artillery
          %br
          %input{:type =>'text', :size => '3', :name=>'aFighter'} Fighter
          %br
          %input{:type =>'text', :size => '3', :name=>'aBomber'} Bomber
          %br
          %input{:type =>'text', :size => '3', :name=>'aDestroyer'} Destroyer
          %br
          %input{:type =>'text', :size => '3', :name=>'aBattleship'} Battleship
          %br
          %input{:type =>'text', :size => '3', :name=>'Transport'} Transport
          %br
          %input{:type =>'text', :size => '3', :name=>'Submarine'} Submarine
      %td
        %h2='Defenders'
        %p
          %input{:type =>'text', :size => '3', :name=>'dInfantry'} Infantry
          %br
          %input{:type =>'text', :size => '3', :name=>'dTanks'} Tanks
          %br
          %input{:type =>'text', :size => '3', :name=>'dArtillery'} Artillery
          %br
          %input{:type =>'text', :size => '3', :name=>'dFighter'} Fighter
          %br
          %input{:type =>'text', :size => '3', :name=>'dBomber'} Bomber
          %br
          %input{:type =>'text', :size => '3', :name=>'dDestroyer'} Destroyer
          %br
          %input{:type =>'text', :size => '3', :name=>'dBattleship'} Battleship
          %br
          %input{:type =>'text', :size => '3', :name=>'dransport'} Transport
          %br
          %input{:type =>'text', :size => '3', :name=>'dubmarine'} Submarine
    %tf
      %td{:colspan=>"2"}
        %input{:type => :submit, :value => "Calculate"}
