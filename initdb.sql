CREATE DATABASE hue_d WITH lc_collate='en_US.utf8';
CREATE USER hue_u WITH PASSWORD 'huepassword';
GRANT ALL PRIVILEGES ON DATABASE hue_d TO hue_u;
ALTER DATABASE hue_d OWNER TO hue_u;