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
