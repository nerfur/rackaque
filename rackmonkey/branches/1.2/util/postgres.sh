dropdb rackmonkey1_2
createdb -O rackmonkey rackmonkey1_2
psql -U rackmonkey rackmonkey1_2 < sql/schema/schema.postgres.sql 
psql -U rackmonkey rackmonkey1_2 < sql/data/default_data.sql 
psql -U rackmonkey rackmonkey1_2 < sql/data/sample_data.sql 
psql -U rackmonkey rackmonkey1_2 < sql/data/test_data.sql
