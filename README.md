What is “Hiki for Personal use on Windows(Hiki-PoW)” ?
====
- Hiki is a powerful and fast wiki clone written in Ruby.
- Hiki-PoW is a Wiki clone that runs on a local Windows PC for the purpose of managing files and folders on the local PC, and was developed based on Hiki.
- Hiki-PoW was developed to promote paperless office work.

- HikiはRubyで書かれた強力かつ高速なWikiクローンです。
- Hiki-PoW は、ローカルPC上のファイルやフォルダを管理する目的で、Hikiをベースに開発されたローカルWindows PC上で動作するWikiクローンです。
- Hiki-PoWは、オフィスワークのペーパーレス化を推進するために開発されました。

# Features
- Hiki-PoW is a web application that runs on your local PC as a web server.
- You can easily register files saved on your local PC and links to local folders or Windows shared folders, and then click on the link to open the file or folder.
- Normally, for security reasons, a web application running on an Internet browser cannot retrieve the path to a local file or open a local file. However, Hiki-PoW clears security restrictions by running on the local PC as a server and performing processes such as obtaining paths and opening local files with the application on the server side.

- Hiki-PoWは、ローカルPCをWebサーバーとして動作するWebアプリケーションです。
- ローカルPCに保存したファイルやローカルフォルダやWindows共有フォルダへのリンクを簡単に登録することができ、そのリンクをクリックすることでファイルやフォルダを開くことができます。
-  通常、セキュリティの観点から、インターネットブラウザ上で動作するWebアプリケーションでは、ローカルのファイルのパスを取得したり、ローカルのファイルを開いたりすることができません。しかし、Hiki-PoWは、ローカルPCをサーバーとして動作し、サーバーサイドでパスの取得やローカルファイルをアプリで開くなどの処理を行うことでセキュリティ上の制約をクリアしています。

# Requirement
-  Ruby 2.7.5〜3.1.2
-  Microsoft Excel
	- Use Excel functions to obtain the path to a file using the file selection dialog.
	- ファイル選択ダイアログでファイルのパスを取得するためにExcelの機能を使います。

# Installation
1. Install Ruby. 
2. Download the complete set of files of HIKI-PoW as a Zip file, and extract them to the `C:¥hiki` on your local PC. 
3. Open `C:¥hiki¥Gemfile` with Notepad, etc., and replace `3.1.2` in the second line of `ruby '3.1.2'` with the version of ruby you installed, and save it. 
4. Open a command prompt window and type the following. The necessary gem will be installed.
~~~
	C:¥Users¥xxxxxxx\>cd¥
	C:¥\>cd hiki
	C:¥hiki\>bundle install
~~~
5. Open `C:¥hiki¥hikiconf.rb` with Notepad, etc., and configure the folder to save the data, etc. as appropriate. It works fine with the default values.

1. Rubyをインストールする。
2. Hiki-PoWのファイル一式をZipファイルでダウンロードし、ローカルPCの`C:¥hiki`フォルダに展開する。
3. `C:¥hiki¥Gemfile`をメモ帳等で開き、2行目の`ruby ‘3.1.2’`の`3.1.2`の部分をインストールしたrubyのバージョンに書き換えて保存する。
4. コマンドプロンプト画面を開き、次のように入力する。必要なgemがインストールされる。
~~~
	C:¥Users¥xxxxxxx\>cd¥
	C:¥\>cd hiki
	C:¥hiki\>bundle install
~~~
5. `C:¥hiki¥hikiconf.rb`をメモ帳等で開き、データを保存するフォルダなどについて適宜設定を行う。既定値のままで支障なく動きます。

### For environments where access to the Internet environment is restricted
- You can do the above procedure on a PC with an Internet environment, and from that PC, copy the folder where you installed Ruby (ex.`C:¥Ruby31-x64`) and the folder where you extracted Hiki-PoW (ex.`C:¥hiki`) to the PC you want to use.
- インターネットへの接続が制限された環境にあるPCにインストールしたいときは、インターネット環境にあるPCで上記の手順を行い、そのPCから、Rubyをインストールしたフォルダ(ex.`C:¥Ruby31-x64`)とHiki-PoWを展開したフォルダ(ex.`C:¥hiki`)を、使用したいPCにコピーしてください。
# Usage
- Double-click `C:¥hiki¥start_hiki.vbs` to start. Type `localhost:9292` in the address bar of your browser and if the initial screen appears, you have succeeded.
- If you set up by copying the folder to a PC with restricted access to the Internet, add the folder containing ruby.exe (ex.`C:¥Ruby31-x64¥bin`) to the Windows environment variable PATH, or open `C:¥ hiki¥start_hiki.vbs` with Notepad and rewrite it as follows (The "C:¥Ruby31-x64" in the second line depends on the version of Ruby. Check it with Explorer and modify it accordingly.)
~~~
	Dim objCMD,RubyPath
	RubyPath = “C:¥Ruby31-x64”
	Set objCMD = CreateObject("WScript.Shell")
	objCMD.Run RubyPath & “¥bin¥rackup.bat”, 0, false
~~~
- `C:¥hiki¥start_hiki.vbs`をダブルクリックすれば起動します。ブラウザのアドレスバーに`localhost:9292`と入力して初期画面が表示されれば成功です。
- インターネット環境へのアクセスが制限されている環境にあるPCにフォルダをコピーすることによってセットアップした場合は、Windowsの環境変数のPATHにruby.exeのあるフォルダ(ex.`C:¥Ruby31-x64¥bin`)を追加するか、又は`C:¥hiki¥start_hiki.vbs`をメモ帳で開き、次のように書き換えてください。(2行目の“C:¥Ruby31-x64”の部分はRubyのバージョンによって異なります。エクスプローラで確認して適宜修正してください。)
~~~
	Dim objCMD,RubyPath
	RubyPath = “C:¥Ruby31-x64”
	Set objCMD = CreateObject("WScript.Shell")
	objCMD.Run RubyPath & “¥bin¥rackup.bat”, 0, false
~~~

###### How to allow other PCs to view the page
- If you want to allow access from other PCs in your network, change the last line of `start_hiki.vbs` to `objCMD.Run RubyPath & "³³.bat -o 0.0.0.0", 0, false`.
- When you start Hiki-PoW with this setting, the web server will accept access from other PCs, but as it is, it will be blocked at the application level of Hiki-PoW and you will not be able to open Hiki-PoW pages from other PCs.
- By registering the words "public" or "limited public" as keywords on a Hiki-PoW page, the page can be opened from other PCs. To register a keyword, open the edit page screen by clicking the Edit button, enter the keyword in the text box at the bottom for keyword entry, and click the Save button.
- When a link to a local file on a public or limited public page is clicked from another PC, the file data is returned to the browser. This is the same as downloading a file from the Internet.
- Links to local folders or Windows shared folders cannot be opened from other PCs, even on public or limited public pages.
- On public pages, you can open the edit screen from other PCs, and the file selection and folder selection buttons are disabled, but you can perform other editing operations.

- ネットワーク内の他のPCからのアクセスを許可したい場合は、`start_hiki.vbs`の最後の行を、`objCMD.Run RubyPath & “¥bin¥rackup.bat -o 0.0.0.0”, 0, false`としてください。
- この設定でHiki-PoWを起動すると、Webサーバーが他のPCからのアクセスを受け付けるようになりますが、そのままではHiki-PoWのアプリケーションレベルでブロックされ、他のPCからHiki-PoWのページを開くことはできません。
- Hiki-PoWのページのキーワードに「公開」又は「限定公開」のワードを登録することで、他のPCからそのページを開くことができるようになります。キーワードの登録は、編集ボタンでページの編集画面を開き、一番下にあるキーワード入力用のテキストボックスにキーワードを入力し、保存ボタンをクリックすることにより行います。
- 公開又は限定公開のページのローカルファイルへのリンクを他のPCからクリックしたときは、ファイルデータがブラウザに返されます。インターネットでファイルをダウンロードする場合と同じです。
- 公開又は限定公開のページでも、ローカルフォルダ又はWindows共有フォルダへのリンクを他PCから開くことはできません。
- 公開ページは、他のPCから編集画面を開くことができ、ファイル選択ボタンとフォルダ選択ボタンは無効ですが、それ以外の編集操作を行うことができます。
