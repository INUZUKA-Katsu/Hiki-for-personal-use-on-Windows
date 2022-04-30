require "hiki/repository/base"
require "fileutils"

module Hiki
  module Repository
    class Plain < Base
      include Hiki::Util

      Repository.register(:plain, self)

      def commit(page, log = nil)
        wiki = File.read("#{@data_path}/text/.wiki")

        dir = "#{@root}/#{wiki}/#{escape(page)}"

        Dir.mkdir(dir) if not File.exist?(dir)
        FileUtils.rm("#{dir}/.removed", {force: true})

        rev = last_revision(page) + 1

        FileUtils.cp("#{@data_path}/text/#{escape(page)}", "#{dir}/#{rev}")
      end

      # This is a utility method for command line tools
      def commit_with_content(page, content, log = nil)
        escaped_page = escape(page)
        wiki = File.read(File.join(@data_path, "text", ".wiki"))
        dir = File.join(@root, wiki, escaped_page)
        revision = last_revision(page) + 1
        page_path = File.join(@data_path, "text", escaped_page)
        FileUtils.mkdir_p(dir)
        FileUtils.rm_f(File.join(dir, ".removed"))

        File.open(page_path, "w+") do |file|
          file.write(content)
        end
        FileUtils.cp(page_path, File.join(dir, revision.to_s))
      end

      def delete(page, log = nil)
        wiki = File.read("#{@data_path}/text/.wiki")
        File.open("#{@root}/#{wiki}/#{escape(page)}/.removed", "w"){|f|}
      end

      def rename(old_page, new_page)
        wiki = File.read("#{@data_path}/text/.wiki")
        old_dir = "#{@root}/#{wiki}/#{escape(old_page)}"
        new_dir = "#{@root}/#{wiki}/#{escape(new_page)}"
        raise ArgumentError, "#{new_page} has already existed." if File.exist?(new_dir)
        FileUtils.mv(old_dir, new_dir)
      end

      def get_revision(page, revision)
        wiki = File.read("#{@data_path}/text/.wiki")
        File.read("#{@root}/#{wiki}/#{escape(page)}/#{revision.to_i}")
      end

      def revisions(page)
        wiki = File.read("#{@data_path}/text/.wiki")
        revs = []
        Dir.glob("#{@root}/#{wiki}/#{escape(page)}/*").each do |file|
          revs << [File.basename(file).to_i, File.mtime(file).localtime.to_s, "", ""]
        end
        revs.sort_by{|e| -e[0]}
      end


      private

      def last_revision(page)
        wiki = File.read("#{@data_path}/text/.wiki")
        Dir.glob("#{@root}/#{wiki}/#{escape(page)}/*").map{|f| File.basename(f)}.sort_by{|f| -f.to_i}[0].to_i
      end
    end
  end
end
