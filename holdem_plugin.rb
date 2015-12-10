require 'texasholdem'

class TexasHoldemPlugin < Plugin
  def initialize
    super
    @games = {}
  end

  def help(plugin, topic='')
    "hem play <starting-amount> (<nick1> <nick2> [<nick3> [...]] | *) => " +
    "start no-limit game of texas hold'em  (* means all players in this " +
    "channel; hem (check|call|fold) => do that; hem raise <amount> => " +
    "do that; hem bet <amount> => make a bet in later rounds of betting; " +
    "hem pot => give the current value of the pot; hem hand => " +
    "show current hand; hem cards => show current table cards; hem money " +
    "[<nick> | *] => show how much money you, <nick>, or everyone have left; "+
    "hem quit => end the game"
  end

  def privmsg(m)
    if m.private?
      if m.params =~ /^(#\w+)\s+/
        channel = $1
        cmd     = $'

        if cmd =~ /^\s*(check|call|fold|raise|play)/i
          m.reply \
            "you may not private-message play, check, call, fold, or raise"
          return
        end
      else
        m.reply "in private message mode, you must give <#channel> as your " +
                "first argument"
        return
      end
    else
      channel = m.channel
      cmd     = m.params
    end

    cmd.strip!

    if cmd =~ /^help\b/
      m.reply help(self)
      return
    end

    if cmd =~ /^play\s+(\d+)\s+(.+)/
      if @games[channel]
        m.reply "there is already a game in progress in #{channel}"
        return
      end

      startMoney = $1.to_i
      nicks      = $2

      if nicks == '*'
        nicks = @bot.channels[channel].users.keys.reject {|n| n == @bot.nick }
      else
        nicks = nicks.split
      end

      m.reply "Starting a new game of No-Limit Texas Hold'em"

      g = @games[channel] = TexasHoldEm::Game.new(nicks.sort, startMoney)

      newRound(g, channel)

      return
    end

    unless g = @games[channel]
      m.reply 'There is no game in progress yet, use "play" to start one.'
      return
    end

    unless curPlayer = g.player[m.sourcenick]
      m.reply 'You are not in the game in ' + channel
      return
    end

    begin
      case cmd
        when 'quit'
          @bot.say channel, "#{m.sourcenick} has left the game."
          g.player[m.sourcenick].money   = 0
          g.player[m.sourcenick].stillIn = false
          return
        when 'end'
          @bot.say channel, "#{m.sourcenick} has ended the game."
          @games.delete channel
          return
        when 'hand'
          tellHand curPlayer
        when 'pot'
          m.reply "The current pot is: $#{g.pot}."
        when /^money(?:\s+(\S+))?$/
          if $1 == '*'
            g.players.each {|p| m.reply "#{p.nick} has $#{p.money}." }
          elsif $1
            unless g.player[$1]
              m.reply "There is no player #$1 currently in the game."
              return
            end
            m.reply "#$1 has #{g.player[$1].money}."
          else
            m.reply((m.private? ? 'You have' : curPlayer.nick + ' has') +
              " $#{curPlayer.money}.")
          end
        when 'cards'
          m.reply g.table.size > 0 ?
            "The cards on the table are: #{g.table.abbr}" :
            'There are no cards on the table.'
        when /^(check|call|fold)$|^(raise|bet)\s+\$?(\d+)$/
          action = $1 || $2
          amount = $3

          if g.bettor.nick != m.sourcenick
            m.reply "#{m.sourcenick}: it's #{g.bettor.nick}'s turn to bet."
            return
          end

          case action
            when /check|call/
              g.send(action + 'Bet')
            when 'raise'
              g.raiseBet amount.to_i
            when 'bet'
              g.newBet amount.to_i
            when 'fold'
              g.foldHand
          end

          if g.winner
            str = if g.winner.is_a? Array
              "#{g.winner.map{|p| p.nick}.join ' and '} share " +
              "the pot of $#{g.pot}."
            else
              "#{g.winner.nick} wins the pot of $#{g.pot}."
            end

            roundPlayers = g.playersLeft + g.losers
            if roundPlayers.size > 1
              m.reply str + '  Best hands were:'
              roundPlayers.each do |p|
                m.reply "#{p.nick}: #{p.bestHand.descr}: #{p.bestHand.abbr}"
              end
            else
              m.reply str
            end

            if g.gameOver?
              m.reply "#{g.winner.nick} has won the game!"
              @games.delete channel
              return
            end

            g.losers.each {|p| "#{p.nick} is broke and out of the game." }

            g.startHand

            newRound(g, channel)

            return
          end

          case g.lastAction
            when :flop
              m.reply "The flop is: #{g.table.abbr}."
            when :turn
              m.reply "The turn card is #{g.table[-1].abbr}; " +
                      "the table cards are now: #{g.table.abbr}"
            when :river
              m.reply "The river is #{g.table[-1].abbr}; " +
                      "the table cards are now: #{g.table.abbr}"
          end

          promptBettor g, channel
        else m.reply help(self)
      end
    rescue TexasHoldEm::RulesViolation => v
      m.reply v.message
      return
    end
  end

  private #####################################################################

  def newRound(g, channel)
    @bot.say channel, "New round:"
    @bot.say channel,
      "#{g.smallBlind.nick} is the small blind and puts in $#{g.blind/2}"
    @bot.say channel,
      "#{g.bigBlind.nick} is the big blind and puts in $#{g.blind}"

    g.players.each {|p| tellHand p }

    promptBettor g, channel
  end

  def tellHand(p)
    @bot.say p.nick, "Your hand is: #{p.hand.abbr}."
  end

  def promptBettor(g, channel)
    choices = g.choices
    if choices.size > 2
      choices[-2] += ', or ' + choices[-1]
      choices.pop
      choices = choices.join ', '
    else
      choices = choices.join ' or '
    end

    str = if g.bet == g.bettor.bet
      if g.bet > 0
        'the bet is back to you; '
      else
        ''
      end
    else
      "the bet is $#{g.bet - g.bettor.bet} to you; "
    end

    @bot.say channel, "#{g.bettor.nick}: #{str}#{choices}?"
  end
end

plugin = TexasHoldemPlugin.new
plugin.register("holdem")
plugin.register("hem")
