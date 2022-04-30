# Copyright (C) 2002-2003 TAKEUCHI Hitoshi <hitoshi@namaraii.com>

require "hiki/util"
require "hiki/pluginutil"
require "hiki/interwiki"
require "hiki/aliaswiki"
require "hiki/formatter"
require "uri"


module Hiki
  module Formatter
    class Default < Base
      Formatter.register(:default, self)

      include Hiki::Util

      def initialize(s, db, plugin, conf, prefix = "l")
        @html       = s
        @db         = db
        @plugin     = plugin
        @conf       = conf
        @prefix     = prefix
        @references = []
        @interwiki  = InterWiki.new(@db.load(@conf.interwiki_name))
        @aliaswiki  = AliasWiki.new(@db.load(@conf.aliaswiki_name))
        get_auto_links if @conf.auto_link
      end

      def analize(s,num)
      #"C:\hiki\keika1.txt"などを保存する.
        res = s.scan(/【start】.*?【end】/m)
        if res.size>0
          str = res.join("\n\n")
          File.write("C:\hiki\keika#{num.to_s}.txt",str)
        end
      end

      def to_s #inuzuka ※行を付加,※※行を移動,analize付加.
        frg = nil #動作解析する.=> :do                   
        s = @html                                      ;analize(s,1)  if frg == :do
        s = replace_local_link( s, 1 )                 ;analize(s,2)  if frg == :do #※
        s = replace_link(s)                            ;analize(s,3)  if frg == :do
        s = replace_auto_link(s) if @conf.auto_link    ;analize(s,4)  if frg == :do
        s = replace_heading(s)                         ;analize(s,5)  if frg == :do
        s = replace_plugin(s) if @conf.use_plugin      ;analize(s,6)  if frg == :do
        s = replace_local_link( s, 2 ,frg)             ;analize(s,7)  if frg == :do #※
        s = make_to_top_page( s )                      ;analize(s,8)  if frg == :do #※
        s = replace_local_image_link( s ,frg)          ;analize(s,9)  if frg == :do #※
        s = replace_inline_image(s)                    ;analize(s,10) if frg == :do #※※
        s = replace_bbs_div(s)                         ;analize(s,11) if frg == :do #※
        s = replace_comment_span(s)                    ;analize(s,12) if frg == :do #※
        s = enable_indent_pre(s)                       ;analize(s,12) if frg == :do #※
        @html_converted = s
        s
      end

      def references
        @references.uniq
      end

      HEADING_RE = %r!<h(\d)>.*<a name="l\d+">.*?</a>(.*?)</h\1>!
      TAG_RE = %r!(<.+?>)!

      unless defined? SIRYO
        eval(File.open("hikiconf.rb"){|f| f.read })
        SIRYO = @siryo_path
        IMAGE = @image_path
      end

      def toc
        s = "<ul>\n"
        num = -1
        level = 1
        to_s unless @html_converted
        @html_converted.each_line do |line|
          if HEADING_RE =~ line
            new_level = $1.to_i - 1
            num += 1
            title = $2.gsub(TAG_RE, "").strip
            if new_level > level
              s << ("<ul>\n" * (new_level - level))
              level = new_level
            elsif new_level < level
              s << ("</ul>\n" * (level - new_level))
              level = new_level
            end
            s << %Q!<li><a href="\#l#{num}">#{title}</a></li>\n!
          end
        end
        s << ("</ul>\n" * level)
        s
      end

      private

      def replace_local_link( text, x ,frg=:no)   # 2020.5.24 inuzuka
        if x==1  # ローカルリンクを待避する。
          text.gsub( /<a href=\"((\\\\|[a-z]:|Mydoc|Documents|siryo|image).+?)\">(.*?)<\/a>/i ) do |str|
              "<escX>#{$1}<escY>#{$3}<escZ>"
          end
        elsif x==2  #自動的にローカルリンクを作成し、また、待避したローカルリンクを復元する。
          re1 = /<escX>(.+?)<escY>(.+?)<escZ>/
          re2 = /&lt;(image.+?)&gt;/
          re3 = /&lt;(siryo.+?)&gt;/
          re4 = /<img src\="(\\\\)?([^<^\]]+?)(?=[\s　]{2,}|$|<|\])/
          re5 = /\\\\([^<^\]]+?)(?=[\s　]{2,}|$|<|\])/
          re6 = /(dl)?[a-zA-Z]:\\.+?(?=[\s　]{2,}|$|<|\])/
          re  = Regexp.union(re1,re2,re3,re4,re5,re6) 
          text.gsub(re) do |str|
            if $&[0,9]=="&lt;image"     #<image/ >はこの段階はスルーする.
              $&
            elsif $&[0,8]=="<img src" 
              img  = $&
              path = img.match(/src\="([^"]*?)"/)[1]
              mdified_path = modify_alias(path)
              mdified_disp = File.basename(path)
              %Q|<img src="#{uri_encode(mdified_path)}" alt="#{mdified_disp}">|
            else
              if $&[0,6]=='<escX>'
                path,disp = $1,$2
                disp = disp
                path = modify_alias(path,frg)
              elsif $&[0,9]=='&lt;siryo' or $&[0,11]=='&lt;dlsiryo'
                str  = $4
                disp = modify_disp(str  ,frg)
                path = modify_alias(str ,frg)
              else
                str = $&
                disp = modify_disp(str  ,frg)
                path = modify_alias(str ,frg) 
              end
              %Q|<a href="#{uri_encode(path)}" class="mylink">#{disp}</a>|
            end
          end
        end
      end
      
      def modify_disp(str,frg=:no)  #2020.7.24 inuzuka
        if frg == :do
          #p "modify_disp"
          #p "0 => " + str
        end
        s = str.sub(/^[\\\/]*(Mydoc|Documents)/i,'Mydoc')           ;p "1 => "+s if frg ==:do  
        s.sub!(/^[\\\/]*siryo(?=[\\\/]|$)/i,SIRYO)                  ;p "2 => "+s if frg ==:do 
        s.sub!(/^[\\\/]*([a-zA-Z]:[\\\/])/,'\1')                    ;p "4 => "+s if frg ==:do  
        s.gsub!(/^[\\\/]*([^?:\.]+?)(?=[\\\/]|$)/,'&#165;&#165;\1') ;p "5 => "+s if frg ==:do
        s.gsub!(/[\\\/]/,'&#165;')                                  ;p "6 => "+s if frg ==:do
        s 
      end

      def modify_alias(str,frg=:no)  #2020.7.24 inuzuka
        if frg == :do
          #p "modify_alias" 
          #p "0 => " + str
        end 
        s = str
        #@old_user_documents.each_with_index{|path,i|
        #  s.sub!(/#{path.gsub(/\\/,"\\\\\\\\")}/i,@backup_path[i])
        #}
        s.sub!(/^C:.Users.*Documents/i,'Mydoc')                  ;p "1 => "+s if frg == :do 
        s.sub!(/^[\\\/]*(Mydoc|Documents)(?=[\\\/]|$)/i,'\1')    ;p "3 => "+s if frg == :do 
        s.sub!(/^[\\\/]*siryo(?=[\\\/]|$)/i, SIRYO)              ;p "4 => "+s if frg == :do 
        s.sub!(/^[\\\/]*image\**(?=[\\\/]|$)/i, IMAGE)           ;p "5 => "+s if frg == :do 
        s.sub!(/^[\\\/]*([a-zA-Z]:[\\\/])/i,'dl.cgi?\1')         ;p "7 => "+s if frg == :do 
        s.sub!(/^[\/\\]*([^?:\.]+?)(?=[\\\/]|$)/i,'dl.cgi?//\1') ;p "8 => "+s if frg == :do 
        s.gsub!(/\\/,'/')                                        ;p "9 => "+s if frg == :do
        s
      end

      def uri_encode(str)
        #CGI.escapeでは半角スペースが '+' に変換される。
        #URI.escapeでは半角スペースが '%20' に変換される。
        # '+'だとIEではリンク切れになる。
        CGI.escape(str).gsub(/%3F/,'?').gsub(/%3A/,':').gsub(/%5C/,'/').gsub(/%2F/,'/').gsub('+','%20')
        #URI.escape(str).gsub(/%3F/,'?').gsub(/%3A/,':').gsub(/%5C/,'/').gsub(/%2F/,'/')
      end

      def uri_decode(str)
        CGI.unescape(str)
      end

      def make_to_top_page( text )   # 2007.12.26 inuzuka
        text.gsub( %r!<h\d?>(|<.*?>)<a name=! ) do |str|
            %Q|<p class="top-link"><a href="#top">TOP</a></p>#{$&}|
        end
      end
  
      def replace_local_image_link(text,frg=:no)
      #inuzuka 「 <image/xxxx.jpg> 」imageフォルダのxxxx.jpgを表示
      #        「 <image***/xxxx.jpg> 」imageの後の"*"で表示サイズを変更.
      #        「 <image***//Mydoc/2020/07/xxxx.jpg> 」 "//"で区切ることで任意のフォルダを指定可能.
        text.gsub(/&lt;(image(\**\/+)([^$]*?\.(jpg|jpeg|gif|png|bmp)))&gt;/i) do |str|
          s = $2.delete("*").size==1 ? $1 : $3
          disp = modify_disp(s)
          path = uri_encode(modify_alias( s ,frg))
          size = case $2.delete("/").size
                 when 0 ; "auto"
                 when 1 ;   "50"
                 when 2 ;  "100"
                 when 3 ;  "150"
                 when 4 ;  "200"
                 when 5 ;  "300"
                 when 6 ;  "400"
                 when 7 ;  "500"
                 when 8 ;  "600"
                 when 9 ;  "800"
                 when 10; "1000"
                 end
          %Q|<a href="#{path}"><img src="/#{path}" width="#{size}" alt="#{disp}"></a>|
        end
      end

      def enable_indent_pre(text) 
      #inuzuka 引用表記にインデントを設定する「 **<<<・・・>>> 」の記法を付加
        #text.gsub(%r|.*?<ul>\n(<li><ul>\n)*<li>&lt;&lt;&lt;</li>\n(</ul></li>\n)*</ul>[\s\S]*?&gt;&gt;&gt;</p>|) do |ans|
        #  disp_str = ans.match(%r|[\s\S]*</ul>([\s\S]*?)&gt;&gt;&gt;</p>|)[1].gsub("<p>","").gsub("</p>","\n")
        #  indent   = ans.scan(%r|<li><ul>|).size
        #  "<pre class=\"pre#{indent+1}\">#{disp_str}</pre>"
        #end
        lt = "<li>&lt;&lt;&lt;</li>\n"
        gt = "&gt;&gt;&gt;</p>"
        middle_end_ul = "</ul></li>\n"
        end_ul = "</ul>\n"
        text.gsub!(%r|^(<ul>\n([\s\S]*?)#{lt}((#{middle_end_ul})*#{end_ul}))([\s\S]*?)#{gt}|) do |str|
          part1 = $1
          part2 = $2
          part3 = $3
          part5 = $5
          if part2.gsub(%r!<ul>|<li>|\n!,"").size > 0
            itemizing = part1.sub(%r|#{lt}|,"")
          else
            itemizing = ""
          end
          level = part3.scan(%r|</ul>|).size
          if level > 0
            pre_tag = "<pre class=\"pre#{level}\">\n"
          else
            pre_tag = "<pre>"
          end
          pre_content = part5.gsub("<p>","").gsub("</p>","\n")
          itemizing + pre_tag + pre_content + "</pre>"
        end
        text
      end

      def replace_inline_image(text)
        text.gsub(/<a href="([^"]+\.(jpg|jpeg|gif|png|bmp))".*?>(.+?)<\/a>/i) do |str|
          if $3[0,9]=="<img src="
            str
          else
            %Q|<img src="#{$1}" alt="#{$3.sub(/.*&#165;/,"")}">|
          end
        end
      end

      def replace_auto_link(text)
        return text if @auto_links.empty?
        replace_inline(text) do |str|
          str.gsub!(@auto_links_re) do |match|
            @plugin.hiki_anchor(escape(unescape_html(@auto_links[match])), match)
          end
        end
      end

      PLUGIN_OPEN_RE = /<(span|div) class="plugin">/
      PLUGIN_CLOSE_RE = %r!</(span|div)>!
      LINK_OPEN_RE = /<a .*href=/
      LINK_CLOSE_RE = %r!</a>!
      PRE_OPEN_RE = /<pre>/
      PRE_CLOSE_RE = %r!</pre>!

      def replace_inline(text)
        status = []
        ret = text.split(TAG_RE).collect do |str|
          case str
          when PLUGIN_OPEN_RE
            status << :plugin
          when LINK_OPEN_RE
            status << :a
          when PRE_OPEN_RE
            status << :pre
          when PLUGIN_CLOSE_RE, LINK_CLOSE_RE, PRE_CLOSE_RE
            status.pop
          when TAG_RE
            # do nothing
          else
            if status.empty?
              yield(str)
            end
          end
          str
        end
        ret.join
      end

      URI_RE = /\A#{URI::DEFAULT_PARSER.make_regexp(%w( http https ftp file mailto ))}\z/ 

      def replace_link(text)
        text.gsub(%r|<a href="(.+?)">(.+?)</a>|) do |str|
          k, u = $2, $1
          if URI_RE =~ u # uri
            @plugin.make_anchor(u, k, "external")
          else
            u = unescape_html(u)
            u = @aliaswiki.aliaswiki_names.key(u) || u # alias wiki
            #if /(.*)(#l\d+)\z/ =~ u
            if /(.*)(#(\d|\w|[^\x01-\x7e])+)\z/ =~ u    #inuzuka 2020.7.20, 全角文字にも対応
              u, anchor = $1, $2
            else
              anchor = ""
            end
            if @db.exist?(u) # page name
              k = @plugin.page_name(k) if k == u
              @references << u
              if u.empty?
                @plugin.make_anchor(anchor, k)
              else
                @plugin.hiki_anchor(escape(u) + anchor, k)
              end
            elsif orig = @db.select{|i| i[:title] == u}.first # page title
              k = @plugin.page_name(k) if k == u
              u = orig
              @references << u
              @plugin.hiki_anchor(escape(u) + anchor, k)
            elsif outer_alias = @interwiki.outer_alias(u) # outer alias
              @plugin.make_anchor(outer_alias[0] + anchor, k, "external")
            elsif /:/ =~ u # inter wiki ?
              s, p = u.split(/:/, 2)
              if s.empty? # normal link
                @plugin.make_anchor(h(p) + anchor, k, "external")
              elsif inter_link = @interwiki.interwiki(s, unescape_html(p), "#{s}:#{p}")
                @plugin.make_anchor(inter_link[0], k, "external")
              else
                missing_page_anchor(k, u)
              end
            else
              missing_page_anchor(k, u)
            end
          end
        end
      end

      def missing_page_anchor(k, u)
        if @plugin.creatable?
          missing_anchor_title = @conf.msg_missing_anchor_title % [h(u)]
          "#{k}<a class=\"nodisp\" href=\"#{@conf.cgi_name}?c=edit;p=#{escape(u)}\" title=\"#{missing_anchor_title}\">?</a>"
        else
          k
        end
      end

      BLOCKQUOTE_OPEN_RE = /<blockquote>/
      BLOCKQUOTE_CLOSE_RE = %r!</blockquote>!
      HEADING_OPEN_RE = /<h(\d)>/
      HEADING_CLOSE_RE = %r!</h\d>!

      def replace_heading(text)
        status = []
        num = -1
        ret = text.split(TAG_RE).collect do |str|
          case str
          when BLOCKQUOTE_OPEN_RE
            status << :blockquote
          when BLOCKQUOTE_CLOSE_RE
            status.pop
          when HEADING_OPEN_RE
            unless status.include?(:blockquote)
              num += 1
              level = $1.to_i
              status << level
              case level
              when 2
                str << %Q!<span class="date"><a name="#{@prefix}#{num}"> </a></span><span class="title">!
              when 3
                str << %Q!<a name="#{@prefix}#{num}"><span class="sanchor"> </span></a>!
              else
                str << %Q!<a name="#{@prefix}#{num}"> </a>!
              end
            end
          when HEADING_CLOSE_RE
            unless status.include?(:blockquote)
              level = status.pop
              str = "</span>#{str}" if level == 2
            end
          end
          str
        end
        ret.join
      end

      def replace_plugin(text)
        text.gsub(%r!<(span|div) class="plugin">\{\{(.+?)\}\}</\1>!m) do |str|
          tag, plugin_str = $1, $2
          begin
            case tag
            when "span"
              result = @plugin.inline_context{ apply_plugin(plugin_str, @plugin, @conf) }
            when "div"
              result = @plugin.block_context{ apply_plugin(plugin_str, @plugin, @conf) }
            end
            result.class == String ? result : ""
          rescue Exception => e
            $& + e.message
          end
        end
      end

      def replace_bbs_div(s)
        s.gsub(/\$\${/, '<div class="bbs">').gsub(/\$\$}/, '</div>')
      end

      def replace_comment_span(s)
        s.gsub(/&lt;span class="blue"&gt;(.*?)&lt;\/span&gt;/) do |w|
          '<span class="blue">'+$1+'</span>'
        end
      end

      def get_auto_links
        pages = {}
        @db.pages.each do |p|
          page_h = escape_html(p)
          pages[page_h] = page_h
          title_h = @plugin.page_name(p).gsub(/&quot;/, '"')
          pages[title_h] = page_h unless title_h == page_h
        end
        @aliaswiki.aliaswiki_names.each do |key, value|
          orig_h = escape_html(key)
          alias_h = escape_html(value)
          pages[alias_h] = orig_h
        end
        @auto_links_re = Regexp.union(*pages.keys.sort_by{|i| -i.size})
        @auto_links = pages
      end

      def escape_html(text)
        text.gsub(/&/, "&amp;").
          gsub(/</, "&lt;").
          gsub(/>/, "&gt;")
      end

    end
  end
end
