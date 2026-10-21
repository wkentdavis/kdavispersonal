-- INTIIAL CODE
CREATE TABLE q5_output (
    Category VARCHAR(255),
    `Older Adult` INT,
    `Physical Disability` INT,
    `I/DD` INT,
    Total INT
);

INSERT INTO q5_output
WITH active_base AS (
    SELECT
        MID,
        `Population Category`,
        `Age Upon Application Approval`,
        `Actual Date of Transition`,
        `Actual MFP Disenrollment Date`,
        `Post Transition Withdrawal Date`
    FROM master_log
    WHERE `Actual Date of Transition` IS NOT NULL
      AND `Actual Date of Transition` <= '2025-12-31'
      AND (`Actual MFP Disenrollment Date` IS NULL OR `Actual MFP Disenrollment Date` >= '2025-12-31')
      AND (`Post Transition Withdrawal Date` IS NULL OR `Post Transition Withdrawal Date` = '')
),
long_hospitalizations AS (
    SELECT DISTINCT `MEDICAID #` as MID
    FROM mstr_critical_incidents
    WHERE `Nature of Critical Incident` = 'Hospitalization'
	  AND `Date of Critical Incident` BETWEEN '2025-07-01' AND '2025-12-31'
      AND `Days in Hospital` >= 30
),
reenrolled AS (
    SELECT DISTINCT MID
    FROM master_log
    WHERE MID LIKE '%#%'
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
            WHEN `Population Category` = 'I/DD' THEN 'I/DD'
            WHEN COALESCE(`Age Upon Application Approval`, 0) >= 65 THEN 'Older Adult'
            WHEN COALESCE(`Age Upon Application Approval`, 0) > 0 THEN 'Physical Disability'
            ELSE COALESCE(NULLIF(`Population Category`, ''), 'Physical Disability')
        END AS Population_Category_Upon_Approval
    FROM final_active
)
SELECT
    '2025 Period 2 (as of Dec 31, 2025)' AS Category,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Older Adult' THEN 1 ELSE 0 END) AS `Older Adult`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'Physical Disability' THEN 1 ELSE 0 END) AS `Physical Disability`,
    SUM(CASE WHEN Population_Category_Upon_Approval = 'I/DD' THEN 1 ELSE 0 END) AS `I/DD`,
    COUNT(*) AS Total
FROM classified;

SELECT *
FROM q5_output;

-- UPDATED TO GET ALL OPEN RECORDS
SELECT m.MEDICAID_ID,
		AGE_ON_APPROVAL, 
		DATE_OF_TRANSITION,
        DATE_MFP_APP_APPROVED, 
        MFP_DISENROLLMENT_DATE, 
        POSTTRANS_WITHDRAW_DATE
FROM data_mart.mfp_tracker_master_log m
WHERE  EXTRACT_DATE = '2026-08-01' AND 
	-- COUNTING TRANSITIONED PEOPLE WHO DID NOT DISENROLL -- 119
    ((DATE_OF_TRANSITION  <= '2025-06-30' AND DATE_OF_TRANSITION  >= '2025-01-01'  ) 
	OR (MFP_DISENROLLMENT_DATE <= '2025-06-30' AND MFP_DISENROLLMENT_DATE > '2025-01-01')
    AND POSTTRANS_WITHDRAW_DATE IS NULL)
       OR
    (DATE_MFP_APP_APPROVED <= '2025-06-30' AND DATE_OF_TRANSITION IS NULL AND 
    (PRETRANS_WITHDRAWAL_DATE IS NULL OR PRETRANS_WITHDRAWAL_DATE >= '2025-06-30') AND EXTRACT_DATE = '2026-08-01' );
    
    -- HERE ARE 251 PEOPLE WHO WERE PRE-TRANSITION IN THE PERIOD (ALL ARE EITHER WITHDRAWN-PRE TRNSITION OR NOT YET T'D)
    SELECT *
    FROM data_mart.mfp_tracker_master_log m
    WHERE DATE_MFP_APP_APPROVED <= '2025-06-30' AND DATE_OF_TRANSITION IS NULL AND 
    (PRETRANS_WITHDRAWAL_DATE IS NULL OR PRETRANS_WITHDRAWAL_DATE >= '2025-06-30') AND LATEST_RECORD = 1; 
