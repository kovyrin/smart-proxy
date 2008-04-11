require 'curb'

class SmartProxy
  def initialize(options = {})
    defaults = {
      :user_agent => "Mozilla/5.0 (Macintosh; U; Intel Mac OS X; en) AppleWebKit/523.12 (KHTML, like Gecko) Version/3.0.4 Safari/523.12",
      :debug => false,
      :emulate_proxy => true,
      :interfaces => [],
      :connect_timeout => 60,
      :max_redirects => 15,
      :follow_location => true
    }
    @options = defaults.merge(options)
  end
    
  def create_connection(name)
    @connections ||= {}
    @connections[name] ||= SmartProxy::Connection.new(self)
  end
  
  def method_missing(meth, *args)
    m = meth.to_s.match(/([\w\_]+)([\?\=]*)$/)
    unless m && m[1] && @options.member?(m[1].to_sym)
      raise NoMethodError.new("Unknown method '#{meth}' for #{self}") 
    end

    if m[2] && m[2] == "="
      @options[m[1].to_sym] = args[0]
    elsif m[2] && m[2] == "?"
      @options[m[1].to_sym]
    else
      @options[meth]
    end
  end
end

class SmartProxy::Connection
  def initialize(proxy)
    @proxy = proxy
    randomize_private_prefix
    populate_iterfaces
  end
    
  # Downloads specified url 
  def download(url)
    curl = init_curl(url)
    return nil unless curl && curl.perform
    return curl.body_str
  end

  # Creates new curl instance and initializes it with proxy options + binds to next interface
  def init_curl(url = nil)
    curl = Curl::Easy.new
    return nil unless curl

    # Pass url if provided
    curl.url = url if url

    # Pass options from proxy object
    [ :connect_timeout, :max_redirects, :follow_location ].each do |option|
      curl.send("#{option}=", @proxy.send(option))
    end

    curl.verbose = @proxy.debug?
    curl.headers["User-Agent"] = @proxy.user_agent

    # Get next interface
    curl.interface = next_interface
    
    # Emulate proxy
    if @proxy.emulate_proxy
      curl.headers["Via"] = "1.1 proxy:3128 (squid/2.6.STABLE5)"
      curl.headers["Cache-Control"] = "max-age=0"
      curl.headers["X-Forwarded-For"] = random_private_ip
    end

    return curl
  end

  def next_interface
    return nil if @active_interfaces.size == 0
    int = @active_interfaces[@interface_idx]
    @interface_idx = (@interface_idx + 1) % @active_interfaces.size
    return int
  end

  def block_interface(int)
    @active_interfaces.delete(int)
    @inactive_interfaces << int
  end

  def unblock_interface(int)
    @inactive_interfaces.delete(int)
    @active_interfaces << int
  end

  def random_private_ip(start = nil)
    start ||= @private_prefix
    "%s.%d.%d" % [ start, rand(255), rand(253) + 1 ]
  end

private

  def populate_iterfaces
    @active_interfaces = @proxy.interfaces || []
    @inactive_interfaces = []
    @interface_idx = 0
  end

  def randomize_private_prefix
    @private_prefix = ["192.168", "10", "172.16"].sort_by{rand}.first
    @private_prefix += ".#{rand(255)}" if @private_prefix == "10"
  end

end