combined.rb: Makefile texasholdem.rb holdem_plugin.rb
	@(cat texasholdem.rb ; tail -n +2 holdem_plugin.rb) > $@.tmp.rb
	@ruby -cw $@.tmp.rb && mv -f $@.tmp.rb $@ || rm -f $@.tmp.rb
