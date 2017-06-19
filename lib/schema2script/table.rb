# encoding: UTF-8
require 'schema2script/field'
require 'schema2script/foreign_keys'

module Schema2Script
    class Table
        attr_accessor :id, :fields, :pks, :pre_script, :post_script, :fks, :plural
        attr_reader   :name, :comment
        
        def initialize()
            @name   = ""
            @fields = []
            @pks    = []
            @fks    = []
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
            table.plural      = node['plural'].to_s
            
            unless table.name.empty?
                node.document.xpath("//mxCell[@parent='#{table.id}']").each do |attr|
                    field = Field.create_from_node attr, table
                    
                    unless field.name.empty?
                        table.fields.each do |fld|
                            STDERR.puts "WARNING: field #{table.name}.#{field.name} already declared".light_yellow if field.name == fld.name
                        end
                        table.fields << field
                    end
                end
            end
            
            return table
        end
        
        def add_fk(kind, name, child_field, master_field)
            @fks << FK_Constraint.new(kind, name, child_field, master_field)
        end
        
        def references?(tab)
            not @fks.detect { |fk| fk.master.table == tab}.nil?
        end
        
        def name=(value)
            @name = value.to_s.strip.gsub(/\s+/, '_')
        end
        
        def comment=(value)
            @comment = value.to_s.strip
        end
    end
end
