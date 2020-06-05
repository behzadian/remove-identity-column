# Remove Identity Column
Did you know you can't drop identity increment of a column only with a command? You must drop column with identity that is so awkward!
I had a very large project that uses more than 100 database table to store information. One day I decided to convert key generations from identity to HiLow (in NHibernate) for better performace and I faced to this problem.

Finally I decided to generate a stored producer to drop old identity column and generate new un-identity primary key column.
This stored producer does followings:
1. Takes table name, an optionally current identity primary key column name (or `ID` if not specified) and an optionally temporarily column name during changes for current column (or `IdentityID` if not specified)
2. Renames current column to temporarily name
3. Creates new INT column with primary key column name (as specified in 2th argument)
4. Copies all current IDs to new `ID` column
5. Makes new `ID` column NOT-NULLABLE
6. Drops all Indexes related to current (renamed) primary key column 
7. Drops all foreign keys related to current (renamed) primary key column 
8. Drops all FullText Indexes related to current (renamed) primary key column 
9. Drops primary key column
10. Creates primary key on new column
11. Creates all dropped indexes but for new primary key column (also indexes that includes `ID` column)
12. Creates all dropped foreign keys but for new primary key column
13. Creates all dropped fulltext indexes but for new primary key column

For creating this script, I changed and used 3 different script (that I don't remember their author now, but I'll reference them later)

# How it works?
This script creates 2 sql scaler function that will be used in generated stored producer. 
After running script @DropTableIdentityMethods.sql, you can call stored producer with passing table full name like below:
`exec DropIdentityColumn 'dbo.table'`
you must pass table full name ([owner].[table]).

also there is a script named [@DropTableIdentities.sql] that runs sp for every table in database.

## what will happen if my table has not identity column?
Nothing! if column you specified (or `table`.ID as default name of identity column), has not identity, sp will stop

## what if I run sp multiple times with a table?
Nothing! for first time, sp drop identity from column, for other runs, will do nothing, because there is no identity!

## What if some indexes defined over identity column?
DropIdentityColumn sp drops all indexes that defined over identity column, and at end, recreate them

## What if some indexes defined includes identity colunmn?
Like normal index, they will be drop and will recreate at the end

## What if there were other indexes in table that not defined over identity column nor includes it?
Nothing. DropIdentityColumn sp does not touch them

## What if there were some foreign keys?
DropIdentityColumn sp will drop keys at start and recreate them at end

## What if there were some FullText indexes?
Like indexes DropIdentityColumn sp will FT indexes at start and recreate them at end. DropIdentityColumn does not drop or recreate FullText catalogs

## Primary key?
Like any indexes, DropIdentityColumn will drop PK at first and recreate it at end

# BE CAREFULL!
Before any use of DropIdentityColumn, take a full backup from database in case of any problem, so you can restore it. DropIdentityColumn sp has not beeen tested fully and may create undesired or unpredicated results. use it at your own risk!
