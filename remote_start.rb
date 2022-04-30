# -*- coding: utf-8 -*-
require 'win32ole'
require 'rbconfig'

#***** rubyプログラム非同期実行メソッド *****
def ruby_path
  path = RbConfig.ruby
  unless File.exist? path
    wmi = WIN32OLE.connect('winmgmts://')
    process_set = wmi.ExecQuery("select * from Win32_Process where Name like 'ruby.exe'")
    process_set.each do |item|
      path=item.CommandLine.match(/(.*) [^\s]+\.rb/)[1]
    end
  end
  path
end

def process_exist?(rb_file)
  path=""
  wmi = WIN32OLE.connect('winmgmts://')
  process_set = wmi.ExecQuery("select * from Win32_Process where CommandLine like '%ruby%'")
  process_set.each do |item|
    p item.CommandLine
    if item.CommandLine.match(/#{rb_file}/)
      return true
    end
  end
  false
end

unless process_exist?("remote_dialog.rb")
  str = ruby_path+" "+__dir__+"/remote_dialog.rb"
  wsh = WIN32OLE.new('WScript.Shell')
  wsh.Run(str,0,false)
  p :started_remote_dialog
else
  p :already_running
end