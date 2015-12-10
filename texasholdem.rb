module TexasHoldEm
  class RulesViolation < RuntimeError
  end

  class RingArray < Array
    def [](n)
      at n % size
    end
  end

  class Card
    attr_reader :n, :suit

    def initialize(n, suit)
      @n        = n
      @suit     = suit
    end

    def suitWord
      %w(Nothing Spades Clubs Diamonds Hearts)[@suit]
    end

    def suitChar
      suitWord[0,1]
    end

    def abbr
      %w(X X 2 3 4 5 6 7 8 9 10 J Q K A)[n] + suitChar
    end

    def name
      %w(Error Error Two Three Four Five Six Seven 
         Eight Nine Ten Jack Queen King Ace)[@n] + ' of ' + suitWord
    end

    def re
      '%02d%s' % [@n, suitChar]
    end
  end

  class Hand < Array
    attr_accessor :score, :descr

    def initialize(a = nil)
      replace a if a
    end

    def abbr
      map {|c| c.abbr}.join ' '
    end
  end

  class Deck < Array
    def initialize
      super

      for suit in 1..4
        for n in 2..14
          push Card.new(n, suit)
        end
      end
    end

    def draw
      slice!(rand(size))
    end
  end

  class Player
    attr_reader   :nick, :money, :bestHand, :bestScore
    attr_accessor :hand, :bet, :stillIn, :hasBet

    def initialize(nick, startMoney)
      @nick      = nick
      @money     = startMoney
      @bet       = 0
      @hand      = Hand.new
      @bestHand  = nil
      @stillIn   = true
      @hasBet    = false
    end

    public ####################################################################

    def money=(amount)
      raise RulesViolation, "#@nick is $#{amount.abs} short" if amount < 0
      @money = amount
    end

    def findBestHand(table)
      cards = (table + @hand).sort {|a,b| b.n <=> a.n } ## sort desc by number
      str   = cards.map {|c| c.re }.join

      straight = straightFlush = false

      # Straight & Straight Flush
      for c in cards[0..(cards.size - 5)]
        if str =~ Regexp.new(c.re + (1..4).map{|m| '%02d.' % (c.n - m)}.join)
          hand = $&

          if hand =~ /..(.)(..\1){4}/
            bestStr       = hand
            straightFlush = true
            break
          elsif !straight
            bestStr  = hand
            straight = true
          end
        end
      end

      # Ace-Straight Special-Case: 14 -> 1
      if !straightFlush && str =~ /14.05.04.03.02./
        hand = $&.sub(/^14(.)(.+)/, '\2' + '01\1') # 14 -> 01
        if hand =~ /..(.)..\1..\1..\1..\1/
          bestStr       = hand
          straightFlush = true
        elsif !straight
          bestStr       = hand
          straight      = true
        end
      end

      ## ordered by best hand  --  there be dragons here
      if straightFlush
        descr   = 'Straight Flush'
        score   = 8000000 + bestStr[0,2].to_i
      elsif str =~ /(\d\d).(\1.){3}/
        descr   = 'Four of a Kind'
        kicker  = ($` + $')[0,3]
        bestStr = $& + kicker
        score   = 7000000 + scoreCards($1, kicker)
      elsif str =~ /((\d\d).\2.).*((\d\d).\4.\4.)|((\d\d).\6.\6.).*((\d\d).\8)/
        descr   = 'Full House'
        bestStr = $1 ? $1 + $3 : $5 + $7
        score   = 6000000 + ($1 ? scoreCards($4, $2) : scoreCards($6, $8))
      elsif str =~ /(\d\d(.)).*?(..\2).*?(..\2).*?(..\2).*?(..\2)/
        descr   = 'Flush'
        flush   = [ $1, $3, $4, $5, $6 ]
        bestStr = flush.join
        score   = 5000000 + scoreCards(flush)
      elsif straight
        descr   = 'Straight'
        score   = 4000000 + bestStr[0,2].to_i
      elsif str =~ /(\d\d).\1.\1./
        descr   = 'Three of a Kind'
        kickers = ($` + $')[0,6]
        bestStr = $& + kickers
        score   = 3000000 + scoreCards($1, *kickers.split(/\D/))
      elsif str =~ /((\d\d).\2.)(.*)((\d\d).\5.)/
        descr   = 'Two Pair'
        kicker  = ($` + ($3 || '') + $')[0,3]
        bestStr = $1 + kicker + $4
        score   = 2000000 + scoreCards($2, $5, kicker)
      elsif str =~ /(\d\d).\1./
        descr   = 'Pair'
        kickers = ($` + $')[0,9]
        bestStr = $& + kickers
        score   = 1000000 + scoreCards($1, *kickers.split(/\D/))
      else
        descr   = 'High Card'
        bestStr = str[0,15]
        score   = scoreCards(bestStr.split(/\D/))
      end

      re = Regexp.new(bestStr.gsub(/...(?=.)/, '\&|'))

      @bestHand       = Hand.new(cards.find_all {|c| c.re =~ re })
      @bestHand.score = score
      @bestHand.descr = descr

      @bestHand
    end

    private ###################################################################

    def scoreCards(*cards)
      cards = cards[0] if cards[0].type == Array
      n = 0
      cards.reverse.each_with_index {|c,i| n += c.to_i * 13 ** i }
      n
    end
  end

  class Game
    attr_reader :players, :blind, :bettor, :pot, :bet, :smallBlind, :bigBlind,
                :player, :winner, :table, :lastAction, :losers

    def initialize(nicks, startMoney)
      @blind       = 2
      @maxRaises   = 3
      @players     = RingArray.new
      @player      = {}
      @dealerIndex = 0

      # create players
      for nick in nicks
        p = Player.new(nick, startMoney)
        @players     << p
        @player[nick] = p
      end

      startHand
    end

    private ###################################################################

    def findLosers
      for p in @players.find_all {|p| p.stillIn && p.money < @blind }
        p.stillIn = false
        p.money   = 0
        @losers << p
      end
    end

    def winHand(player)
      # pay the man
      player.money += @pot

      # the winner of this hand (and possibly the game)
      @winner = player

      # find the losers
      findLosers
    end

    def tieHand(winners)
      # pay the men
      winners.each {|w| w.money += @pot / winners.size }

      # set winner to an array
      @winner = winners

      # find the losers
      findLosers
    end

    def makeBet(amount)
      raise RulesViolation,
        "#{@bettor.nick} tried to bet $#{amount} when the bet is $#@bet" \
          if amount < (@bet - @bettor.bet)

      raise RulesViolation,
        "#{@bettor.nick} tried to bet $#{amount} when (s)he only has " +
        "#{@bettor.money}" if amount > @bettor.money

      @bet  = amount
      @pot += amount

      @bettor.money -= amount
      @bettor.bet    = amount

      @bettor.hasBet = true

      nextBettor

      # unless it's the first round and we're on the bigBlind's second betting
      # chance or there are people who still haven't called, the round's over
      unless @players.find {|p| p.stillIn && (p.bet < @bet || !p.hasBet) }
        case @table.size
          when 0  # pre-flop
            dealFlop
          when 3  # flop
            dealTurn
          when 4  # turn
            dealRiver
          when 5
            playersLeft.each {|p| p.findBestHand @table }
            hiScore = playersLeft.map {|p| p.bestHand.score}.max
            winners = playersLeft.find_all {|p| p.bestHand.score == hiScore }

            if winners.size > 1
              tieHand winners
            else
              winHand winners[0]
            end
          else
            raise "There are #{@table.size} cards on the table!?"
        end

        return
      end

      @lastAction = nil
    end

    def nextBettor
      begin
        @bettorIndex += 1
      end until (@bettor = @players[@bettorIndex % @players.size]).stillIn
      @bettor
    end

    def dealFlop
      3.times { @table << @deck.draw }

      resetRound
      @lastAction = :flop
    end

    def dealTurn
      @table << @deck.draw

      resetRound
      @lastAction = :turn
    end

    def dealRiver
      @table << @deck.draw

      resetRound
      @lastAction = :river
    end

    def resetRound
      @bet = @raises = 0
      @losers = []

      for p in @players
        p.bet    = 0
        p.hasBet = false
      end

      @bettorIndex = @dealerIndex

      nextBettor
    end

    public ####################################################################

    def playersLeft
      @players.find_all {|p| p.stillIn }
    end

    def gameOver?
      @players.find_all {|p| p.money > 0 }.size == 1
    end

    def newBet(amount)
      raise RulesViolation,
        "there is already a bet of #@bet on the table; did you mean raise?" \
          if @bet > 0

      @raises -= 1

      raiseBet amount
    end

    def checkBet
      makeBet 0
    end

    def callBet
      makeBet @bet
    end

    def raiseBet(amount)
      @raises += 1

      raise RulesViolation, "maximum number of raises (#@maxRaises) exceeded" \
        if @raises > @maxRaises

      raise RulesViolation, "minimum bet/raise is $#@blind" if amount < @blind

      min = playersLeft.min {|a,b| a.money <=> b.money }

      raise RulesViolation, 
        "maximum bet is #{min.nick}'s remaining money: $#{min.money}" \
          if amount > min.money

      makeBet @bet + amount
    end

    def foldHand
      @bettor.stillIn = false

      if playersLeft.size == 1
        winHand playersLeft[0]
      else
        nextBettor
      end

      @lastAction = nil
    end

    def choices
      if @bet == @bettor.bet
        choices = ['check']
      else
        choices = ['fold', 'call']
      end
      choices += [@bet > 0 ? 'raise' : 'bet'] if @raises < @maxRaises

      choices
    end

    def startHand
      # shuffle the deck
      @deck = Deck.new

      # reset everything
      @bet = @pot = @raises = 0
      @winner     = nil
      @table      = Hand.new
      @lastAction = :deal
      @losers     = []

      for p in @players.find_all {|p| p.money > 0 }
        p.bet     = 0
        p.stillIn = true
        p.hasBet  = false
      end

      # rotate the dealer
      @dealerIndex += 1

      # handle blinds
      @bettorIndex = @dealerIndex

      @smallBlind = nextBettor
      makeBet @blind / 2    ## calls nextBettor

      @bigBlind = @bettor
      makeBet @blind            ## calls nextBettor
      @bigBlind.hasBet = false

      # deal the cards
      @players.each {|p| 
        p.hand = Hand.new([ @deck.draw, @deck.draw ]) if p.stillIn 
      }
    end
  end
end
