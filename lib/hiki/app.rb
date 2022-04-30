
require "rubygems"
require "rack"

require "hiki/config"
require "hiki/repository"
require "hiki/xmlrpc"

$LOAD_PATH.unshift(File.dirname(__FILE__))

module Hiki
  class App
    def initialize(config_path = "hikiconf.rb")
      @config_path = config_path
    end
    def call(env)
      request = Rack::Request.new(env)
      # TODO use Rack::Request#env or other methods instead of ENV
      # HACK replace ENV values to web application environment
      env.each{|k,v| ENV[k] = v.to_s unless /\Arack\./ =~ k }
      conf = Hiki::Config.new(@config_path)
      response = nil
      if %r|text/xml| =~ request.content_type and request.post?
        server = Hiki::XMLRPCServer.new(conf, request)
        response = server.serve
      else
        db = conf.database
        db.open_db do
          command = Hiki::Command.new(request, db, conf)
          response = command.dispatch
        end
      end

      response.header.delete("status")
      response.header.delete("cookie")

      charset = response.header.delete("charset")
      response.header["Content-Type"] ||= response.header.delete("type")
      response.header["Content-Type"] += "; charset=#{charset}" if charset

      response.body = [] if request.head?

      #inuzuka 以下17行追加
      if env["SERVER_NAME"]!="localhost" and 
         env["REQUEST_METHOD"]=="GET" and  
         not response.body[0].match(/キーワード:\[<a href.*>(限定)?公開<\/a>\]/) and
         not response.body[0].match(/<textarea.*?>([^<]*\n)?公開(\n|[^<]*<\/textarea>)/) and
         not response.body[0].match(/Wait or <a href=.*?>Click here!<\/a>/)
         if response.body[0].match(/<textarea/)
           msg = "このページを編集することはできません m(__)m　"
         else
           msg = "指定したページを開くことはできません m(__)m　"
         end
         str =  %Q|<html><head><meta charset="utf-8">|
         str =  %Q|<link rel="stylesheet" type="text/css" href="theme/hiki/hiki.css">|
         str << %Q|</head><body class="hikokai">|
         str << %Q|#{msg}<input type="button" value="戻る" onclick="history.back()">|
         str << %Q|</body></html>|
         response.header["content-Length"] = str.bytesize.to_s
         response.body = [str]
      end
      
      response.finish
    end
  end
end
