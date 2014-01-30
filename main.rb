require 'rubygems'
require 'sinatra'
require 'sinatra/base'
require 'sinatra/contrib/all'

set :sessions, true

helpers do
	def calculate_total(cards) #card is a nested arrat
		array = []
		array = cards.map{|element| element[1]}

		total = 0
		array.each do |a|
			if a == "A"
				total += 11
			elsif a.to_i == 0
				total += 10
			else
				total += a.to_i
			end
		end

		#correct for aces
		array_times = array.select{|element| element == "A"}.count
		array_times.times do
			break if total <= 21
			total -= 10
		end

		return total
	end

	def card_images(card) #['H', '4']
		suit = case card[0]
		when 'H' then 'hearts'
		when 'D' then 'diamonds'
		when 'C' then 'clubs'
		when 'S' then 'spades'
		end
		value = card[1]

		if ['J', 'Q', 'K', 'A'].include?(value)
			value = case card[1]
			when 'J' then 'jack'
			when 'Q' then 'queen'
			when 'K' then 'king'
			when 'A' then 'ace'
			end
		end

		"<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
	end

	def winner!(msg)
		session[:player_pot] += session[:bet].to_i
		@show_hit_or_stay_button = false
		@winner = "<strong>#{session[:player_name]} wins!</strong> #{msg}"
	end

	def loser!(msg)
		session[:player_pot] -= session[:bet].to_i
		@show_hit_or_stay_button = false
		@loser = "<strong>#{session[:player_name]} loses!</strong> #{msg}"
	end

	def tie!(msg)
		@show_hit_or_stay_button = false
		@loser = "It's a tie #{msg}"
	end
end

before do
	@show_hit_or_stay_button = true
end

class MyApp < Sinatra::Base
  register Sinatra::Contrib
end

get '/' do
	if session[:player_name]
	redirect  '/bet'
	else
		redirect '/new_player'
	end
end

get '/new_player' do
	session[:player_pot] = 500
	erb :new_player
end

post '/new_player' do
	if params[:player_name].empty?
		@error = "Name is required"
		halt erb(:new_player)
	end

	session[:player_name] = params[:player_name]
	#progress to the game
	redirect  '/bet'
end

get '/bet' do
	erb :betting
end

post '/bet' do
	if session[:player_pot] == 0
		redirect '/game/end'
	end

	if params[:bet].empty? || params[:bet].to_i > session[:player_pot] || params[:bet].to_i <= 0
		@error = "Please input a valid bet"
		halt erb(:betting)
	end
	session[:bet] = params[:bet]
	redirect'/game'
end

get '/game' do
	session[:turn] = session[:player_name]
	#creating a deck and put it in session
	suits = ['H', 'D', 'C', 'S']
	values = ['2','3','4','5','6','7','8','9','10','J','Q','K','A',]
	#deck
	session[:deck] = suits.product(values).shuffle!
	#dealer cards
	session[:dealer_cards] = []
	#player cards
	session[:player_cards] = []

	#deal cards
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop
	session[:dealer_cards] << session[:deck].pop
	session[:player_cards] << session[:deck].pop
	erb :game
end

post '/game/player/hit' do
	@replay_again = false

	session[:player_cards] << session[:deck].pop
	player_total = calculate_total(session[:player_cards])
	if player_total > 21
		loser!("#{session[:player_name]} is busted")
		@replay_again = true
	elsif player_total == 21
		winner!("#{session[:player_name]} hits blackjack!")
		@replay_again = true
	end

	erb :game, layout: false
end


post '/game/player/stay'  do
	@success = "#{session[:player_name]} has chosen to stay."
	@show_hit_or_stay_button = false
	redirect '/game/dealer'
end


get '/game/dealer' do
	session[:turn] = "dealer"
	@show_hit_or_stay_button = false
	@replay_again = false
	#decision tree
	player_total = calculate_total(session[:player_cards])
	dealer_total = calculate_total(session[:dealer_cards])

	if dealer_total == 21
		loser!("Sorry the dealer hit blackjack the dealer has #{dealer_total}, you have #{player_total}")
		@replay_again = true
	elsif dealer_total > 21
		winner!("Congrats the dealer busted the dealer has #{dealer_total}, you have #{player_total}")
		@replay_again = true
	elsif dealer_total >= 17
		#dealer stays
		redirect '/game/compare'
	else
		#dealer hits
		@show_dealer_hit_button = true
	end

	erb :game, layout: false
end

post '/game/dealer/hit' do
	session[:dealer_cards] << session[:deck].pop
	redirect '/game/dealer'
end

get '/game/compare' do
	@show_hit_or_stay_button = false
	@replay_again = false

	player_total = calculate_total(session[:player_cards])
	dealer_total = calculate_total(session[:dealer_cards])

	if player_total < dealer_total
		loser!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
		@replay_again = true
	elsif dealer_total < player_total
		winner!("#{session[:player_name]} stayed at #{player_total}, and the dealer stayed at #{dealer_total}")
		@replay_again = true
	else
		tie!("Both #{session[:player_name]} and dealer stays at #{dealer_total}.")
		@replay_again = true
	end

	erb :game, layout: false
end

post '/game/replay' do
	redirect '/game'
end

post '/game/end' do
	redirect '/game/end'
end

get '/game/end' do
	erb :game_over
end