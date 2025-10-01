 -- Advance SQL Queries
 -- Q1) Readmissions within 30 days (by department & month)
 --  Business question:
  --   Which departments see the highest 30-day readmission
    -- counts and rates each month?
   -- Techniques:
     -- Multi-table JOINs
     -- Window function (LEAD)
     -- CASE
     -- GROUP BY
WITH enc AS (
  SELECT
    e.encounter_id,
    e.patient_id,
    e.department_id,
    e.admit_dt,
    e.discharge_dt,
    LEAD(e.admit_dt) OVER (
      PARTITION BY e.patient_id
      ORDER BY e.admit_dt
    ) AS next_admit_dt
  FROM Encounter e
  WHERE e.status = 'Closed'
    AND e.discharge_dt IS NOT NULL
)
SELECT
  d.name AS department,
  DATE_FORMAT(e.discharge_dt, '%Y-%m') AS month_key,
  COUNT(*) AS discharges,
  SUM(
    CASE
      WHEN e.next_admit_dt IS NOT NULL
       AND TIMESTAMPDIFF(DAY, e.discharge_dt, e.next_admit_dt) BETWEEN 0 AND 30
      THEN 1 ELSE 0
    END
  ) AS readmissions_30d,
  ROUND(
    100.0 * SUM(
      CASE
        WHEN e.next_admit_dt IS NOT NULL
         AND TIMESTAMPDIFF(DAY, e.discharge_dt, e.next_admit_dt) BETWEEN 0 AND 30
        THEN 1 ELSE 0
      END
    ) / COUNT(*), 2
  ) AS readmit_rate_pct
FROM enc e
JOIN Department d ON d.department_id = e.department_id
GROUP BY d.name, DATE_FORMAT(e.discharge_dt, '%Y-%m')
ORDER BY month_key, department;

-- Quick preview (limit rows in clients that support LIMIT):
-- (Remove LIMIT if your client doesn't allow it after CTE)
-- WITH enc AS (... same as above ...) SELECT ... ORDER BY ... LIMIT 20;


/* =======================================================
   Q2) Hypertension + Diabetes comorbidity rate (by dept & month)
   Business question:
     How often do encounters present both hypertension (I10)
     and type-2 diabetes (E11)?
   Techniques:
     - JOINs
     - Conditional aggregation with CASE
     - GROUP BY (and optional HAVING)
======================================================= */
SELECT
  d.name AS department,
  f.month_key,
  COUNT(*) AS encounters,
  SUM(CASE WHEN f.has_i10 = 1 AND f.has_e11 = 1 THEN 1 ELSE 0 END) AS both_i10_e11,
  ROUND(
    100.0 * SUM(CASE WHEN f.has_i10 = 1 AND f.has_e11 = 1 THEN 1 ELSE 0 END) / COUNT(*),
    2
  ) AS comorbidity_rate_pct
FROM (
  SELECT
    e.encounter_id,
    e.department_id,
    DATE_FORMAT(e.admit_dt, '%Y-%m') AS month_key,
    MAX(ed.diagnosis_code = 'I10') AS has_i10,
    MAX(ed.diagnosis_code = 'E11') AS has_e11
  FROM Encounter e
  JOIN EncounterDiagnosis ed ON ed.encounter_id = e.encounter_id
  GROUP BY e.encounter_id, e.department_id, DATE_FORMAT(e.admit_dt, '%Y-%m')
) AS f
JOIN Department d ON d.department_id = f.department_id
GROUP BY d.name, f.month_key
ORDER BY f.month_key, department;

-- Optional focus on busy months:
-- ... GROUP BY ... HAVING encounters >= 5 ORDER BY ...;


/* =======================================================
   Q3) Top 3 procedures by department (last 60 days)
   Business question:
     What are the top procedures performed per department recently?
   Techniques:
     - Multi-table JOINs
     - Aggregation
     - Window function (ROW_NUMBER)
======================================================= */
WITH proc_counts AS (
  SELECT
    d.name AS department,
    pc.procedure_code,
    pc.description,
    SUM(COALESCE(ep.quantity,1)) AS total_qty
  FROM EncounterProcedure ep
  JOIN ProcedureCode pc ON pc.procedure_code = ep.procedure_code
  JOIN Encounter e ON e.encounter_id = ep.encounter_id
  JOIN Department d ON d.department_id = e.department_id
  WHERE ep.performed_dt >= (CURRENT_DATE - INTERVAL 60 DAY)
  GROUP BY d.name, pc.procedure_code, pc.description
),
ranked AS (
  SELECT
    department, procedure_code, description, total_qty,
    ROW_NUMBER() OVER (PARTITION BY department ORDER BY total_qty DESC) AS rn
  FROM proc_counts
)
SELECT department, procedure_code, description, total_qty
FROM ranked
WHERE rn <= 3
ORDER BY department, total_qty DESC;




/* =======================================================
   Q4) Claim outliers vs plan-month average
   Business question:
     Which claims are unusually high compared to their plan’s
     monthly average?
   Techniques:
     - JOINs
     - Window function (AVG OVER PARTITION)
     - CASE
======================================================= */
WITH plan_month AS (
  SELECT
    c.claim_id,
    c.plan_id,
    ip.plan_name,
    p.name AS payer,
    DATE_FORMAT(c.claim_dt, '%Y-%m') AS month_key,
    c.amount,
    AVG(c.amount) OVER (
      PARTITION BY c.plan_id, DATE_FORMAT(c.claim_dt, '%Y-%m')
    ) AS plan_month_avg
  FROM Claim c
  JOIN InsurancePlan ip ON ip.plan_id = c.plan_id
  JOIN Payer p ON p.payer_id = ip.payer_id
)
SELECT
  payer,
  plan_name,
  month_key,
  claim_id,
  amount,
  ROUND(plan_month_avg,2) AS plan_month_avg,
  CASE
    WHEN amount >= 2.0 * plan_month_avg THEN 'Very High (>= 2x)'
    WHEN amount >= 1.5 * plan_month_avg THEN 'High (>= 1.5x)'
    ELSE 'Normal'
  END AS outlier_flag
FROM plan_month
 -- WHERE amount >= 1.5 * plan_month_avg
ORDER BY month_key, payer, plan_name, amount DESC;

-- Preview tip: Remove the WHERE clause to see all claims and their flags.


/* =======================================================
   Q5) Latest A1C per patient (uncontrolled diabetes)
   Business question:
     Which patients’ latest A1C indicates poor control (A1C >= 7.0)?
   Techniques:
     - JOINs
     - Correlated subquery to get latest A1C per patient
     - CASE
======================================================= */
SELECT
  p.patient_id,
  p.first_name,
  p.last_name,
  lr.result_value AS latest_a1c,
  DATE(lr.collected_dt) AS collected_date,
  CASE
    WHEN lr.result_value >= 9.0 THEN 'Very High'
    WHEN lr.result_value >= 7.0 THEN 'High'
    ELSE 'OK'
  END AS control_flag
FROM LabResult lr
JOIN Encounter e ON e.encounter_id = lr.encounter_id
JOIN Patient p   ON p.patient_id   = e.patient_id
WHERE lr.lab_test_code = 'A1C'
  AND lr.collected_dt = (
    SELECT MAX(lr2.collected_dt)
    FROM LabResult lr2
    JOIN Encounter e2 ON e2.encounter_id = lr2.encounter_id
    WHERE lr2.lab_test_code = 'A1C'
      AND e2.patient_id = e.patient_id
  )
  AND lr.result_value >= 7.0
ORDER BY latest_a1c DESC, collected_date DESC;