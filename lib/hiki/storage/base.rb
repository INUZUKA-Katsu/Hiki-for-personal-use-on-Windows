# Copyright (C) 2002-2003 TAKEUCHI Hitoshi <hitoshi@namaraii.com>

require "digest/md5"
require "hiki/util"

module Hiki
  module Storage
    class Base
      attr_accessor :text
      include Hiki::Util
      def open_db
        if block_given?
          yield
          close_db
        else
          true
        end
        true
      end

      def close_db
        true
      end

      def pages
        ["page1", "page2", "page3"]
      end

      def backup(page)
        @text = load(page) || ""
      end

      def delete(page)
        backup(page)
        unlink(page)
        delete_cache(page)
        begin
          send_updating_mail(page, "delete", text) if @conf.mail_on_update
        rescue
        end
      end

      def md5hex(page)
        s = load(page)
        Digest::MD5.hexdigest(s || "")
      end

      def search(w)
        result  = []
        keys    = w.split
        p       = pages
        total   = pages.size

        page_info.sort_by {|e| e.values[0][:last_modified]}.reverse_each do |i|
          page = i.keys[0]
          info = i.values[0]
          keyword  = info[:keyword]
          title    = info[:title]
          status   = ""
          keyNum   = 0            # inuzuka

          keys.each do |key|
            keyNum    += 1        # inuzuka
            quoted_key = Regexp.quote(key)
            if keyword and keyword.join("\n").index(/#{quoted_key}/i)
              status << @conf.msg_match_keyword.gsub(/\]/, " <strong>#{h(key)}</strong>]")
            elsif title and title.index(/#{quoted_key}/i)
              status << @conf.msg_match_title.gsub(/\]/, " <strong>#{h(key)}</strong>]")
            #elsif load(page).index(/^.*#{quoted_key}.*$/i)
            #  status << "[" + h($&).gsub(/#{Regexp.quote(h(key))}/i) { "<strong>#{$&}</strong>"} + "]"
            # **************　上の２行を以下の15行に差し替え  *************************************
            # オリジナルでは、ページ内で最初にヒットした箇所だけを結果表示していたのを、
            # すべてのヒット箇所を結果表示することとし（ scan の部分）、
            # ヒット箇所の各末尾に、「#1-1,#1-2 ･･･」という形式の一連番号をつけることとした。
            # （+ " ##{$keyNum}-#{x}]<br>" の部分）一連番号は、最終的には該当箇所へのリンクになる。
            # また、結果表示を見やすくするため、[[見出し|URL]]の部分については、原則として、
            # 見出しだけを結果表示することとし、検索語がURLに含まれている場合だけ、URLを含む
            # 全体を結果表示するようにした。
            elsif load_page = load( page ) and load_page.index(/#{quoted_key}/i)
               status_str=""
               x=1
               load_page.scan(/^.*#{quoted_key}.*$/i) do |str|
                 status_str += '[' + h(str).gsub(/\[\[(.*?)(|\|.*?)\]\]/) do
                   if $2.include?("#{quoted_key}")
                     $&
                   else
                     $1
                   end
                 end.gsub(/#{Regexp::quote(h(key))}/i) { "<strong>#{$&}</strong>"} +
                 " ##{keyNum}-#{x}]<br>"
                 x+=1
               end
               status << status_str
            # ********************************************************************************
            else
              status = nil
              break
            end
          end
          result << [page, status] if status
        end

        [total, result]
      end

      def load_cache(page)
        Dir.mkdir(@conf.cache_path) unless test(?e, @conf.cache_path)
        cache_path = "#{@conf.cache_path}/parser"
        Dir.mkdir(cache_path) unless test(?e, cache_path)
        begin
          release_date, tokens = Marshal.load(File.binread("#{cache_path}/#{escape(page)}"))
          if release_date == Hiki::RELEASE_DATE
            return tokens
          else
            return nil
          end
        rescue
          return nil
        end
      end

      def save_cache(page, tokens)
        begin
          File.open("#{@conf.cache_path}/parser/#{escape(page)}", "wb") do |f|
            Marshal.dump([Hiki::RELEASE_DATE, tokens], f)
          end
        rescue
        end
      end

      def delete_cache(page)
        begin
          File.unlink("#{@conf.cache_path}/parser/#{escape(page)}")
        rescue Errno::ENOENT
        end
      end
    end
  end
end
