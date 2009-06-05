DROP DATABASE rackmonkey1_2;
CREATE DATABASE rackmonkey1_2;
USE rackmonkey1_2;
\. /Users/flux/Sites/1.2/sql/schema/schema.mysql.sql
\. /Users/flux/Sites/1.2/sql/data/default_data.sql
\. /Users/flux/Sites/1.2/sql/data/sample_data.sql
\. /Users/flux/Sites/1.2/sql/data/test_data.sql
GRANT ALL ON rackmonkey1_2.* TO 'rackmonkey'@'localhost' IDENTIFIED BY '7jhH#98*';
GRANT ALL ON rackmonkey1_2.* TO 'rackmonkey'@'%' IDENTIFIED BY '7jhH#98*';
FLUSH PRIVILEGES;
