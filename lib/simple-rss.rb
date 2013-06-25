require 'cgi'
require 'time'

class SimpleRSS
  VERSION = "1.2.5"
  
	attr_reader :items, :source
	alias :entries :items

	@@feed_tags = [
		:id,
		:title, :subtitle, :link,
		:description, 
		:author, :webMaster, :managingEditor, :contributor,
		:pubDate, :lastBuildDate, :updated, :'dc:date',
		:generator, :language, :docs, :cloud,
		:ttl, :skipHours, :skipDays,
		:image, :logo, :icon, :rating,
		:rights, :copyright,
		:textInput, :'feedburner:browserFriendly',
		:'itunes:author', :'itunes:category'
	]

	@@item_tags = [
		:id,
		:title, :link, :'link+alternate', :'link+self', :'link+edit', :'link+replies',
		:author, :contributor,
		:description, :summary, :content, :'content:encoded', :comments,
		:pubDate, :published, :updated, :expirationDate, :modified, :'dc:date',
		:category, :guid,
		:'trackback:ping', :'trackback:about',
		:'dc:creator', :'dc:title', :'dc:subject', :'dc:rights', :'dc:publisher',
		:'feedburner:origLink',
		:'media:content#url', :'media:content#type', :'media:content#height', :'media:content#width',
		:'media:title', :'media:thumbnail#url', :'media:thumbnail#height', :'media:thumbnail#width',
		:'media:credit', :'media:credit#role',
		:'media:category', :'media:category#scheme'
	]

	def initialize(source, options={})
		@source = source.respond_to?(:read) ? source.read : source.to_s
		@items = Array.new
    @options = Hash.new.update(options)
    
		parse
	end

	def channel() self end
	alias :feed :channel

	class << self
		def feed_tags
			@@feed_tags
		end
		def feed_tags=(ft)
			@@feed_tags = ft
		end

		def item_tags
			@@item_tags
		end
		def item_tags=(it)
			@@item_tags = it
		end

		# The strict attribute is for compatibility with Ruby's standard RSS parser
		def parse(source, options={})
			new source, options
		end
	end

	private

	def parse
	  raise SimpleRSSError, "Poorly formatted feed" unless @source =~ %r{<(channel|feed).*?>.*?</(channel|feed)>}mi
	  
		# Feed's title and link
		feed_content = $1 if @source =~ %r{(.*?)<(rss:|atom:)?(item|entry).*?>.*?</(rss:|atom:)?(item|entry)>}mi
		
		@@feed_tags.each do |tag|
      if tag.to_s.include?("+")
        tag_data = tag.to_s.split("+")
        tag = tag_data[0]
        rel = tag_data[1]
        
        if feed_content and feed_content =~ %r{<(rss:|atom:)?#{tag}(.*?)rel=['"]#{rel}['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
          nil
        elsif @source =~ %r{<(rss:|atom:)?#{tag}(.*?)rel=['"]#{rel}['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
          nil
        end
        if $3 || $4
          tag_cleaned = clean_tag("#{tag}_#{rel}_data")
          instance_variable_set("@#{ tag_cleaned }", clean_content(tag, $3, $4))
          self.class.send(:attr_reader, tag_cleaned)
        end
        next
      elsif tag.to_s.include?("#")
        tag_data = tag.to_s.split("#")
        tag = tag_data[0]
        attrib = tag_data[1]
        if feed_content and feed_content =~ %r{<(rss:|atom:)?#{tag}(.*?)#{attrib}=['"](.*?)['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
          nil
        elsif @source =~ %r{<(rss:|atom:)?#{tag}(.*?)#{attrib}=['"](.*?)['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
          nil
        end
        if $3
          tag_cleaned = clean_tag("#{tag}_#{attrib}")
          instance_variable_set("@#{ tag_cleaned }", clean_content(tag, attrib, $3))
          self.class.send(:attr_reader, tag_cleaned)
        end
        next
      elsif feed_content && feed_content =~ %r{<(rss:|atom:)?#{tag}(.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
        nil
			elsif @source =~ %r{<(rss:|atom:)?#{tag}(.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
        nil
			end
			
			if $2 || $3
        tag_cleaned = clean_tag(tag)
        instance_variable_set("@#{ tag_cleaned }", clean_content(tag, $2, $3))
        self.class.send(:attr_reader, tag_cleaned)
			end
		end

		# RSS items' title, link, and description
		@source.scan( %r{<(rss:|atom:)?(item|entry)([\s][^>]*)?>(.*?)</(rss:|atom:)?(item|entry)>}mi ) do |match|
			item = Hash.new
			@@item_tags.each do |tag|
			  if tag.to_s.include?("+")
			    tag_data = tag.to_s.split("+")
			    tag = tag_data[0]
			    rel = tag_data[1]
			    
  				if match[3] =~ %r{<(rss:|atom:)?#{tag}(.*?)rel=['"]#{rel}['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
            nil
  				end
  				item[clean_tag("#{tag}+#{rel}")] = clean_content(tag, $3, $4) if $3 || $4
  			elsif tag.to_s.include?("#")
			    tag_data = tag.to_s.split("#")
			    tag = tag_data[0]
			    attrib = tag_data[1]
  				if match[3] =~ %r{<(rss:|atom:)?#{tag}(.*?)#{attrib}=['"](.*?)['"](.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
  				  nil
  				end
  				item[clean_tag("#{tag}_#{attrib}")] = clean_content(tag, attrib, $3) if $3
		    else
  				if match[3] =~ %r{<(rss:|atom:)?#{tag}(.*?)(?:/\s*>|>(.*?)</(rss:|atom:)?#{tag}>)}mi
  					nil
  				end
  				item[clean_tag(tag)] = clean_content(tag, $2, $3) if $2 || $3
				end
			end
			def item.method_missing(name, *args) self[name] end
			@items << item
		end

	end

	def clean_content(tag, attrs, content)
		content = content.to_s
		case tag
			when :pubDate, :lastBuildDate, :published, :updated, :expirationDate, :modified, :'dc:date'
				Time.parse(content) rescue unescape(content)
			when :author, :contributor, :skipHours, :skipDays
				unescape(content.gsub(/<.*?>/,''))
			else
				content.empty? && "#{attrs} " =~ /href=['"]?([^'"]*)['" ]/mi ? $1.strip : unescape(content)
		end
	end

	def clean_tag(tag)
		tag.to_s.gsub(':','_').intern
	end
	
  def unescape(content)
  	if content =~ /([^-_.!~*'()a-zA-Z\d;\/?:@&=+$,\[\]]%)/un then
  		CGI.unescape(content).gsub(/(<!\[CDATA\[|\]\]>)/u,'').strip
  	else
  		content.gsub(/(<!\[CDATA\[|\]\]>)/u,'').strip
  	end
  end
end

class SimpleRSSError < StandardError
end
