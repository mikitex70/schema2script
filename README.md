# schema2script
Utility for generation of DDL script from www.draw.io ER schemas.

## Installation
To install this script use these commands:

```
bundle install
bundle exec rake install
```

## Usage

### help
Gives help about available commands. Example:

```
schema2script help
```

### sboot
Generates [sboot](https://github.com/Simo/sboot) commands that can be used to generate a Java skeleton application given an ER diagram. Example:

```
schema2script sboot mySchema.xml
```

After execution you will find the file `sboot_commands.sh` (may be changed with the `--file` option) containing the list of [sboot](https://github.com/Simo/sboot) commands to execute. To exec these commands in bash run:

```
. sboot_commands.sh
```

In windows run a command like this:

```
cmd /C sboot_commands.sh
```

Running the script would generate a basic structure for a Java application operating on the entities defined in the schema diagram.

Use `schema2script help sboot` for a more detailed list of options.

### ddl
This command wil generate an SQL DDL script that can be used to create a database structure (at this time tables and some constraints). Example:

```
schema2script ddl mySchema.xml
```

Executing this command will generate the file `src/main/resources/database/db_create.sql` (may be overriden with the `--file` option) containing the SQL statements for creating the tables with the H2 database.

For creating a script for Oracle databases, use the following command:

```
schema2script ddl --dialect=oracle mySchema.xml
```

Use `schema2script help ddl` for a more detailed list of options.

### validate
Validates the ER schema without generating scripts. For example:

```
schema2script validate mySchema.xml
```

#### Validations performed

* duplicate table name
* field declared `NOT NULL` but with `NULL` default value
* for Oracle dialect:

    * size of textual fields (eg. `VARCHAR`, `VARCHAR2`, etc.) greater than 4095

# ER schema tuning
The www.draw.io ER schema can be tuned for the `sboot` and the `ddl` commands by adding *attributes* to tables, columns and relations.

## Table attributes

* `comment`: `string`, comment for the table
* `preScript`: `string`, script/text to generate before the CREATE TABLE
* `postScript`: `string`, script/text to generate after the CREATE TABLE (after the COMMENT and ALTER TABLE instructions)
* `plural`: `string`, plural name for the table

## Column attributes

* `comment`: `string`, comment for the column
* `default`: `string`, default value for the field

    * for strings non need of quotes; single quotes are duplicated to prevent breaking of the SQL literal
    * for dates and times, can be used the Ruby syntax (eg. '11 May 2017'); italian months names are recognized
    
* `notNull`: `boolean`, if set then a `NOT NULL` constraint will be generated

## Relation attributes

* `reverseRelation`: `boolean`, reverse the relation direction (instead of deleteting and redrawing it on the schema)
