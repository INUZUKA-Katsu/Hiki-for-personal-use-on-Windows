#coding:utf-8

require "cgi"
require 'win32ole'
require 'json'
require 'rbconfig'
require 'pathname'
require 'uri'
require 'kconv'
require 'drb/drb'
require __dir__+'/remote_start'
require __dir__+'/wincontrol'

Encoding.default_external = 'utf-8'

eval(File.open("hikiconf.rb"){|f| f.read })
SIRYO = @siryo_path
IMAGE = @image_path
if @maxnum_to_disp_file_detail
  NUM = @maxnum_to_disp_file_detail
else
  NUM = 50
end

begin
  WIN32OLE.const_load('Microsoft Office 14.0 Object Library')
  FilePicker   = WIN32OLE::MsoFileDialogFilePicker
  FolderPicker = WIN32OLE::MsoFileDialogFolderPicker
rescue
  FilePicker   = 3
  FolderPicker = 4
end      

#ファイル/フォルダ選択ダイアログを表示するための"remote_dialog.rb"に接続
sleep(1)
DRb.start_service
drb_uri = File.read(__dir__+"/drb_uri.txt")
Dialog = DRbObject.new(nil,drb_uri)

class LocalLinkApp
  def call(env)
    req = Rack::Request.new(env)

    if ["/dl.cgi", "/exist.cgi", "/dir.cgi"].include? req.script_name
      re = req.query_string()
    else
      re = req.fullpath()
    end
    path = re.sub(/&\d+$/,"") #Ajaxのキャッシュを無効にするために付加された文字列を削除.
    p "path => "+path
    decoded_path = uri_decode(path)
    full_path = decode_alias(decoded_path).gsub(/\//,"\\")
    filename = File.basename(full_path).to_s
    full_path = __dir__+"/"+filename if File.dirname(full_path).size==1
    header   = Hash.new
    #p_req_heder(req)
    #編集画面でファイル選択ボタン・フォルダ選択ボタンをクリックしたときの処理
    if ["/selectfile.cgi","/selectfolder.cgi"].include? req.script_name
          if req.script_name == "/selectfile.cgi"
             dialog_title = "Select Files"
          else
             dialog_title = "Select Folder"
          end
          
          #ダイアログ終了後にHikiの画面を前面表示するためのハンドルを取得しておく。
          hiki_hwnd = get_foreground_window
          
          #ダイアログボックスを常にHIKIの前面に表示するプログラムを開始する。
          thread_win_ctrl = Thread.new(dialog_title) do |dialog_title|
            set_foreground_dialog(dialog_title)
          end
          
          #リモートサーバにアクセスしてファイル/フォルダ選択ダイアログを表示
          response = []
          thread = Thread.new do
            response = Dialog.get_select_files_or_folder(dialog_title)
          end
          
          #戻り待ちのカウントダウン
          sec = 0
          wait_sec = 30
          while sec < wait_sec and thread.status!=false
            p thread.status
            sleep(0.1)
            p sec
            sec += 0.1
            if sec >= wait_sec
              #ダイアログを強制的に閉じる。
              p :close_window
              close_window(dialog_title)
            end
          end
          #ダイアログ終了後の処理を続行
          thread.join
          Thread.kill( thread_win_ctrl )
          if response and response.size>0
            if dialog_title == "Select Files"
              p response
              #Thunderbird添付ファイルのファイル名に混入する不正文字を処理.
              ans = correct_file_name(response)
              #使用フォルダ名を次回のデフォルトとするために保存.
              folder = response[0].sub(/\\[^\\]*$/,"").toutf8
              File.write(__dir__+"/defaultdir.txt",folder)
            elsif dialog_title == "Select Folder"
              ans = response
              folder = response[0].toutf8
              File.write(__dir__+"/defaultdir2.txt",Pathname(folder)+"../") #親フォルダを記録する.
            else
              ans = nil
            end
          end
           
          set_foreground_window(hiki_hwnd)
          
          if ans
            header["Content-Type"] = "application/json;charset=utf-8"
            header["Content-Disposition"] = "inline;"
            response = JSON.generate(ans)
          else
            header["Content-Type"] = "text/plain;charset=utf-8"
            header["Content-Disposition"] = "inline;"
            response = JSON.generate(["not selected"])
            #p "not selected"
          end
            
    elsif req.script_name=="/dropedfile.cgi"
          param = req.POST()
          files_json = param['droped_files']
          full_paths = get_explorer_location(JSON.parse(files_json))
          ans = correct_file_name(full_paths)

          header["Content-Type"] = "application/json;charset=utf-8"
          response = JSON.generate(ans)

    #リンクをクリックしたとき、リンクにマウスオーバーしたときの処理のその1　リンクが生きている場合のレスポンス
    elsif File.exist?(full_path)
          #マウスオーバーへのレスポンス
          if req.script_name=="/exist.cgi"
            header["Content-Type"] = "text/plain;charset=utf-8"
            response = "true"   
              
          #フォルダを開く操作
          elsif File.directory?(full_path)
            if req.host() == "localhost"
              header,response = open_dir_by_explorer(full_path)
            else
              header,response = open_dir_on_browser(full_path, req.script_name)
            end
            
          #ファイルを開く操作
          else
            if [".jpg",".png",".gif",".bmp","jpeg",".zip",".atc",".vbs",".bat",".exe","mp3"].include?(filename[-4,4].downcase)
              header,response = return_binary_data(full_path,filename)
            
            elsif filename[-4,4].downcase == "html"
              header,response = return_modified_html(full_path)
            
            #localhostで使用する場合はローカルブラウザを経由せずに拡張子に関連付けられたアプリで直接ファイルを開く.
            elsif req.host() == "localhost"
              header,response = open_file_directly(full_path)
              
            #他の端末からアクセスしたとき
            else
              #htmlファイルはローカルブラウザにhtmlデータを返す。
              if filename[-4,4] == "html"
                header["Content-Type"] = "text/html;charset=utf-8"
                response = "<!DOCTYPE html>\n"
                response << File.read(full_path)
              
              #html以外のファイルはローカルブラウザにバイナリデータを返す。
              else
                header,response = return_binary_data(full_path,filename)
              end
            end
          end
    else
    #以下はリンク切れの場合のレスポンス(ファイルもフォルダも）
          if req.script_name=="/exist.cgi"
          #マウスオーバーによるリンクチェックの場合
            header["Content-Type"] = "text/plain;charset=utf-8"
            response = "bloken link: #{full_path}"
           
          elsif full_path.match(/\.\w+$/)==nil
          #フォルダリンクをクリックした場合(Ajaxによるリクエストに対する返信)
            header["Content-Type"] = "text/plain;charset=utf-8"
            response = "Did not find folder: #{full_path}"
              
          elsif req.host() == "localhost"
          #ファイルリンクをクリックした場合(Ajaxによるリンククリックに対する返信)
            header["Content-Type"] = "text/plain;charset=utf-8"
            response = "Did not find file: #{full_path}"
          else
          #ファイルリンクをクリックした場合(通常のリンククリックに対する返信)
            header["Content-Type"] = "text/html;charset=utf-8"
            response  = %Q|<html><script type="text/javascript">\n|
            response << %Q|alert("#{full_path.gsub(/\\/,"/")}はリンク切れです。\\n上記のファイル名又はフォルダ名に「?」が含まれているときは、ファイル名に「‣」などの機種依存文字を使用していることが「リンク切れ」と表示される原因です。その場合はエクスプローラで元のファイルの名称を修正し、それからリンクを修正してください。");\n|
            response << %Q|history.back();\n|
            response << %Q|</script></html>|
          end
    end
    [
      200, 
       header,
      [
         #env.keys.sort.map {|k| "#{k} = #{env[k]}\n" }.join
         response
      ]
    ]
  end
  
  def get_dir_used_last_time(mode)
    case mode
      when :filepicker    ; file = __dir__+"/defaultdir.txt"
      when :folderpicker  ; file = __dir__+"/defaultdir2.txt"
    end
    if File.exist? file
      path = File.read(file, :encoding => 'utf-8')
      puts path
    else
      path = get_mydocument
    end
    path
  end
  
  def record_dir_of_selected(file)
    File.write(__dir__+"/defaultdir.txt",file.sub(/\\[^\\]*$/,""))
  end

  def return_binary_data(full_path,filename)
    header = Hash.new
    header["Content-Type"] = get_type(filename)
    header["Content-Disposition"] = 
      get_disposition(filename) + "filename=\"#{filename}\""
    header["Expires"] = "0"
    header["Cache-Control"] = "must-revalidate, post-check=0,pre-check=0"
    header["Pragma"] = "private"
    response = nil
    open(full_path,"rb") do |fp|
      header["Content-Length"] = fp.stat.size.to_s
      response = fp.read
    end
    [header,response]
  end

  def open_file_directly(path)
    header = Hash.new
    #ary = get_hwnd_of_all_windows
    sh=WIN32OLE.new("WScript.Shell")
    sh.run %Q|"#{path}" , 3, false|
    filename = File.basename(path)
    #set_new_window_foreground(ary,filename)
    set_foreground_window_by_filename(filename, :maximize)
    header["Content-Type"] = "text/html;charset=utf-8"
    response = %Q|<html><script type="text/javascript">history.back()</script></html>|
    [header,response]
  end
  
  def return_modified_html(full_path)
    target_html = File.read(full_path)
    str   = target_html.match(/<(body|html).*?>(.*)<\/(body|html)>/m)[2]
    puts str
    str.gsub!(/href ?\= ?['"](.*?)['"]/){|w|
      url=$1
      if url.match(/^http/)
        w
      elsif url.match(/^([a-zA-Z]|\/\/|\\\\)/)
        %Q|href="dl.cgi?#{uri_encode(url.gsub(/\\/,"/"))}"|
      elsif url.match(/^\.\//)
        path = File.dirname(full_path)+"/"+url[1..-1].gsub(/\\/,"/")
        %Q|href="dl.cgi?#{uri_encode(path)}"|
      elsif url.match(/^\.\.\//)
        path = Pathname(File.dirname(full_path)+"/"+url.gsub(/\\/,"/")).cleanpath.to_s
        %Q|href="dl.cgi?#{uri_encode(path)}"|
      else
        w
      end
    }
    html = File.read(__dir__+"/template/folder.html")
    puts html
    html.sub!(/<!--contents-->/,str)
    response = html
    header = Hash.new
    header["Content-Type"] = "text/html;charset=utf-8"
    [header,response]
  end

  def open_dir_by_explorer(path)
    header = Hash.new
    #explorer_title = File.basename(path)
    explorer_title = path.match(/.*(\\|\/)(.*)/)[2]
    hwnd = find_window(explorer_title)
    if hwnd>0
      set_foreground_window(hwnd,:restore)
      thread = nil
    else
      sh=WIN32OLE.new("WScript.Shell")
      sh.run "C:/Windows/Explorer.exe #{path} , vbNormalFocus, false"
      thread = Thread.new{set_foreground_window_by_filename(explorer_title,:normal)}
      thread.join
    end
    header["Content-Type"] = "text/plain;charset=utf-8"
    response = "directly open on the server side"
    [header,response]
  end
   
  def open_dir_on_browser(path, called_script, post_data=nil)
    header = Hash.new
    if called_script=="/dl.cgi"
      num = Dir.glob(path.gsub(/\\/,"/")+"/*").size
      header["Content-Type"] = "text/plain;charset=utf-8"
      if num > 50
        response = "This dir includes many files"
      else
        response = "This dir does not include so many files"
      end
    
    elsif called_script=="/dir.cgi"
      if is_newer_head_of_00default
        save_new_template
      end
      files = Dir.glob(path.gsub(/\\/,"/")+"/*").sort
      num=files.size
      if num<=NUM
        ary = files.sort.map{|f| s=File.stat(f);[f,File.basename(f),s.size,s.mtime]}
        str = %Q|<div class="shared-folder a-col">ファイル名</div><div class="shared-folder b-col">サイズ</div>更新日時<br>\n|
      else  
        ary = files.sort.map{|f| [f,File.basename(f)]}
        str = %Q|<div class="shared-folder a-col">ファイル名</div><br>\n|
      end
      len   = ary.map{|d| d[1].bytesize}.max
      ary.each do |d|
         str << %Q|<div class="shared-folder a-col">|
         str << %Q|<a href="/dl.cgi?#{uri_encode(d[0])}" class="mylink">#{d[1]}</a>|
         str << %Q|</div>|
         str << %Q|<div class="shared-folder b-col">#{d[2] ? d[2]:""}</div>|
         str << %Q|#{d[3] ? d[3]:""}<br>\n|
      end
      html = File.read(__dir__+"/template/folder.html")
      html.sub!(/<!--path-->/,path_to_link(path.gsub(/\\/,"/")))
      html.sub!(/<!--contents-->/,str)

      header["Content-Type"] = "text/html;charset=utf-8"
      response = html
    end
    [header,response]
  end

  def get_type(filename)
    case filename.match(/\.\w+$/)[0].downcase
      when ".html"         ;  "text/html"
      when ".css"          ;  "text/css"
      when ".pdf"          ;  "application/pdf"
      when ".txt"          ;  "text/plain"
      when ".csv"          ;  "text/csv"
      when ".doc"          ;  "application/msword"
      when ".xls"          ;  "application/vnd.ms-excel"
      when ".docx"         ;  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
      when ".xlsx"         ;  "application/vnd.openxmlformats-officedocument.spleadsheetml.sheet"
      when ".png"          ;  "image/png"
      when ".jpg","jpeg"   ;  "image/jpeg"
      when ".gif"          ;  "image/gif"
      when "json"          ;  "application/json"
      else                 ;  "application/octet-stream"
    end
  end
  
  def get_disposition(filename)
    case filename.match(/\.\w+$/)[0].downcase
      when  ".html"        ;  "inline;"
      when  ".pdf"         ;  "inline;"
      when  ".txt"         ;  "attachment; "
      when  ".csv"         ;  "attachment;"
      when  ".doc"         ;  "attachment;"
      when  ".xls"         ;  "attachment;"
      when  ".docx"        ;  "attachment;"
      when  ".xlsx"        ;  "attachment;"
      when  ".jpg","jpeg"  ;  "inline;"
      when  ".png"         ;  "inline;"
      when  ".gif"         ;  "inline;"
      else                 ;  "attachment;"
    end
  end
  
  def decode_alias(str)
    re1 = /^\/*(mydoc|documents)/i
    re2 = /^\/*siryo/i
    re3 = /^\/*image/i
    if str.match(re1)
      str.sub(re1,get_mydocument)
    elsif str.match(re2)
      str.sub(re2,SIRYO)
    elsif str.match(re3)
      str.sub(re3,IMAGE)
    else
      str
    end
  end

  def uri_encode(str)
    CGI.escape(str).sub(/%3F/,'?').sub(/%3A/,':').gsub(/\+/,'%20').gsub(/%5C/,'/').gsub(/%2F/,'/')
  end

  def uri_decode(str)
    CGI.unescape(str)
  end

  def path_to_link(path)
    dir_array  = path.split(/(?<!\/)\/(?!\/)/)
    link_array = []
    (1..dir_array.size).each do |i|
      link_array << %Q|<a href="dl.cgi?#{uri_encode(dir_array.slice(0,i).join('/'))}" class="mylink">#{dir_array[i-1].sub('//','&#165;&#165;')}</a>|
    end
    link_array.join('&#165;')
  end

  def get_mydocument
    unless $mydoc_path
      wsh = WIN32OLE.new('WScript.Shell')
      $mydoc_path = wsh.SpecialFolders('MyDocuments').toutf8.gsub("\\","/")
      wsh=nil
    end
    $mydoc_path
  end

  def is_newer_head_of_00default
    scriptfile      = "c:/hiki/lib/hiki/plugin/00default.rb"
    template  = "c:/hiki/template/folder.html"
    return File.stat(scriptfile).mtime > File.stat(template).mtime
  end

  def save_new_template
    template=__dir__+"/template/folder.html"
    require "open-uri"
    s = open("http://localhost:9292").read
    head = s.match(/<head>.*<\/head>/m)[0]
    html =  "<!DOCTYPE html>\n"
    html <<  "<html lang=\"ja\">\n"
    html << head
    html << "<body>"
    html << "<h2><!--path--></h2>"
    html << "<!--contents-->"
    html << "</body>"
    html << "</html>"
    File.write(template,html)
  end

  #Thunderbirdで受信したファイル名に不正な文字U+FFFDが入ることがあるので除去する.
  #(FileDialogで取得したファイル名では"?"に置き換えられている場合がある。)
  #また、iPadから送信したファイル名の濁音・半濁音が独立文字となっている場合にリンクエラーになるので、通常の濁音・半濁音付き文字に置き換える。
  def correct_file_name(file_names)
    file_names.map!{|file| file.toutf8}

    #保存フォルダ内のファイル名を変更
    dir = File.dirname(file_names[0].gsub(/\\/,"/"))
    Dir.glob(dir+"/*").each do |file|
      file2  = file.gsub(/#{0xFFFD.chr("utf-8")}/,"")
      File.rename(file, file2) unless file==file2
      file3  = file2.gsub(/(.)[゛ﾞ]/){|w|
                 $1.tr('か-とは-ほカ-トハ-ホウ', 'が-どば-ぼガ-ドバ-ボヴ')
               }.gsub(/(.)[゜ﾟ]/){|w|
                 $1.tr('は-ほハ-ホ', 'ぱ-ぽパ-ポ')
               }
      File.rename(file2, file3) unless file2==file3
    end

    #FileDialogで取得したファイル名を変更
    file_names.map! do |file|
      file2 = file.gsub(/\?|#{0xFFFD.chr("utf-8")}/,"")
      file3 = file2.gsub(/(.)[゛ﾞ]/){|w|
                  $1.tr('か-とは-ほカ-トハ-ホウ', 'が-どば-ぼガ-ドバ-ボヴ')
                }.gsub(/(.)[゜ﾟ]/){|w|
                  $1.tr('は-ほハ-ホ', 'ぱ-ぽパ-ポ')
                }
      file3
    end
  end

  def p_req_heder(req)
    req.env.each{ |k, v| p k + + " => " + v.to_s}
  end

  #ファイル/フォルダ選択ダイアログがタイムアウトしたときの処理
  def close_window(title)
    #Alt+F4で閉じる。
    whnd = find_window(title)
    set_foreground_window(whnd)
    sleep(0.1)
    key_alt_f4
    #Alt F4で閉じていないときはプロセスを強制終了する。
    p :kill_remote
    wmi = WIN32OLE.connect('winmgmts://')
    process_set = wmi.ExecQuery("select * from Win32_Process where CommandLine like '%EXCEL.EXE\" /automation%'")
    process_set.each do |item|
      pid = item.ProcessId
      p item.CommandLine
      p pid
      `taskkill /f /pid #{pid}`
    end
  end
  #ドラッグ＆ドロップ元のエクスプローラーで表示しているフォルダのパスを取得
  def get_explorer_location(files)
    
    def get_full_paths(files,location)
      full_paths = []
      path = location.toutf8.sub(/file\:\/\/\//,"").sub(/file\:/,"")
      files.each do |f|
        if File.exist? path+"/"+f
          full_paths << (path+"/"+f.toutf8).gsub(/\//,"\\")
        end
      end
      if files.size == full_paths.size
        full_paths
      else
        nil
      end
    end

    # エクスプローラのWindowハンドルの配列を作成する.
    explrs = Hash.new
    app=WIN32OLE.new('Shell.Application')
    app.windows.each do |w|
      explrs[w.hwnd] = w.LocationURL if w.name.toutf8=='エクスプローラー'
    end

    #最前面のウインドウがエクスプローラーだったらその表示URLを返す。
    hwnd = get_foreground_window
    if explrs.keys.include? hwnd
      if full_paths = get_full_paths(files,explrs[hwnd])
        return full_paths
      else
        explrs.delete(hwnd)
      end
    end

    #２番目のウインドウがエクスプローラーだったらその表示URLを返す。
    hwnd = get_hwnd_of_2nd_window
    if explrs.keys.include? hwnd
      if full_paths = get_full_paths(files,explrs[hwnd])
        return full_paths
      else
        explrs.delete(hwnd)
      end
    end

    #それ以外のエクスプローラのウインドウからドラッグされた可能性を調べる。
    if explrs.keys.size>0
      explrs.each do |k,v|
        if full_paths = get_full_paths(files,v)
          return full_paths
        end
      end
    end

    #エクスプローラーではなかったらデスクトップのURLを返す。
    wsh = WIN32OLE.new('WScript.Shell')
    path = wsh.SpecialFolders('Desktop')
    if full_paths = get_full_paths(files,path)
      return full_paths
    else
      nil
    end
  end
end
