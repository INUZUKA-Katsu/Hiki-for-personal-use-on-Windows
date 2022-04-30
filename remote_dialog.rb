#coding:utf-8
require 'kconv'
require 'drb/drb'
require 'win32ole'
require __dir__+'/wincontrol'

begin
  WIN32OLE.const_load('Microsoft Office 14.0 Object Library')
  FilePicker   = WIN32OLE::MsoFileDialogFilePicker
  FolderPicker = WIN32OLE::MsoFileDialogFolderPicker
rescue
  FilePicker   = 3
  FolderPicker = 4
end

class Dialog
	def host
		return [Socket.gethostname,Process.pid]
	end
	def get_select_files_or_folder(title)
		p :Excel_start
		begin
			@xl = WIN32OLE.connect('Excel.Application')
			xl_status = :visible if @xl.visible==true
		rescue
			@xl = WIN32OLE.new('Excel.Application')
		end
		@xl.visible = false
		if title == "Select Files"
			dialog = @xl.FileDialog(FilePicker)
			dialog.InitialFileName = get_dir_used_last_time(:filepicker)
			dialog.AllowMultiSelect = -1
			dialog.Title = title
			begin
				if dialog.Show==-1
					ans=[]
					(1..dialog.SelectedItems.count).each do |i|
						ans << dialog.SelectedItems(i)
					end
				else
					ans = nil
				end
			#タイムアウトでExcelが強制終了されたときに発生する例外を処理する。
			rescue
				ans = nil
			end
		elsif title == "Select Folder"
			p :get_select_folder
			dialog = @xl.FileDialog(FolderPicker)
			dialog.Title = title
			dialog.InitialFileName = get_dir_used_last_time(:folderpicker)
			if dialog.Show==-1
				ans = [ dialog.SelectedItems(1) ]
			else
				ans = nil
			end
		end
		@xl.visible = true if defined?(xl_status) and xl_status == :visible
		ans
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
    def get_mydocument
      unless $mydoc_path
        wsh = WIN32OLE.new('WScript.Shell')
        $mydoc_path = wsh.SpecialFolders('MyDocuments').gsub("\\","/")
        wsh=nil
      end
      $mydoc_path
    end
end

DRb.start_service(nil,Dialog.new)
File.write(__dir__+"/drb_uri.txt", DRb.uri)
puts DRb.uri
DRb.thread.join
