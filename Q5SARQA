/* PERFORM QA OF THE CODE INCREMENTALLY */
WITH active_base AS (
    SELECT m.MEDICAID_ID MID,
		POPULATION_CATEGORY,
		AGE_ON_APPROVAL, 
		DATE_OF_TRANSITION,
        DATE_MFP_APP_APPROVED, 
        MFP_DISENROLLMENT_DATE, 
        POSTTRANS_WITHDRAW_DATE,
        CASE
            WHEN POPULATION_CATEGORY = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(POPULATION_CATEGORY, ''), 'Physical Disability')
        END AS Population_Category_Upon_Approval 
FROM data_mart.mfp_tracker_master_log m
WHERE  LATEST_RECORD = 1 AND 
	-- COUNTING TRANSITIONED PEOPLE WHO DID NOT DISENROLL -- 119
    ((DATE_OF_TRANSITION  <= '2025-06-30' AND DATE_OF_TRANSITION  >= '2025-01-01'  ) 
	OR (MFP_DISENROLLMENT_DATE <= '2025-06-30' AND MFP_DISENROLLMENT_DATE > '2025-01-01')
    AND POSTTRANS_WITHDRAW_DATE IS  NULL)
       OR
    (DATE_MFP_APP_APPROVED <= '2025-06-30' AND DATE_OF_TRANSITION IS NULL AND 
    (PRETRANS_WITHDRAWAL_DATE IS NULL OR PRETRANS_WITHDRAWAL_DATE >= '2025-06-30') AND EXTRACT_DATE = '2026-08-01' )
),
long_hospitalizations AS (
    SELECT DISTINCT MEDICAID_ID as MID
    FROM data_mart.mfp_tracker_critical_incidents
    WHERE INCIDENT_TYPE = 'Hospitalization'
	  AND CRITICAL_INCIDENT_DATE BETWEEN '2025-01-01' AND '2025-06-30'
      AND DAYS_IN_HOSPITAL >= 30
),
reenrolled AS (
    SELECT DISTINCT MEDICAID_ID MID
FROM data_mart.mfp_tracker_master_log m
    WHERE MEDICAID_ID LIKE '%#%'
),
final_active AS (
    SELECT ab.*
    FROM active_base ab
    LEFT JOIN long_hospitalizations lh
        ON ab.MID = lh.MID
    LEFT JOIN reenrolled r
        ON ab.MID = r.MID
    WHERE lh.MID IS NULL
      OR r.MID IS NOT NULL
),
classified AS (
    SELECT
        CASE
            WHEN POPULATION_CATEGORY = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(AGE_ON_APPROVAL, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(POPULATION_CATEGORY, ''), 'Physical Disability')
        END AS Population_Category_Upon_Approval
    FROM final_active
)

/* check dupes
SELECT MID, COUNT(*) 
FROM final_active
GROUP BY MID
HAVING Count(*) >1
-- no dupes
*/
/*  check categories - FINE
select  POPULATION_CATEGORY, AGE_ON_APPROVAL, COUNT(*)
FROM final_active
GROUP BY 1,2 ORDER BY 3 DESC;
*/

/*SELECT * FROM active_base ab
join long_hospitalizations lh on ab.MID=lh.MID; -- no rows
*/

SELECT 'active base' as stage, COUNT(*) FROM active_base
union all
SELECT 'longhosp' as stage, COUNT(*) FROM long_hospitalizations
union all
SELECT 'reenrolled' as stage, COUNT(*) FROM reenrolled
union all
SELECT 'finalactive' as stage, COUNT(*) FROM final_active
union all
SELECT 'classified' as stage, COUNT(*) FROM classified;
/* results
active base	370
longhosp	2
reenrolled	0
finalactive	370
classified	370
*/   -- how does this translate to 367 as a final count?
/* LONG HOSP CHECK
SELECT * FROM active_base ab
join long_hospitalizations lh on ab.MID=lh.MID
*/
SELECT * FROM measures.q5_output where YEAR = 2025 AND SEMI_PERIOD = '1' order by year, semi_period, month_last_date; 

-- QUESTION IS WHY DO WE HAVE 40 MORE PDs THAN THE OFFICIAL SAR?  there are 32 records of PD of people who transitioned, vs the null trans date
-- OR COULD BE SOME PEOPLE COME IN AS OLDER ADULTS EVEN THOUGH THEY ARE UNDER 65 (ABOUT 20)
