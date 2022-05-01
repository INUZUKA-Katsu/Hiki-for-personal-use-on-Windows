#!/usr/bin/env rackup
# -*- ruby -*-

$LOAD_PATH.unshift "lib"

require "hiki/app"
require "hiki/attachment"
require "./LocalLinkApp.rb"

use Rack::Lint
use Rack::ShowExceptions
use Rack::Reloader
# use Rack::Session::Cookie
# use Rack::ShowStatus
use Rack::CommonLogger
use Rack::Static, :urls => ["/theme"], :root => "."


# inuzuka added the following 6 lines.
["/Mydoc","/Documents","/siryo","/image","/dl.cgi","/selectfile.cgi",
  "/selectfolder.cgi","/exist.cgi","/dir.cgi","/dropedfile.cgi"].each do |url|
  map url do
    run LocalLinkApp.new
  end  
end
map "/" do
  run Hiki::App.new("hikiconf.rb")
end
map "/attach" do
  run Hiki::Attachment.new("hikiconf.rb")
end
