use YELP_DB;

-- ------------------------------------------
-- Insert raw data into temp tables        --
-- ------------------------------------------
load data INFILE '/var/lib/mysql-files/yelp_business.csv' 
into table BusinessTemp fields terminated BY ',' ENCLOSED BY '"' IGNORE 1 LINES
(business_id,name,@vNB,address,city,state,postal_code,latitude,longitude,stars,review_count,is_open,categories) 
SET neighborhood = nullif(@vNB, '');

-- followers is VARCHAR(5000) --> can fit max 200 user IDs in variable (see below: 4798 < 5000)
-- user_id = '0njfJmB-7n84DlIgUByCNw'
-- 4798 = len(user_id+', '+ 198*(user_id+', ') + user_id) 
load data INFILE '/var/lib/mysql-files/yelp_user.csv' 
into table UserTemp 
FIELDS TERMINATED BY ',' ENCLOSED BY '"' LINES TERMINATED BY "\r\n" IGNORE 1 LINES 
(user_id,name,@vRC,@vYsince,@vFollowers,@vUseful,@vFunny,@vCool,@vFans,@dummy,average_stars,@dummy,@dummy,@dummy,@dummy,@dummy,@dummy,@dummy,@dummy,@dummy, @dummy, @dummy)
SET review_count = cast(@vRC as unsigned), useful = cast(@vUseful as unsigned), 
funny = cast(@vFunny as unsigned), cool = cast(@vCool as unsigned),
followers = left(@vFollowers, 4798), yelping_since = @vYsince, last_online = @vYsince;

-- -------------------------------------------------------------------------
-- Move User & Business data from temp tables to normalized tables        --
-- -------------------------------------------------------------------------

-- Delete businesses that don't have a latitude or longitude value 
--   (only 1 exists --> business_id = 'W1x0rlzGUrMBbK3Hq5bk2Q') 
delete from BusinessTemp where latitude = '' or longitude = '';

-- Insert all distinct pairs of latitude and longitude, 
--   with their corresponding location details into AddressLocations table
insert into AddressLocations
select latitude, longitude, ANY_VALUE(neighborhood), ANY_VALUE(address), 
ANY_VALUE(city), ANY_VALUE(state), ANY_VALUE(postal_code)
from BusinessTemp
group by latitude, longitude;

insert into Business
select business_id, name, latitude, longitude, stars, review_count, is_open
from BusinessTemp;


-- -----------------------------------------------------------------------------
-- Checkin, Review, and Tip tables are already normalized... Insert raw data  --
-- -----------------------------------------------------------------------------
load data INFILE '/var/lib/mysql-files/yelp_checkin.csv' 
into table Checkin fields terminated BY ',' IGNORE 1 LINES
(business_id,weekday,hour,checkins);

load data INFILE '/var/lib/mysql-files/yelp_review.csv' 
into table Review 
fields terminated BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(review_id,user_id,business_id,@vStars,date,@vText,@vUseful,@vFunny,@vCool)
SET stars  = cast(@vStars as unsigned), useful  = cast(@vUseful as unsigned),
text = left(@vText, 5000), funny = cast(@vFunny as unsigned), cool  = cast(@vCool as unsigned);

load data INFILE '/var/lib/mysql-files/yelp_tip.csv' 
into table Tip 
fields terminated BY ',' ENCLOSED BY '"' LINES TERMINATED BY '\r\n' IGNORE 1 LINES
(text,date,likes,business_id,user_id);

