-- SAR Q7 REENROLLMENTS
-- Assume Q2 2025 to test
/*    CREATE TABLE q7_output (
    Category VARCHAR(255),
    `Older Adult` INT,
    `Physical Disability` INT,
    `I/DD` INT,
    Total INT
);
INSERT INTO q7_output 
*/

-- core sar output runs for the current time period
WITH in_period AS (
    SELECT
        IN_MFP_BEFORE,
        MEDICAID_ID,
        MFP_ID,
        POPULATION_CATEGORY,
        AGE_ON_APPROVAL
    FROM data_mart.mfp_tracker_master_log master_log
    WHERE DATE_MFP_APP_APPROVED BETWEEN '2025-07-01' AND '2025-12-31'
    and LATEST_RECORD = 1
),
reenrolled AS (
    SELECT
        *
    FROM in_period
    WHERE LOWER(TRIM(COALESCE(IN_MFP_BEFORE, ''))) = 'yes'
       OR MEDICAID_ID LIKE '%#%'
),
 classified AS (
    SELECT
        CASE
            WHEN POPULATION_CATEGORY = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(POPULATION_CATEGORY, ''), 'Physical Disability')
        END AS Population_Category_Upon_Approval
    FROM reenrolled
)
SELECT
    '2025 Period 2 (Jul 1 – Dec 31)' AS Category,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Older Adult' THEN 1 ELSE 0 END) AS `Older Adult`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Physical Disability' THEN 1 ELSE 0 END) AS `Physical Disability`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'I/DD' THEN 1 ELSE 0 END) AS `I/DD`,
    0 as 'Brain Injury', 
    COUNT(*) AS Total
FROM classified;

-- Create Code to dump into the measure structure (Historical SAR tables?)
-- Does this work over time ? Change Start year from 2025 to 2021...And Add the SAR Periods as group bys.

WITH in_period AS (
    SELECT
        IN_MFP_BEFORE,
        MEDICAID_ID,
        MFP_ID,
        POPULATION_CATEGORY,
        AGE_ON_APPROVAL,
        DATE_MFP_APP_APPROVED,
        concat(Cal.Calendar_Year,' ',Cal.Semi_Annual_Period) SARPeriod
    FROM data_mart.mfp_tracker_master_log master_log
    INNER JOIN reference.calendar Cal 
        ON master_log.DATE_MFP_APP_APPROVED = Cal.Calendar_Date
    WHERE DATE_MFP_APP_APPROVED BETWEEN '2021-01-01' AND '2025-12-31'
    and LATEST_RECORD = 1
),
reenrolled AS (
    SELECT
        *
    FROM in_period
    WHERE LOWER(TRIM(COALESCE(IN_MFP_BEFORE, ''))) = 'yes'
       OR MEDICAID_ID LIKE '%#%'
),
classified AS (
    SELECT
		SARPeriod,
        CASE
            WHEN POPULATION_CATEGORY = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(POPULATION_CATEGORY, ''), 'Physical Disability')
        END AS Population_Category_Upon_Approval
    FROM reenrolled
)
SELECT
    SARPeriod,
    -- '2025 Period 2 (Jul 1 – Dec 31)' AS Category,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Older Adult' THEN 1 ELSE 0 END) AS `Older Adult`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Physical Disability' THEN 1 ELSE 0 END) AS `Physical Disability`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'I/DD' THEN 1 ELSE 0 END) AS `I/DD`,
    0 as 'Brain Injury', 
    COUNT(*) AS Total
FROM classified
GROUP BY SARPeriod order by 1;

-- ************************************************************************************
-- and the measure file layout
WITH Q7int AS (
 SELECT MFP_ID,
		Cal.Calendar_Year,
        Cal.Month_First_Date,
        Cal.Month_Last_Date,
         CASE
            WHEN POPULATION_CATEGORY = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(POPULATION_CATEGORY, ''), 'Physical Disability')
        END AS POPCAT,
       DATE_MFP_APP_APPROVED
    FROM data_mart.mfp_tracker_master_log master_log
		INNER JOIN reference.calendar Cal ON master_log.DATE_MFP_APP_APPROVED  = Cal.Calendar_Date
  WHERE DATE_MFP_APP_APPROVED BETWEEN '2025-07-01' AND '2025-12-31'
		AND (LOWER(TRIM(COALESCE(IN_MFP_BEFORE, ''))) = 'yes'
       OR MEDICAID_ID LIKE '%#%')
      AND LATEST_RECORD = 1
 )
 SELECT 
	'0'  REPORTID,
    'SAR07'  SECTION,
    'REENROLL'  MSR,
	Calendar_Year CALYEAR,
	'M' TIMEFRAME,
	Month_First_Date STARTDT,
	Month_Last_Date ENDDT,
	'POPULATION CATEGORY' STRAT,
	POPCAT STRATVAL,
	COUNT(MFP_ID) NUM,
	NULL DENOM,
	 COUNT(MFP_ID)  VAL,
	'MASTER LOG' SOURCE,
	NOW() LOADDT,
	'KDVIS' LOADEDBY,
	NOW() EXTRACTDT
 FROM  Q7int
 GROUP BY 
	Calendar_Year,
	Month_First_Date,
	Month_Last_Date,
	POPCAT
 ;
