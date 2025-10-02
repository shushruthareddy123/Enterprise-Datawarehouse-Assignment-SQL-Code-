-- Optimization Strategy A — Add/Adjust Indexes
-- Helps filter EncounterDiagnosis by the few codes we care about,
-- then group by encounter efficiently.
CREATE INDEX idx_ed_code_encounter
  ON EncounterDiagnosis (diagnosis_code, encounter_id);

-- Supports grouping by department and month (and many date-range filters).
DROP INDEX idx_enc_dept_admit ON Encounter;
CREATE INDEX idx_enc_dept_admit ON Encounter (department_id, admit_dt);

-- (Bonus for other analytics) readmissions, patient timelines:
drop  index idx_enc_patient_admit  ON Encounter ;
CREATE INDEX idx_enc_patient_admit
  ON Encounter (patient_id, admit_dt);



-- Optimization Strategy B — Rewrite the Query to Pre-Aggregate

WITH dx_flags AS (
  SELECT
    e.encounter_id,
    e.department_id,
    DATE_FORMAT(e.admit_dt, '%Y-%m') AS month_key,
    -- Only scan the two codes we care about:
    MAX(ed.diagnosis_code = 'I10') AS has_i10,
    MAX(ed.diagnosis_code = 'E11') AS has_e11
  FROM Encounter e
  JOIN EncounterDiagnosis ed
    ON ed.encounter_id = e.encounter_id
   AND ed.diagnosis_code IN ('I10','E11')  -- <<< EARLY FILTER
  GROUP BY e.encounter_id, e.department_id, DATE_FORMAT(e.admit_dt, '%Y-%m')
)
SELECT
  d.name AS department,
  f.month_key,
  COUNT(*) AS encounters,
  SUM(CASE WHEN f.has_i10 = 1 AND f.has_e11 = 1 THEN 1 ELSE 0 END) AS both_i10_e11,
  ROUND(100.0 *
        SUM(CASE WHEN f.has_i10 = 1 AND f.has_e11 = 1 THEN 1 ELSE 0 END) / COUNT(*),
        2) AS comorbidity_rate_pct
FROM dx_flags f
JOIN Department d ON d.department_id = f.department_id
GROUP BY d.name, f.month_key
ORDER BY f.month_key, department;

-- Bonus: Readmissions Query Speed-up
-- Supports the window partition/order:
CREATE INDEX idx_enc_patient_admit ON Encounter (patient_id, admit_dt);

-- Add a time window to avoid scanning history unless you need it:
-- WHERE e.status = 'Closed'
--   AND e.discharge_dt IS NOT NULL
--   AND e.discharge_dt >= CURRENT_DATE - INTERVAL 12 MONTH
