# encoding: UTF-8
module Schema2Script
    class SqlGenerator
        attr_reader :name
        @default_string_type
        @current_time
        @current_date
        @current_timestamp
        
        def initialize(name)
            @name                = name
            @default_string_type = 'Varchar2(255)'
            @current_time        = 'Current_Time'
            @current_date        = 'Current_Date'
            @current_timestamp   = 'Current_Timestamp'
        end
        
        def warning(message)
            STDERR.puts "WARNING: #{message}"
        end
        
        def validate(table)
            # Verify that table fields are ok
            table.fields.each { |field| validate_column(field) }
        end
        
        def validate_column(column)
            warning "field #{column.table.name}.#{column.name} declared NOT NULL with NULL as default value" if column.not_null? && column.default == 'null'
        end
        
        def generate_table(table)
            ddl_script = ''
            separator  = ''
            pks        = []
            comments   = []
            comments << table_comment(table) unless table.comment.empty?
            
            ddl_script << "#{table.pre_script}\n" unless table.pre_script.empty?
            ddl_script << table_create(table)
            
            # Scan for attribute of table
            table.fields.each do |field|
                fieldType    = if field.type.empty? then @default_string_type else field.type.capitalize end
                fieldType << " Default #{default_value(field)}" unless field.default.empty?
                fieldType << " Not Null" if field.not_null?
                
                ddl_script << sprintf("%s    %-20s %s", separator, field.name, fieldType)
                comments   << column_comment(field) unless field.comment.empty?
                separator = ",\n"
            end
            
            # Emit primary key constraint, if required
            ddl_script << sprintf("%s    %s", separator, primary_key(table)) unless table.pks.empty?
            ddl_script << sprintf("%s    %s", separator, table.fks.map { |fk| foreign_key fk }.join("#{separator}    ")) unless table.fks.empty?
            ddl_script << "\n);\n\n" # End of table
            
            # Emit table and column comments, if necessary
            ddl_script << comments.join("\n")+"\n\n" unless comments.empty?
            ddl_script << "#{table.post_script}\n\n" unless table.post_script.empty?
            ddl_script
        end
        
        def multiline_comment(text)
            return "/* #{text} */\n"
        end
        
        def table_create(table)
            "Create Table #{table.name}(\n"
        end
        
        def primary_key(table)
            "Primary Key (#{table.pks.join(', ')})"
        end
        
        def foreign_key(fk)
            "Foreign Key(#{fk.child.name}) References #{fk.master.table.name}(#{fk.master.name})"
        end
        
        def table_comment(table)
            "Comment On Table #{table.name} Is '#{table.comment.gsub(/'/, "''")}';"
        end
        
        def column_comment(column)
            "Comment On Column #{column.table.name}.#{column.name} Is '#{column.comment.gsub(/'/, "''")}';"
        end
        
        def default_value(column)
            return "Null"                if column.default =~ /\s*null\s*/i
            return "'#{column.default}'" if column.textType?
            return column.default        unless column.typestampType?
            
            normalized_timestamp(column.default)
        end
        
        def normalized_timestamp(value)
            normalizedTimestamp(value)
        end
        
        def normalizedTimestamp(value)
            return @current_time      if time_expr?      value
            return @current_date      if date_expr?      value
            return @current_timestamp if timestamp_expr? value
            
            # Provare a vedere in https://gist.github.com/jackrg/2927162
            value = value.to_s.gsub(/gennaio|gen/i  , 'Jan')
                              .gsub(/febbraio/i     , 'Feb')
                              .gsub(/marzo/i        , 'Mar')
                              .gsub(/aprile/i       , 'Apr')
                              .gsub(/maggio|mag/i   , 'May')
                              .gsub(/giugno|giu/i   , 'Jun')
                              .gsub(/luglio|lug/i   , 'Jul')
                              .gsub(/agosto|ago/i   , 'Aug')
                              .gsub(/settembre|set/i, 'Sep')
                              .gsub(/ottobre|ott/i  , 'Oct')
                              .gsub(/novembre/i     , 'Nov')
                              .gsub(/dicembre|dic/i , 'Dec')
            
            return "'"+DateTime.parse(value).strftime('%Y-%m-%d %H:%M:%S')+"'"
        end
        
        def time_expr?(value)
            !!(value =~ /^(current_time|currtime?)/i)
        end
        
        def date_expr?(value)
            !!(value.to_s.strip =~ /^(current_date|currdate|sysdate|today)/i)
        end
        
        def timestamp_expr?(value)
            !!(value.to_s.strip =~ /^(current_timestamp|now)/i)
        end
    end
end
