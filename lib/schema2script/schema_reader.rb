# encoding: UTF-8
require 'nokogiri'
#require 'open-uri'
require 'uri'
require 'chunky_png'
require 'schema2script/table'

module Schema2Script
    class SchemaReader
        @doc
        
        def initialize(filename)
            if filename =~ /.png$/i
                image = ChunkyPNG::Image.from_file(filename)
                # PNG generation of www.draw.io is broken, there is a bad CRC
                puts image.metadata['mxGraphModel']
                exit
            end
            
            @doc = Nokogiri::XML(if filename =~ /^https?:/ then open(filename) else File.read(filename) end)
            
            if @doc.at('svg')
                # SVG diagram, check if contains embedded source (compressed)
                data = @doc.search('svg')[0]['content']
                abort "SVG doesn't contain embedded source diagram" if data.nil?
                @doc  = Nokogiri.XML(data)
            end
            
            if @doc.at('mxfile')
                # Compressed schema, must decompress it before continue
                data = @doc.search('mxfile').text
                data = Base64.decode64(data)
                data = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data)
                data = URI.decode_www_form_component(data)
                @doc  = Nokogiri.XML(data)
            end
            
            abort "Diagram not recognized" unless @doc.at('mxGraphModel')
        end
        
        def get_tables()
            tables = []
            
            @doc.xpath('//mxCell[@parent="1"]').each do |node|
                table = Table.create_from_node node
                
                unless table.name.empty?
                    tables.each { |tab| STDERR.puts "WARNING: table #{table.name} already declared" if tab.name == table.name }
                    tables << table
                end
            end
            
            tables
        end
        
    end
end
