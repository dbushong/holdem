# Texas Holdem

## Overview

This is a very old ruby implementation of holdem I wrote, and an rbot-compatible
plugin to let it be played in a channel.

## Usage

```ruby
require 'texasholdem'
players = %w(alex blake chris)
bucks   = 100
game    = TexasHoldEm::Game.new(players, bucks)

choices = game.choices
bettor  = game.bettor
# ... much more - see holdem_plugin.rb for example
```

## Testing

```
% ./mock a b c
> a |hem help
-> #mock: hem play <starting-amount> (<nick1> <nick2> [<nick3> [...]] | *) => start no-limit game of texas hold'em  (* means all players in this channel; hem (check|call|fold) => do that; hem raise <amount> => do that; hem bet <amount> => make a bet in later rounds of betting; hem pot => give the current value of the pot; hem hand => show current hand; hem cards => show current table cards; hem money [<nick> | *] => show how much money you, <nick>, or everyone have left; hem quit => end the game
> a |hem play 100 *
-> #mock: Starting a new game of No-Limit Texas Hold'em
-> #mock: New round:
-> #mock: c is the small blind and puts in $1
-> #mock: a is the big blind and puts in $2
-> a: Your hand is: AS QH.
-> b: Your hand is: 8D 9D.
-> c: Your hand is: JC JS.
-> #mock: b: the bet is $2 to you; fold, call, or raise?
> %
```
