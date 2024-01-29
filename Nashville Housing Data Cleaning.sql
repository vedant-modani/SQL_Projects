-- Cleaning Data in MySQL

-- Checking all data
SELECT * 
FROM nashville_housing;

-- Checking the datatypes to convert them for proper transformations
DESCRIBE	nashville_housing

-- converting empty strings ('') to NULL for better transformations 
UPDATE nashville_housing
SET
  ownername = NULLIF(ownername, ''),
  acreage = NULLIF(acreage, ''),
  taxdistrict = NULLIF(taxdistrict, ''),
  landvalue = NULLIF(landvalue, ''),
  buildingvalue = NULLIF(buildingvalue, ''),
  totalvalue = NULLIF(totalvalue, ''),
  bedrooms = NULLIF(bedrooms, ''),
  fullbath = NULLIF(fullbath, ''),
  halfbath = NULLIF(halfbath, ''),
  yearbuilt = NULLIF(yearbuilt, ''),
  owner_state = NULLIF(owner_state, ''),
  owner_city = NULLIF(owner_city, ''),
  owner_address = NULLIF(owner_address, '');

-- removing symbols from 
UPDATE nashville_housing
SET saleprice = REPLACE(REPLACE(saleprice, '$', ''), ',', ''),
SET acreage = REPLACE(REPLACE(acreage, '$', ''), ',', '');

-- converting numerical values from string to integer and decimals
ALTER TABLE nashville_housing
MODIFY COLUMN saleprice INT,
MODIFY COLUMN acreage DECIMAL(10,2),
MODIFY COLUMN landvalue INT,
MODIFY COLUMN buildingvalue INT,
MODIFY COLUMN totalvalue INT,
MODIFY COLUMN bedrooms INT,
MODIFY COLUMN fullbath INT,
MODIFY COLUMN halfbath INT;

-- Adding a new date column for the yearbuilt column for better operations
ALTER TABLE nashville_housing
ADD COLUMN year_built DATE;

UPDATE nashville_housing
SET year_built = STR_TO_DATE(CONCAT(yearbuilt, '-01-01'), '%Y-%m-%d');

ALTER TABLE nashville_housing
DROP COLUMN yearbuilt;

-- Convert saledate to a Date Format
-- Add a new column of DATE type
ALTER TABLE nashville_housing
ADD COLUMN sale_date DATE;

-- Update the new column with converted dates
UPDATE nashville_housing
SET sale_date = STR_TO_DATE(saledate, '%M %e, %Y');

-- Convert the DATE column to the desired format
UPDATE nashville_housing
SET sale_date = DATE_FORMAT(sale_date, '%Y/%m/%d');

-- Drop the old VARCHAR column if needed
ALTER TABLE nashville_housing
DROP COLUMN saledate;

-- Handling Missing Data
-- Populate propertyaddress data
UPDATE nashville_housing
SET propertyaddress = (SELECT b.propertyaddress
                      FROM nashville_housing b
                      WHERE nashville_housing.parcelid = b.parcelid
                        AND nashville_housing.uniqueid <> b.uniqueid
                        AND propertyaddress != ""
                      LIMIT 1)
WHERE propertyaddress = "";

-- Breaking out Address into Individual Columns (Address, City, State)

-- Add new column for property_address
ALTER TABLE nashville_housing
Add COLUMN property_address NVARCHAR(255);

-- Add the property address values to new column
UPDATE nashville_housing
SET property_address = SUBSTR(propertyaddress,1,INSTR(propertyaddress,',')-1);

-- Add new column for property_city
ALTER TABLE nashville_housing
Add COLUMN property_city NVARCHAR(255);

-- Add the property city values to new column
UPDATE nashville_housing
SET property_city = SUBSTR(propertyaddress,INSTR(propertyaddress,',')+1,LENGTH(propertyaddress));

-- Drop the old column
ALTER TABLE nashville_housing
DROP COLUMN propertyaddress;

-- Add new columns to store extracted values
ALTER TABLE nashville_housing
ADD COLUMN owner_state VARCHAR(255),
ADD COLUMN owner_city VARCHAR(255),
ADD COLUMN owner_address VARCHAR(255);

-- Update the new columns with extracted values
UPDATE nashville_housing
SET
  owner_state = SUBSTRING_INDEX(REPLACE(owneraddress, ',', '.'), '.', -1),
  owner_city = SUBSTRING_INDEX(SUBSTRING_INDEX(REPLACE(owneraddress, ',', '.'), '.', -2), '.', 1),
  owner_address = SUBSTRING_INDEX(REPLACE(owneraddress, ',', '.'), '.', 1);
  
  -- Drop the old column
ALTER TABLE nashville_housing
DROP COLUMN owneraddress;

-- Standardising soldasvacant column
UPDATE nashville_housing
SET soldasvacant = CASE WHEN soldasvacant = 'Y' THEN 'Yes'
	   WHEN soldasvacant = 'N' THEN 'No'
	   ELSE soldasvacant
	   END
	   
-- Drop duplicates
DELETE FROM nashville_housing
WHERE UniqueID IN (
    SELECT UniqueID
    FROM (
        SELECT UniqueID,
               ROW_NUMBER() OVER (
                   PARTITION BY ParcelID,
                                Property_Address,
                                SalePrice,
                                Sale_Date,
                                LegalReference
                   ORDER BY UniqueID
               ) AS row_num
        FROM nashville_housing
    ) AS RowNum
    WHERE row_num > 1
);

/*
31,158 of the remaining 56,373 rows have missing values in several important columns describing the property like bedrooms, baths, acreage, taxdistrict, etc. 
The data seems to fall under Missing Completely at Random category of Missing Data. Dropping this data will lead to removal of 55% of the data. 
Similarly imputing mean for 55% of the records will alter the data at a great level. 
As a solution, I am going to conduct statistics on the available data without any further transformations. 
For example, as saledata is available for every record, the statistics will include all records. 
But as acreage is not available for all records, I will filter the NULL values out for any calculations involving acreage.
*/

-- Summary Statistics as part of Data Exploration
-- finding the average max and min values of saleprice
SELECT ROUND(AVG(saleprice),2), MAX(saleprice), MIN(saleprice)
FROM	nashville_housing

-- finding median saleprice 
SELECT 
  AVG(saleprice) AS median
FROM (
  SELECT
    saleprice,
    ROW_NUMBER() OVER (ORDER BY saleprice) AS row_num,
    COUNT(*) OVER () AS total_rows
  FROM
    nashville_housing
) AS subquery
WHERE
  row_num BETWEEN total_rows / 2 AND total_rows / 2 + 1;

-- finding average sale price by land use
SELECT landuse, ROUND(AVG(saleprice),2)
FROM	nashville_housing
GROUP BY landuse

-- finding average sale price by property city
SELECT property_city, ROUND(AVG(saleprice),2)
FROM	nashville_housing
GROUP BY property_city

-- mode of land use
SELECT landuse, COUNT(landuse)
FROM	nashville_housing
GROUP BY landuse
ORDER BY COUNT(landuse) DESC

-- mode of property_city
SELECT property_city, COUNT(landuse)
FROM	nashville_housing
GROUP BY property_city
ORDER BY COUNT(landuse) DESC

-- finding rates by land use 
SELECT landuse, ROUND(AVG(saleprice/acreage),2) AS price_per_acre
FROM	nashville_housing
WHERE	acreage IS NOT NULL
GROUP BY landuse

-- finding rates by land use 
SELECT property_city, ROUND(AVG(saleprice/acreage),2) AS price_per_acre
FROM	nashville_housing
WHERE	acreage IS NOT NULL
GROUP BY property_city

-- finding premiums paid by calculating difference of saleprice and total value
SELECT property_city, ROUND(AVG(saleprice - totalvalue),2) AS premium_paid
FROM nashville_housing
WHERE totalvalue IS NOT NULL
GROUP BY property_city

SELECT landuse, ROUND(AVG(saleprice - totalvalue),2) AS premium_paid
FROM nashville_housing
WHERE totalvalue IS NOT NULL
GROUP BY landuse

-- finding premiums paid by acre
SELECT property_city, ROUND(AVG((saleprice - totalvalue)/acreage ),2)AS premium_per_acre
FROM nashville_housing
WHERE totalvalue IS NOT NULL
GROUP BY property_city

SELECT landuse, ROUND(AVG((saleprice - totalvalue)/acreage),2) AS premium_per_acre
FROM nashville_housing
WHERE totalvalue IS NOT NULL
GROUP BY landuse
