# encoding: UTF-8
require 'schema2script/field'

module Schema2Script
    class Table
        attr_accessor :id, :fields, :pks, :pre_script, :post_script
        attr_reader   :name, :comment
        
        def initialize()
            @name   = ""
            @fields = []
            @pks    = []
        end
        
        def self.create_from_node(node)
            table = Table.new
            
            if node.parent.name == 'object'
                table.name = node.parent['label']
                node       = node.parent
            else
                table.name = node['value']
            end
            
            table.id          = node['id']
            table.comment     = node['comment']
            table.pre_script  = node['preScript'].to_s
            table.post_script = node['postScript'].to_s

            unless table.name.empty?
                node.document.xpath("//mxCell[@parent='#{table.id}']").each do |attr|
                    field = Field.create_from_node attr, table
                    
                    unless field.name.empty?
                        table.fields.each do |fld|
                            STDERR.puts "WARNING: field #{table.name}.#{field.name} already declared" if field.name == fld.name
                        end
                        table.fields << field
                    end
                end
            end
            
            return table
        end
        
        def name=(value)
            @name = value.to_s.strip.gsub(/\s+/, '_')
        end
        
        def comment=(value)
            @comment = value.to_s.strip
        end
    end
end
