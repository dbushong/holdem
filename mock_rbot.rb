require 'readline'

class MockMessage
  attr_reader :params, :sourcenick, :plugin
  def initialize(params, sourcenick, priv=false)
    @params     = params
    @sourcenick = sourcenick
    @priv       = priv
  end

  def channel
    '#mock'
  end

  def private?
    @priv
  end

  def reply(msg)
    puts "-> #{private? ? sourcenick : channel}: #{msg}"
  end
end

class MockChannel
  attr_reader :users
  def initialize(nicks)
    @users = {}
    nicks.each {|n| @users[n] = true }
  end
end

class MockBot
  attr_reader :channels
  def initialize(nicks)
    @channels = { '#mock' => MockChannel.new(nicks) }
  end

  def nick
    'mock'
  end

  def say(chan, msg)
    puts "-> #{chan}: #{msg}"
  end
end

class Plugin
  @@plugins = {}

  def initialize
    @bot = MockBot.new(@@nicks)
  end

  def self.set_nicks(nicks)
    @@nicks = nicks
  end

  def self.mock
    puts 'mocking'
    while line = Readline.readline('> ', true)
      unless line =~ /^(\w+)\s+(\|)?(\w+)(?:\s+(.+))?/
        puts "usage: nick [|]rest of msg"
        next
      end

      sourcenick = $1
      priv       = !$2
      cmd        = $3
      msg        = $4

      unless plugin = @@plugins[cmd]
        puts "unregistered command: #{cmd}"
        next
      end

      plugin.privmsg(MockMessage.new(msg, sourcenick, priv))
    end
  end

  def register(name)
    @@plugins[name] = self
  end
end
