#!/usr/bin/env ruby

require 'nokogiri'
require 'thor'
require 'open-uri'
require 'zlib'
require 'base64'
require 'uri'
require 'date'
require 'fileutils'
require 'chunky_png'


class CmdLine < Thor
    include Thor::Actions
    
    desc "sboot [options] schema.[xml|svg]", "Generate sboot commands from www.draw.io ER schemas"
    long_desc <<-LONGDESC
      Generates sources based on the entities defined in the specified schema diagram.\n
      Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
    LONGDESC
    method_option :env,    :enum    => [ "fullstack", "api", "backend", "conversion", "persistence" ],
                           :default => "fullstack",
                           :desc    => "kind of stack to generate"
    method_option :file,   :default => "sboot_generate.sh",
                           :desc    => "file for the generated sboot commands script"
    method_option :stdout, :type    => :boolean,
                           :default => false,
                           :desc    => "generate code to standard output"
    def sboot(file)
        doc    = openSchema(file)
        tables = get_tables doc
        
        emit generate_sboot_commands(tables, options[:env])
    end
    
    desc "ddl [options] schema.[xml|svg]", "Generate sboot commands from www.draw.io ER schemas"
    long_desc <<-LONGDESC
      Generates am SQL DDL script from the entities defined in the specified schema diagram.\n
      Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
    LONGDESC
    method_option :dialect, :enum    => [ "h2", "oracle" ],
                            :default => "h2",
                            :desc    => "SQL dialect when generating DDL"
    method_option :file,    :default => "src/main/resources/database/db_create.sql",
                            :desc    => "file for the generated DDL script"
    method_option :stdout,  :type    => :boolean,
                            :default => false,
                            :desc    => "generate code to standard output"
    def ddl(file)
        doc       = openSchema(file)
        tables    = get_tables doc
        generator = sql_generator options[:dialect]
        
        tables.each { |table| generator.validate table }
        
        emit generate_ddl(tables, generator)
    end
    
    desc "validate [options] schema.[xml|svg]", "Validate an www.draw.io ER schema"
    long_desc <<-LONGDESC
      Validates the entities defined in the specified schema diagram.\n
      Diagrams can be in XML format (compressed or not) or in SVG format with embedded XML source.
    LONGDESC
    method_option :dialect, :enum    => [ "h2", "oracle" ],
                            :default => "h2",
                            :desc    => "SQL dialect when generating DDL"
    def validate(file)
        doc       = openSchema(file)
        tables    = get_tables doc
        generator = sql_generator options[:dialect]
        tables.each { |table| generator.validate table }
    end
    
    private
    
    def openSchema(file)
        if file =~ /.png$/i
            image = ChunkyPNG::Image.from_file(file)
            # PNG generation of www.draw.io is broken, there is a bad CRC
            puts image.metadata['mxGraphModel']
            exit
        end
        
        doc = Nokogiri::XML(if file =~ /^https?:/ then open(file) else File.read(file) end)
        
        if doc.at('svg')
            # SVG diagram, check if contains embedded source (compressed)
            data = doc.search('svg')[0]['content']
            abort "SVG doesn't contain embedded source diagram" if data.nil?
            doc  = Nokogiri.XML(data)
        end
        
        if doc.at('mxfile')
            # Compressed schema, must decompress it before continue
            data = doc.search('mxfile').text
            data = Base64.decode64(data)
            data = Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(data)
            data = URI.decode_www_form_component(data)
            doc  = Nokogiri.XML(data)
        end
        
        abort "Diagram not recognized" unless doc.at('mxGraphModel')
        doc
    end
    
    def sql_generator(dialect)
        case options[:dialect]
        when 'h2'     then H2Generator.new
        when 'oracle' then OracleGenerator.new
        else abort "Unsupporto SQL dialect '#{options[:dialect]}'"
        end
    end
   
    def emit(text)
        if options[:stdout]
            puts text
        else
            FileUtils.mkdir_p File.dirname(options[:file])
            File.write options[:file], text
        end
    end
    
    def generate_sboot_commands(tables, env)
        return tables.map { |table| "sboot generate --env=#{env} #{table.name} #{sbootFields(table)}" }.join("\n")
    end
    
    def sbootFields(table)
        table.fields.map { |field| "#{field.name}:#{sbootType(field)}#{sbootConstraint(field)}"}.join(" ")
    end
    
    def sbootType(field)
        sbtype = if field.type =~ /^(\w+)/ then $1 else field.type end
        return ''     if sbtype.empty?
        return 'text' if sbtype.casecmp('char') == 0 # char type isn't recognized by sboot
        
        return sbtype if ['string','text','varchar','varchar2','number','long','int','integer','double','numeric','date'].include? sbtype.downcase
        
        STDERR.puts "WARNING: type #{sbtype} is not supported by sboot (field #{field.table.name}.#{field.name})"
        '' # fallthrough for an unrecognized type
    end
    
    def sbootConstraint(field)
        return "" if field.constraints.empty?
        ":#{field.constraints.join()}"
    end
    
    def generate_ddl(tables, generator)
        generator.multiline_comment("Create script for #{generator.name} database")+
                "\n"+
                tables.map { |table| generator.generate_table(table) }.join()
    end
    
    def get_tables(doc)
        tables = []
        
        doc.xpath('//mxCell[@parent="1"]').each do |node|
            table = Table.create_from_node node
            
            unless table.name.empty?
                tables.each { |tab| STDERR.puts "WARNING: table #{table.name} already declared" if tab.name == table.name }
                tables << table
            end
        end
        
        tables
    end
    
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
    
    class H2Generator < SqlGenerator
        def initialize
            super 'H2'
        end
    end
    
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
    
    class Field
        attr_accessor :id, :constraints, :not_null, :table
        alias_method  :not_null?, :not_null
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

CmdLine.start
