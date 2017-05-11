# encoding: UTF-8
module Schema2Script
    class Field
        attr_accessor :id, :constraints, :not_null, :table, :unique
        alias_method  :not_null?, :not_null
        alias_method  :unique?, :unique
        attr_reader   :name, :type, :comment, :default
        
        def initialize()
            @name = ""
            @constraints = []
        end
        
        def self.create_from_node(node, table)
            field = Field.new
            
            if node.parent.name == 'object'
                name = node.parent['label']
                node = node.parent
            else
                name = node['value']
            end
            
            field.table    = table
            field.id       = node['id']
            field.comment  = node['comment']
            field.default  = node['default']
            field.not_null = !!(node['notNull'].to_s.strip =~ /^(y(es)?|t(rue)?|s[iì]?)$/i)
            field.unique   = !!(node['unique' ].to_s.strip =~ /^(y(es)?|t(rue)?|s[iì]?)$/i)
            
            if name =~ /([^:]+)\s*:?\s*(.*)/
                field.name, field.type = $1, $2
                
                # Find for primary key attribute(s)
                node.document.xpath("//mxCell[@parent='#{field.id}' and @value!='']").each do |constraint|
                    if constraint['value'].downcase == 'pk'
                        # Only primary keys are handled (for now)
                        field.constraints << constraint['value'].downcase
                        table.pks << field.name
                    end
                end
            end
            
            return field
        end
        
        def name=(value)
            @name = value.to_s.gsub(/&nbsp;/, ' ').strip.gsub(/\s+/, '_')
        end
        
        def type=(value)
            @type = value.to_s.gsub(/&nbsp;/, ' ').strip
            
            STDERR.puts "WARNING: unrecognized field type #{@type} for field #{@table.name}.#{@name}" unless valid_type?
        end
        
        def comment=(value)
            @comment = value.to_s.strip
        end
        
        def default=(value)
            @default = value.to_s.gsub(/'/, "''")
        end
        
        def size
            return Integer($1) if @type =~ /.*\((\d+)\)$/
            nil
        end
        
        def numericType?
            !!(@type =~ /^(number|long|int|integer|double|numeric)/i)
        end
        
        def textType?
            !!(@type =~ /^(varchar|char|string|text)/i)
        end
        
        def typestampType?
            !!(@type =~ /^(date|time)/i)
        end
        
        private
        
        def valid_type?
            @type.empty? || textType? || numericType? || typestampType?
        end
    end
    
end
