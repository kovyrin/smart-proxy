require File.dirname(__FILE__) + '/spec_helper'
require 'smart_proxy'

describe "Newly created SmartProxy" do
  it "should override default options in constructor" do
    p = SmartProxy.new(:user_agent => "Test")
    p.should_not be_nil
    p.user_agent.should == "Test"
  end
  
  it "should not answer to reader methods for unknown options" do
    p = SmartProxy.new
    lambda { p.spec_opt }.should raise_error(NoMethodError)
  end
  
  it "should answer to reader methods for known options" do
    p = SmartProxy.new(:spec_opt => "Test")
    p.spec_opt.should == "Test"
  end
  
  it "should answer to question methods for known options" do
    p = SmartProxy.new(:spec_opt => "Test")
    p.spec_opt?.should == "Test"
  end

  it "should not answer to writer methods for unknown options" do
    p = SmartProxy.new
    lambda { p.spec_opt = "Test" }.should raise_error(NoMethodError)
  end
  
  it "should answer to writer methods for known options" do
    p = SmartProxy.new(:spec_opt => "Test")
    p.spec_opt.should == "Test"
    lambda { p.spec_opt = "Test2" }.should_not raise_error(NoMethodError)
    p.spec_opt.should == "Test2"
  end

  it "should create new Connection on first create_connection call" do
    p = SmartProxy.new
    c1 = p.create_connection("test")
    c1.should_not be_nil

    c2 = p.create_connection("test2")
    c2.should_not be_nil

    c1.should_not be(c2)
  end

  it "should return old Connection on consequtive create_connection calls" do
    p = SmartProxy.new
    c1 = p.create_connection("test")
    c1.should_not be_nil

    c2 = p.create_connection("test")
    c2.should_not be_nil

    c1.should be(c2)
  end
end

describe "Newly created SmartProxy::Connection" do
  def create_proxy(options = {})
    @p = SmartProxy.new(options)
    @c = @p.create_connection("test")
  end
  
  it "should return nil for next_interface if no interfaces specified" do
    create_proxy
    @c.next_interface.should be_nil
  end

  it "should return the same interface value for next_interface if only one interfaces specified" do
    create_proxy :interfaces => [ '127.0.0.1' ]
    @c.next_interface.should == '127.0.0.1'
    @c.next_interface.should == '127.0.0.1'
  end

  it "should round-robin interface values for next_interface" do
    create_proxy :interfaces => [ '127.0.0.1', '127.0.0.2' ]
    @c.next_interface.should == '127.0.0.1'
    @c.next_interface.should == '127.0.0.2'
    @c.next_interface.should == '127.0.0.1'
  end

  it "should not return an interaface after blocking" do
    create_proxy :interfaces => [ '127.0.0.1', '127.0.0.2' ]
    @c.next_interface.should == '127.0.0.1'
    @c.next_interface.should == '127.0.0.2'
    @c.block_interface('127.0.0.1')
    @c.next_interface.should == '127.0.0.2'
    @c.next_interface.should == '127.0.0.2'
    @c.block_interface('127.0.0.2')
    @c.next_interface.should be_nil
  end

  it "should return blocked interaface after unblocking" do
    create_proxy :interfaces => [ '127.0.0.1', '127.0.0.2' ]
    @c.block_interface('127.0.0.1')
    @c.next_interface.should == '127.0.0.2'
    @c.next_interface.should == '127.0.0.2'
    @c.unblock_interface('127.0.0.1')
    @c.next_interface.should == '127.0.0.2'
    @c.next_interface.should == '127.0.0.1'
  end

  it "should return a valid private ip on random_private_ip" do
    create_proxy
    ip = @c.random_private_ip
    ip.should match(/\d+\.\d+\.\d+\.\d+/)
    [/^192\.168/, /^10/, /^172.16/].any? { |r| ip.match r }.should be_true
  end

  it "should return different private ips on random_private_ip calls" do
    create_proxy
    ip1 = @c.random_private_ip
    ip2 = @c.random_private_ip
    ip1.should_not == ip2
  end

  it "should return Curl object on init_curl" do
    create_proxy
    @c.init_curl.should_not be_nil
  end

  it "should pass options from proxy object to Curl" do
    create_proxy(:interfaces => "127.0.0.1")
    curl = @c.init_curl
    curl.should_not be_nil
    
    curl.connect_timeout.should == @p.connect_timeout
    curl.max_redirects.should == @p.max_redirects
    curl.follow_location?.should == @p.follow_location?
    curl.verbose?.should == @p.debug?
    curl.headers["User-Agent"].should == @p.user_agent
  end
end

describe "Curl object returned by SmartProxy::Connection" do
  def create_proxy(options = {})
    @p = SmartProxy.new(options)
    @c = @p.create_connection("test")
  end

  it "should download http://google.com following all redirects" do
    create_proxy
    content = @c.download("http://google.com")
    content.should be_instance_of(String)
    content.should match(/name=btnG/)
    content.should match(/name=btnI/)
    content.should match(/name=hl/)
    content.should match(/name=q/)
  end
end