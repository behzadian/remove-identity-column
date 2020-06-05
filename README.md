# Remove Identity Column
You know you can't drop identity increment of a column only with a command? You must drop column with identity that is so awkward!
I had a very large project that uses more than 100 database table to store information. One day I decided to convert key generations from identity to HiLow (in NHibernate) for better performace and I faced to this problem
Finally I decided to generate a stored producer to drop old identity column and generate new un-identity primary key column.
This stored producer does followings:
1. Takes table name, an optionally current identity primary key column name (or `ID` if not specified) and an optionally temporairly column name during changes for current column (or `IdentityID` if not specified)
2. Renames current column to temporairly name
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
