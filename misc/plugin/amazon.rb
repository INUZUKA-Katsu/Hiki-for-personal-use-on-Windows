# amazon.rb: Making link with image to Amazon using Amazon ECS.
#
# see document: #{@lang}/amazon.rb
#
# Copyright (C) 2005-2007 TADA Tadashi <sho@spc.gr.jp>
# You can redistribute it and/or modify it under GPL2.
#
require 'net/http'
require 'uri'
require 'timeout'
require 'rexml/document'

# do not change these variables
@amazon_subscription_id = '1CVA98NEF1G753PFESR2'
@amazon_require_version = '2007-01-17'

@amazon_url_hash = {
  'us' => 'http://www.amazon.com/exec/obidos/ASIN',
  'jp' => 'http://www.amazon.co.jp/exec/obidos/ASIN',
  'fr' => 'http://www.amazon.fr/exec/obidos/ASIN',
  'uk' => 'http://www.amazon.co.uk/exec/obidos/ASIN',
  'de' => 'http://www.amazon.de/exec/obidos/ASIN',
  'ca' => 'http://www.amazon.ca/exec/obidos/ASIN',
}

@amazon_ecs_url_hash = {
  'us' => 'http://honnomemo.appspot.com/rpaproxy/us/',
  'jp' => 'http://honnomemo.appspot.com/rpaproxy/jp/',
  'fr' => 'http://honnomemo.appspot.com/rpaproxy/fr/',
  'uk' => 'http://honnomemo.appspot.com/rpaproxy/uk/',
  'de' => 'http://honnomemo.appspot.com/rpaproxy/de/',
  'ca' => 'http://honnomemo.appspot.com/rpaproxy/ca/',
}

def amazon_fetch( url, limit = 10 )
	raise ArgumentError, 'HTTP redirect too deep' if limit == 0

	px_host, px_port = (@conf['proxy'] || '').split( /:/ )
	px_port = 80 if px_host and !px_port
	res = Net::HTTP::Proxy( px_host, px_port ).get_response( URI::parse( url ) )
	case res
	when Net::HTTPSuccess
		res.body
	when Net::HTTPRedirection
		amazon_fetch( res['location'].untaint, limit - 1 )
	else
		raise ArgumentError, res.error!
	end
end

def amazon_call_ecs( asin, id_type, country = nil )
	aid =  @conf['amazon.aid'] || ''
	aid = 'cshs-22' if aid.empty?

	url = (@conf['amazon.endpoints'] || @amazon_ecs_url_hash)[country].dup
	url << "?Service=AWSECommerceService"
	url << "&SubscriptionId=#{@amazon_subscription_id}"
	url << "&AssociateTag=#{aid}"
	url << "&Operation=ItemLookup"
	url << "&ItemId=#{asin}"
	url << "&IdType=#{id_type}"
	url << "&SearchIndex=Books" if id_type == 'ISBN'
	url << "&ResponseGroup=Medium"
	url << "&Version=#{@amazon_require_version}"

	begin
		timeout( 10 ) do
			amazon_fetch( url )
		end
	rescue ArgumentError
	end
end

def amazon_author( item )
	begin
		author = []
		%w(Author Creator Artist).each do |elem|
			item.elements.each( "*/#{elem}" ) do |a|
				author << a.text
			end
		end
		@conf.to_native( author.uniq.join( '/' ), 'utf-8' )
	rescue
		'-'
	end
end

def amazon_title( item )
	@conf.to_native( item.elements.to_a( '*/Title' )[0].text, 'utf-8' )
end

def amazon_image( item )
	image = {}
	begin
		size = case @conf['amazon.imgsize']
		when 0; 'Large'
		when 2; 'Small'
		else;   'Medium'
		end
		img = item.elements.to_a("#{size}Image")[0] || item.elements.to_a("ImageSets/ImageSet/#{size}Image")[0]
		image[:src] = img.elements['URL'].text
		image[:height] = img.elements['Height'].text
		image[:width] = img.elements['Width'].text
	rescue
		base = @conf['amazon.default_image_base'] || 'http://www.tdiary.org/images/amazondefaults/'
		case @conf['amazon.imgsize']
		when 0
			image[:src] = "#{base}large.png"
			image[:height] = 500
			image[:width] = 380
		when 2
			image[:src] = "#{base}small.png"
			image[:height] = 75
			image[:width] = 57
		else
			image[:src] = "#{base}medium.png"
			image[:height] = 160
			image[:width] = 122
		end
	end
	image
end

def amazon_url( item )
	item.elements.to_a( 'DetailPageURL' )[0].text
end

def amazon_label( item )
	begin
		@conf.to_native( item.elements.to_a( '*/Label' )[0].text, 'utf-8' )
	rescue
		'-'
	end
end

def amazon_price( item )
	begin
		@conf.to_native( item.elements.to_a( '*/LowestNewPrice/FormattedPrice' )[0].text, 'utf-8' )
	rescue
		begin
			@conf.to_native( item.elements.to_a( '*/ListPrice/FormattedPrice' )[0].text, 'utf-8' )
		rescue
			'(no price)'
		end
	end
end

def amazon_detail_html( item )
	author = amazon_author( item )
	title = amazon_title( item )

	size_orig = @conf['amazon.imgsize']
	@conf['amazon.imgsize'] = 2
	image = amazon_image( item )
	@conf['amazon.imgsize'] = size_orig

	url = amazon_url( item )
	html = <<-HTML
	<a href="#{url}">
		<img class="amazon-detail left" src="#{h image[:src]}"
		height="#{h image[:height]}" width="#{h image[:width]}"
		alt="#{h title}" title="#{h title}">
	</a>
	<span class="amazon-title">#{h title}</span><br>
	<span class="amazon-author">#{h author}</span><br>
	<span class="amazon-label">#{h amazon_label( item )}</span><br>
	<span class="amazon-price">#{h amazon_price( item )}</span><br style="clear: left">
	HTML
end

def amazon_to_html( item, with_image = true, label = nil, pos = 'amazon' )
	with_image = false if @mode == 'categoryview'

	author = amazon_author( item )
	author = "(#{author})" unless author.empty?

	if with_image and @conf['amazon.hidename'] || pos != 'amazon' then
		label = ''
	elsif not label
		label = %Q|#{amazon_title( item )}#{author}|
	end

	if with_image
		image = amazon_image( item )
		unless image[:src] then
			img = ''
		else
			img = <<-HTML
			<img class="#{h pos}" src="#{h image[:src]}"
			height="#{h image[:height]}" width="#{h image[:width]}"
			alt="#{h label}" title="#{h label}">
			HTML
			img.gsub!( /\t/, '' )
		end
	end

	url = amazon_url( item )
	%Q|<a href="#{h url}">#{img}#{h label}</a>|
end

def amazon_secure_html( asin, with_image, label, pos = 'amazon', country = nil )
	with_image = false if @mode == 'categoryview'
	label = asin unless label

	image = ''
	if with_image and @conf['amazon.secure-cgi'] then
		image = <<-HTML
		<img class="#{h pos}"
		src="#{h @conf['amazon.secure-cgi']}?asin=#{u asin};size=#{u @conf['amazon.imgsize']};country=#{u country}"
		alt="#{h label}" title="#{h label}">
		HTML
	end
	image.gsub!( /\t/, '' )

	if with_image and @conf['amazon.hidename'] || pos != 'amazon' then
		label = ''
	end

	amazon_url = @amazon_url_hash[country]
	url =  "#{amazon_url}/#{u asin}"
	url << "/#{u @conf['amazon.aid']}" if @conf['amazon.aid'] and @conf['amazon.aid'].length > 0
	url << "/ref=nosim/"
	%Q|<a href="#{h url}">#{image}#{h label}</a>|
end

def amazon_get( asin, with_image = true, label = nil, pos = 'amazon' )
	asin = asin.to_s.strip # delete white spaces
	asin.sub!(/\A([a-z]+):/, '')
	country = $1 || @conf['amazon.default_country'] || @amazon_default_country
	digit = asin.gsub( /[^\d]/, '' )
	if digit.length == 13 then # ISBN-13
		asin = digit
		id_type = 'ISBN'
	else
		id_type = 'ASIN'
	end

	if @conf.secure then
		amazon_secure_html( asin, with_image, label, pos, country )
	else
		begin
			cache = "#{@cache_path}/amazon"
			Dir::mkdir( cache ) unless File::directory?( cache )
			begin
				xml = File::read( "#{cache}/#{country}#{asin}.xml" )
			rescue Errno::ENOENT
				xml =  amazon_call_ecs( asin, id_type, country )
				File::open( "#{cache}/#{country}#{asin}.xml", 'wb' ) {|f| f.write( xml )}
			end
			doc = REXML::Document::new( REXML::Source::new( xml ) ).root
			item = doc.elements.to_a( '*/Item' )[0]
			if pos == 'detail' then
				amazon_detail_html( item )
			else
				amazon_to_html( item, with_image, label, pos )
			end
		rescue Timeout::Error
			asin
		rescue NoMethodError
			message = label || asin
			if @mode == 'preview' then
				if item == nil then
					m = doc.elements.to_a( 'Items/Request/Errors/Error/Message' )[0].text
					message << %Q|<span class="message">(#{h @conf.to_native( m, 'utf-8' )})</span>|
				else
					message << %Q|<span class="message">(#{h $!}\n#{h $@.join( ' / ' )})</span>|
				end
			end
			message
		end
	end
end

unless @conf.secure and not @conf['amazon.secure-cgi'] then
	add_conf_proc( 'amazon', @amazon_label_conf ) do
		amazon_conf_proc
	end
end

def amazon_conf_proc
	if @mode == 'saveconf' then
		unless @conf.secure and not @conf['amazon.secure-cgi'] then
			@conf['amazon.imgsize'] = @request.params['amazon.imgsize'].to_i
			@conf['amazon.hidename'] = (@request.params['amazon.hidename'] == 'true')
			unless @conf.secure then
				@conf['amazon.nodefault'] = (@request.params['amazon.nodefault'] == 'true')
				if @request.params['amazon.clearcache'] == 'true' then
					Dir["#{@cache_path}/amazon/*"].each do |cache|
						File::delete( cache.untaint )
					end
				end
			end
		end
		unless @conf['amazon.hideconf'] then
			@conf['amazon.aid'] = @request.params['amazon.aid']
		end
	end

	result = ''
	unless @conf.secure and not @conf['amazon.secure-cgi'] then
		result << <<-HTML
			<h3>#{@amazon_label_imgsize}</h3>
			<p><select name="amazon.imgsize">
				<option value="0"#{" selected" if @conf['amazon.imgsize'] == 0}>#{@amazon_label_large}</option>
				<option value="1"#{" selected" if @conf['amazon.imgsize'] == 1}>#{@amazon_label_regular}</option>
				<option value="2"#{" selected" if @conf['amazon.imgsize'] == 2}>#{@amazon_label_small}</option>
			</select></p>
			<h3>#{@amazon_label_title}</h3>
			<p><select name="amazon.hidename">
				<option value="true"#{" selected" if @conf['amazon.hidename']}>#{@amazon_label_hide}</option>
				<option value="false"#{" selected" unless @conf['amazon.hidename']}>#{@amazon_label_show}</option>
			</select></p>
		HTML
		unless @conf.secure then
			result << <<-HTML
				<h3>#{@amazon_label_notfound}</h3>
				<p><select name="amazon.nodefault">
					<option value="true"#{" selected" if @conf['amazon.nodefault']}>#{@amazon_label_usetitle}</option>
					<option value="false"#{" selected" unless @conf['amazon.nodefault']}>#{@amazon_label_usedefault}</option>
				</select></p>
				<h3>#{@amazon_label_clearcache}</h3>
				<p><label for="amazon.clearcache"><input type="checkbox" id="amazon.clearcache" name="amazon.clearcache" value="true">#{@amazon_label_clearcache_desc}</label></p>
			HTML
		end
	end
	unless @conf['amazon.hideconf'] then
		result << <<-HTML
			<h3>#{@amazon_label_aid}</h3>
			<p>#{@amazon_label_aid_desc}</p>
			<p><input name="amazon.aid" value="#{h( @conf['amazon.aid'] ) if @conf['amazon.aid']}"></p>
		HTML
	end
	result
end

def isbn_detail( asin )
	amazon_get( asin, true, nil, 'detail' )
end

def isbn_image( asin, label = nil )
	amazon_get( asin, true, label )
end

def isbn_image_left( asin, label = nil )
	amazon_get( asin, true, label, 'left' )
end

def isbn_image_right( asin, label = nil )
	amazon_get( asin, true, label, 'right' )
end

def isbn( asin, label = nil )
	amazon_get( asin, false, label )
end

# for compatibility
alias isbnImgLeft isbn_image_left
alias isbnImgRight isbn_image_right
alias isbnImg isbn_image
alias amazon isbn_image
