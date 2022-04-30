#*** coding: utf-8 ***

require 'fiddle/import'
require 'fiddle/types'
require 'timeout'
require 'kconv'


module WIN32API
  extend Fiddle::Importer
  dlload 'C:\\Windows\\System32\\user32.dll'
  include Fiddle::Win32Types
  extern 'HWND GetWindow(HWND,long)'
  GW_HWNDLAST = 1
  GW_HWNDNEXT = 2
  GW_OWNER = 4
  extern 'HWND GetForegroundWindow()'
  extern 'int FindWindow(char *, char *)'
  extern 'int FindWindowEx(HWND, HWND, char *, char *)'
  extern 'int IsWindowVisible(HWND)' 
  TRUE  = 1
  FALSE = 0
  extern 'HWND GetLastActivePopup(HWND)'
  extern 'int GetWindowText(HWND,char*,int)'
  extern 'int GetWindowTextLength(HWND)'
  extern 'int SetForegroundWindow(HWND)'
  extern 'int ShowWindow(HWND, int)'
  SW_SHOWNORMAL = 1 #Windowを起動したとき使う.
  SW_MAXIMIZE = 3
  SW_SHOW = 5  
  SW_RESTORE = 9 #起動済みWindowに使う.
  SW_SHOWDEFAULT = 10
  extern 'DWORD GetWindowThreadProcessId(HWND,UINT)'
  extern 'BOOL BringWindowToTop(HWND)'
  extern 'BOOL AttachThreadInput(UINT,UINT,BOOL)'
  extern 'BOOL PostMessage(HWND,UINT,int,int)'
  extern 'int EnumWindows(void*, int)'
  extern 'void keybd_event(BYTE, BYTE, DWORD, ULONG)'  # sendkey
  BM_CLICK = 0xF5
  extern 'int MessageBox(HWND, char*, char*, UINT)'
  MB_OK                = 0x00000000  # OK
  MB_OKCANCEL          = 0x00000001  # OK, キャンセル
  MB_ABORTRETRYIGNORE  = 0x00000002  # 中止，再試行，無視
  MB_YESNOCANCEL       = 0x00000003  # はい，いいえ，キャンセル
  MB_YESNO             = 0x00000004  # はい，いいえ
  MB_RETRYCANCEL       = 0x00000005  # 再試行，キャンセル
  MB_CANCELTRYCONTINUE = 0x00000006  # キャンセル，再実行，継続
  MB_ICONHAND          = 0x00000010  # エラー
  MB_ICONQUESTION      = 0x00000020  # 問合せ
  MB_ICONEXCLAMATION   = 0x00000030  # 警告
  MB_ICONASTERISK      = 0x00000040  # 情報
  extern 'void *GetWindowInfo(void *,void *)'
  SWindowInfo = struct( [
    'unsigned long cbSize',
    'long rcWindow_left',
    'long rcWindow_top',
    'long rcWindow_right',
    'long rcWindow_bottom',
    'long rcClient_left',
    'long rcClient_top',
    'long rcClient_right',
    'long rcClient_bottom',
    'unsigned long dwStyle', 
    'unsigned long dwExStyle', 
    'unsigned long dwWindowStatus', 
    'unsigned int cxWindowBorders', 
    'unsigned int cyWindowBorders', 
    'unsigned short atomWindowType', 
    'unsigned short wCreatorVersion', 
  ])
  class Rect
    def initialize(left,top,right,bottom)
      @left = left
      @top = top
      @right = right
      @bottom = bottom
    end
    def to_s
      '{'+[@left,@top,@right,@bottom].join(',')+'}'
    end
    attr_reader :left, :top, :right, :bottom
    def width
      return @right - @left
    end
    def height
      return @bottom - @top
    end
    def to_a
      return [@left,@top,width,height]
    end
    def with_left(n)
      @right += (n - @left)
      @left=n
      self
    end
    def with_width(w)
      @right = @left + w
      self
    end
  end
  class WindowInfo
    def initialize(sw)
      @rect = Rect.new(sw.rcWindow_left, sw.rcWindow_top, sw.rcWindow_right, sw.rcWindow_bottom)
    end
    def rect
      @rect
    end
    def to_s
      "rect=#{@rect.to_s}"
    end
  end
end

def get_hwnd_of_2nd_window
  #最前面から2番目のウインドウのhwndを返す。
  top_hwnd  = get_foreground_window
  next_hwnd = WIN32API.GetWindow(top_hwnd,WIN32API::GW_HWNDNEXT)
  ary       = get_hwnd_of_all_windows
  res       = nil
  ary.size.times do
    if ary.include? next_hwnd
      res = next_hwnd
      break
    end
    next_hwnd = WIN32API.GetWindow(next_hwnd,WIN32API::GW_HWNDNEXT)
  end
  res
end
def get_hwnd_of_all_windows
  res=[]
  cb = Fiddle::Closure::BlockCaller.new(Fiddle::TYPE_INT, [Fiddle::TYPE_INT]) do |hwnd|
    if is_visible(hwnd)
      res << hwnd
    end
    -1
  end
  func = Fiddle::Function.new(cb, [Fiddle::TYPE_INT], Fiddle::TYPE_INT)
  WIN32API.EnumWindows(func,0)
  res
end
def is_visible(hwnd)
  if WIN32API.IsWindowVisible(hwnd) ==WIN32API::TRUE  and
       WIN32API.GetWindowTextLength(hwnd)>0
    return true
  else
    return false
  end
end
def get_window_title(hwnd)
  buf_len = WIN32API.GetWindowTextLength(hwnd)
  str = ' ' * (buf_len+1)
  result = WIN32API.GetWindowText(hwnd, str, str.length)
  str.force_encoding("sjis").encode("utf-8")
end
def get_foreground_window
  hwnd = WIN32API.GetForegroundWindow().to_i
  hwnd
end
def find_window(title_str)
  hwnd = WIN32API.FindWindow(nil,title_str.tosjis)
#  puts "WIN32API => " + hwnd.to_s
  if hwnd and hwnd>0
    return hwnd
  else
    title_reg = Regexp.escape(title_str.toutf8)
#    p "title_reg"
#    puts title_reg
    hwnds = get_hwnd_of_all_windows
    hwnds.each do |hwnd|
      title = get_window_title(hwnd).strip
#      puts title
      if title and title!="" and title.match(title_reg)
        p :true
        p hwnd
        return hwnd
      else
#        p :false
      end
    end
  end
  return 0
end
def find_window_ex(parent_hwnd,title_str)
  WIN32API.FindWindowEx(parent_hwnd,0,nil,title_str)
end
def btn_click(parent_hwnd,btn_caption)
  hwnd = find_window_ex(parent_hwnd,btn_caption.encode('sjis'))
  WIN32API.PostMessage(hwnd, WIN32API::BM_CLICK, 0, 0)
end
def set_foreground_window(hwnd,state=nil)
  def done?(hwnd)
    get_foreground_window == hwnd
  end
  WIN32API.SetForegroundWindow(hwnd)
  unless done?(hwnd)
    hwnd_pid = WIN32API.GetWindowThreadProcessId(hwnd,0)
    foreground_pid = WIN32API.GetWindowThreadProcessId(get_foreground_window,0)
    if foreground_pid != hwnd_pid
      WIN32API.AttachThreadInput(hwnd_pid,foreground_pid,1)
      WIN32API.BringWindowToTop(hwnd)
      WIN32API.AttachThreadInput(hwnd_pid,foreground_pid,0)
    end
  end
  WIN32API.ShowWindow(hwnd,win_state(state)) if state != nil
  return done?(hwnd)
end

def set_foreground_window_by_filename(filename,state=nil)
  cnt=0
  is_word_document = ['.doc','.docx'].include? File.extname(filename)
  loop{
    sleep 0.05
    cnt +=1
    #p "cnt => "+cnt.to_s
    if is_word_document
      target_hwnd_pre = find_window("起動しています")
      p "target_hwnd_pre => "+target_hwnd_pre.to_s
      if target_hwnd_pre>0
        puts "起動しています => " + target_hwnd_pre.to_s
        set_foreground_window(target_hwnd_pre, state)
      end
    end
    target_hwnd = find_window(filename) 
    if target_hwnd==0
      target_hwnd = find_window("パスワード")
      state = win_state(:default) if target_hwnd > 0
    end
    if target_hwnd > 0
      puts filename + " => " + target_hwnd.to_s
      return set_foreground_window(target_hwnd, state)
    else
      p "cnt => "+cnt.to_s
      break if cnt>100
    end
  }
  false
end
def set_new_window_foreground(wins,filename="not_file")
  wins = wins.select{|hwnd| is_visible(hwnd)}
  current_wins = []
  cnt=0
  loop{
    sleep 0.05
    cnt +=1
    p cnt
    current_wins = get_hwnd_of_all_windows
    target_hwnd_pre = find_window("起動しています")
    if target_hwnd_pre>0
      puts "起動しています => " + target_hwnd_pre.to_s
      set_foreground_window(target_hwnd_pre)
      current_wins.delete(target_hwnd_pre)
    end
    target_hwnd = find_window(filename)
    if target_hwnd>0
      puts filename + " => " + target_hwnd.to_s
      return set_foreground_window(target_hwnd,:restore)
    else
      new_wins = current_wins - wins
      if new_wins.size>0 or cnt>200
        new_wins.each do |win|
          set_foreground_window(win)
        end
        return true
      end
    end
  }
  false
end
def win_state(state)
  case state
  when :normal   ; 1
  when :maximize ; 3
  when :restore  ; 9
  when :default  ;10
  else           ;10
  end
end
def get_hwnd_by_pid(pid)
  wins = get_hwnd_of_all_window
  wins.each do |hwnd|
    return hwnd if WIN32API.GetWindowThreadProcessId(hwnd,0)
  end
  nil
end

def key_backspace
  WIN32API::keybd_event(0x08,0,0,0)
end

def key_alt_f4
  WIN32API.keybd_event(0x12,0,0,0)     #alt key_press
  WIN32API.keybd_event(0x73,0,0,0)     #F4 key_press
  WIN32API.keybd_event(0x12,0,0x002,0) #alt key_up
  WIN32API.keybd_event(0x73,0,0x002,0) #F4 key_up
end

def msgbox(message,title,disp)
   type = {:OK                => 0x00000000,
           :OKCancel          => 0x00000001,
           :StopRetryIgnore   => 0x00000002,
           :YesNoCancel       => 0x00000003,
           :YeNo              => 0x00000004,
           :RetryCancel       => 0x00000005,
           :CancelTryContinue => 0x00000006,   
           :ERROR             => 0x00000010,
           :QUESTION          => 0x00000020,
           :CAUTION           => 0x00000030,
           :INFORMATION       => 0x00000040 }
  WIN32API.MessageBox(0,message.encode("sjis"),title.encode("sjis"),type[disp])
end

def set_foreground_dialog(dialog_title)
  hiki = get_foreground_window
  dialog_hwnd = nil
  begin
      i=0
      loop do
        p i += 1 
        dialog_hwnd = find_window(dialog_title)
        if dialog_hwnd > 0
          break
        else
          sleep(0.2)
        end
      end
      set_foreground_window(dialog_hwnd)
      sleep(0.1)
      key_backspace #ダイアログの入力欄の初期値をブランクにする.
  rescue => e
    p e.message
    p :dialog_no_opend
    #exit
  end
  #ファイル/フォルダ選択ダイアログは常にHikiの前面に表示する.
  #ファイル/フォルダ選択ダイアログのウインドウがなくなったら終了する。
  while find_window(dialog_title)>0
    if hiki == get_foreground_window
      set_foreground_window(dialog_hwnd)
    end
    sleep(0.2)
  end
end
