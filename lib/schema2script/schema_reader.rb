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
                unless node.has_attribute? 'edge' # skip named relations
                    table = Table.create_from_node node
                    
                    unless table.name.empty?
                        tables.each { |tab| STDERR.puts "WARNING: table #{table.name} already declared".light_yellow if tab.name == table.name }
                        tables << table
                    end
                end
            end
            
            # Search for relations
            tables.each do |table|
                table.fields.each do |srcField|
                    @doc.xpath("//mxCell[@source='#{srcField.id}']").each do |relation|
                        dstField   = field_by_id(tables, relation['target'])
                        styles     = relation['style'].split ';'
                        startArrow = styles.detect { |s| s =~ /^startArrow=/ }
                        endArrow   = styles.detect { |s| s =~ /^endArrow=/ }
                        startArrow = startArrow.split('=')[1] unless startArrow.nil?
                        endArrow   = endArrow.split('=')[1]   unless endArrow.nil?
                        
#                         STDERR.print "==>#{srcField.table.name}.#{srcField.name} - startArrow=#{startArrow}, endArrow=#{endArrow}\n"
                        
                        if ["ERmany", "ERoneToMany"].include? startArrow
                            STDERR.puts "WARNING: reversing relation as seems reversed: #{srcField.table.name}.#{srcField.name} (#{startArrow}) -> #{dstField.table.name}.#{dstField.name} (#{endArrow})".light_yellow
                            srcField, dstField = dstField, srcField 
                            startArrow, endArrow = endArrow, startArrow
                        elsif relation.parent.name == 'object' && relation.parent['reverseRelation'].to_s.strip =~ /^(y(es)?|t(rue)?|s[iì]?)$/i
                            # Requested to swap relation, quick fix instead to delete and re-create the relation
                            STDERR.puts "INFO: #{srcField.table.name}.#{srcField.name} (#{startArrow})-> #{dstField.table.name}.#{dstField.name} (#{endArrow}): relation explicitly reversed".green
                            srcField, dstField = dstField, srcField
                            startArrow, endArrow = endArrow, startArrow
                        end
                        
                        if dstField.nil?
                            STDERR.puts "ERROR: target foreign key not found: field=#{srcField.table.name}.#{srcField.name} target id=#{relation['target']}".light_red
                            break;
                        end
                        
                        startArrow = endArrow     if startArrow.nil?
                        startArrow = 'ERoneToOne' if startArrow == 'none' # standard link, no ER

                        dstField.table.add_fk(startArrow, relation['value'], dstField, srcField)
                    end
                end
            end
            
            # Sort tables to avoid troubles when generating foreign key constraints
            sort tables
        end
        
        def sort(tables)
            tables.sort do |x, y|
                if x.fks.empty? && y.fks.empty?
                    x.name <=> y.name               # no fks, order alphabetically
                elsif x.fks.empty?
                    -1                              # x has no relations, goes first
                elsif y.fks.empty?
                    1                               # y has no relations, goes first
                elsif x.references? y
                    1                               # x references y, y need to go first
                elsif y.references? x
                    -1                              # y references x, x need to go first
                elsif x.fks.length < y.fks.length
                    -1                              # x has fewer relations, goes first to reduce conflicts
                elsif x.fks.length > y.fks.length
                    1                               # y has fewer relations, goes first to reduce conflicts
                else
                    x.name <=> y.name               # no other rules, order alphabetically
                end
            end
        end
        
        def field_by_id(tables, field_id)
            tables.each do |table|
                found = table.fields.detect { |field| field.id == field_id }
                return found unless found.nil?
            end
            
            nil
        end
        
    end
end
