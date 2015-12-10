combined.rb: Makefile texasholdem.rb holdem_plugin.rb
	(cat texasholdem.rb ; tail -n +2 holdem_plugin.rb) > $@
