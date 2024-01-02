-- Cleaning Data in MySQL

-- Checking all data
SELECT * 
FROM nashville_housing;

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

