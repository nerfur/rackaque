dropdb rackmonkey-1_2
createdb -O rackmonkey-1_2 rackmonkey-1_2
psql -U rackmonkey-1_2 rackmonkey-1_2 < sql/schema/schema.postgres.sql 
psql -U rackmonkey-1_2 rackmonkey-1_2 < sql/data/default_data.sql 
psql -U rackmonkey-1_2 rackmonkey-1_2 < sql/data/sample_data.sql 
psql -U rackmonkey-1_2 rackmonkey-1_2 < sql/data/test_data.sql
