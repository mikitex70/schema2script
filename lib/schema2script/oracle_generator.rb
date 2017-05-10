require 'schema2script/sql_generator'

module Schema2Script
    class OracleGenerator < SqlGenerator
        def initialize
            super 'Oracle'
            @current_time      = 'Sysdate'
            @current_date      = 'Sysdate'
            @current_timestamp = 'Sysdate'
        end
        
        def primary_key(table)
            "Constraint #{table.name}_pk Primary Key (#{table.pks.join(', ')})"
        end
        
        def validate_column(column)
            super column
            
            warning "field #{column.table.name}.#{column.name} size #{column.size} is too big for oracle database" if column.textType? && !column.size.nil? && column.size >= 4096
        end

    end
end
