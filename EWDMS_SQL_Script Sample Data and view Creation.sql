USE healthcare;
SET FOREIGN_KEY_CHECKS = 0;

-- =========================
-- Inserting Data 
-- =========================
INSERT INTO Patient (nhs_no, first_name, last_name, sex, dob) VALUES
('NHS001','Ava','Schmidt','F','1989-03-14'),
('NHS002','Liam','Müller','M','1978-11-02'),
('NHS003','Mia','Wagner','F','1995-07-21'),
('NHS004','Noah','Becker','M','2001-01-09'),
('NHS005','Emma','Hoffmann','F','1983-05-30');

INSERT INTO Provider (provider_code, name, role) VALUES
('PRV001','Dr. Julia Kern','Physician'),
('PRV002','Dr. Felix Roth','Physician'),
('PRV003','Nurse Lina Vogt','Nurse'),
('PRV004','Dr. Jonas Wolf','Physician'),
('PRV005','Nurse Erik Hahn','Nurse');

INSERT INTO Department (name) VALUES
('Emergency'),
('Cardiology'),
('Outpatient Clinic'),
('Orthopedics'),
('Laboratory');

-- Provider ↔ Department (M:N)
INSERT INTO ProviderDepartment (provider_id, department_id, start_dt) VALUES
(1,1,'2022-01-01'),
(2,2,'2021-06-01'),
(3,1,'2023-09-01'),
(4,3,'2020-03-01'),
(5,4,'2024-02-01');

-- Clinical vocabularies
INSERT INTO Diagnosis (diagnosis_code, description) VALUES
('I10','Essential (primary) hypertension'),
('E11','Type 2 diabetes mellitus'),
('J06','Acute upper respiratory infection'),
('S83','Tear of meniscus, knee'),
('R07','Pain in throat and chest');

INSERT INTO ProcedureCode (procedure_code, description) VALUES
('CPT1001','ECG 12-lead'),
('CPT2001','Knee MRI'),
('CPT3001','Chest X-Ray'),
('CPT4001','Blood draw'),
('CPT5001','Wound suturing');

INSERT INTO Medication (generic_name, brand_name) VALUES
('Metformin','Glucophage'),
('Lisinopril',NULL),
('Ibuprofen','Nurofen'),
('Amoxicillin','Amoxil'),
('Paracetamol','Tylenol');

INSERT INTO LabTest (lab_test_code, name, unit) VALUES
('HB','Hemoglobin','g/dL'),
('GLU','Glucose (fasting)','mg/dL'),
('CRP','C-Reactive Protein','mg/L'),
('TSH','Thyroid Stimulating Hormone','mIU/L'),
('A1C','Hemoglobin A1c','%');

-- Payers and Plans
INSERT INTO Payer (name) VALUES
('Aegis Health'),
('EuroCare'),
('Unity Insurance');

INSERT INTO InsurancePlan (payer_id, plan_name, plan_type) VALUES
(1,'Aegis Basic','HMO'),
(1,'Aegis Plus','PPO'),
(2,'EuroCare Silver','HMO'),
(2,'EuroCare Gold','PPO'),
(3,'Unity Standard','EPO');

-- =========================
-- 2) APPOINTMENTS & ENCOUNTERS
-- =========================
INSERT INTO Appointment (patient_id, provider_id, department_id, appt_dt, status) VALUES
(1,1,3,'2025-08-01 09:00:00','Seen'),
(2,2,2,'2025-08-03 10:30:00','Seen'),
(3,1,1,'2025-08-05 15:00:00','Seen'),
(4,4,4,'2025-08-10 11:15:00','Cancelled'),
(5,1,3,'2025-08-12 08:45:00','Seen'),
(1,2,2,'2025-09-01 09:30:00','Scheduled'),
(2,1,3,'2025-09-02 13:00:00','Scheduled'),
(3,4,4,'2025-09-03 14:15:00','Scheduled'),
(4,1,1,'2025-09-04 18:20:00','Scheduled'),
(5,2,2,'2025-09-05 11:00:00','Scheduled');

-- Encounters (mix of inpatient/outpatient/ER)
INSERT INTO Encounter (patient_id, provider_id, department_id, type, admit_dt, discharge_dt, status, appointment_id) VALUES
(1,1,3,'Outpatient',NULL,NULL,'Closed',1),
(2,2,2,'Inpatient','2025-08-03 11:00:00','2025-08-05 10:00:00','Closed',2),
(3,1,1,'ER','2025-08-05 15:10:00','2025-08-05 20:00:00','Closed',3),
(5,1,3,'Outpatient',NULL,NULL,'Closed',5),
(2,2,2,'Inpatient','2025-08-20 08:00:00','2025-08-22 09:30:00','Closed',NULL),
(4,4,4,'Outpatient',NULL,NULL,'Cancelled',4),
(1,1,2,'Outpatient',NULL,NULL,'Open',6),
(2,1,3,'Outpatient',NULL,NULL,'Open',7),
(3,4,4,'Outpatient',NULL,NULL,'Open',8),
(5,2,2,'Outpatient',NULL,NULL,'Open',10);

-- =========================
-- 3) CLINICAL FACTS
-- =========================
-- Diagnoses per encounter
INSERT INTO EncounterDiagnosis (encounter_id, diagnosis_code, seq_no, is_primary) VALUES
(1,'J06',1,TRUE),
(2,'I10',1,TRUE),
(2,'E11',2,FALSE),
(3,'R07',1,TRUE),
(4,'E11',1,TRUE),
(5,'I10',1,TRUE),
(7,'I10',1,TRUE),
(8,'E11',1,TRUE),
(9,'S83',1,TRUE),
(10,'I10',1,TRUE);

-- Procedures per encounter
INSERT INTO EncounterProcedure (encounter_id, procedure_code, performed_dt, quantity) VALUES
(1,'CPT4001','2025-08-01 09:20:00',1),
(2,'CPT1001','2025-08-03 12:00:00',1),
(3,'CPT3001','2025-08-05 16:00:00',1),
(5,'CPT1001','2025-08-20 10:00:00',1),
(9,'CPT2001','2025-09-03 15:00:00',1);

-- Prescriptions (order-level)
INSERT INTO Prescription (encounter_id, medication_id, dose, frequency, route, duration, instructions) VALUES
(1,3,'400 mg','TID','PO','5 days','After meals'),
(2,2,'10 mg','OD','PO','30 days','Morning'),
(2,1,'500 mg','BID','PO','30 days','With food'),
(3,5,'500 mg','QID','PO','3 days','As needed for pain'),
(4,1,'500 mg','BID','PO','14 days','Glycemic control'),
(5,2,'10 mg','OD','PO','30 days','BP control'),
(7,2,'5 mg','OD','PO','30 days',NULL),
(8,1,'500 mg','BID','PO','90 days','Diabetes maintenance');

-- Medication administrations (can be multiple per Rx)
INSERT INTO MedicationAdministration (encounter_id, medication_id, admin_dt, prescription_id, dose, route) VALUES
(1,3,'2025-08-01 10:00:00',1,'400 mg','PO'),
(2,2,'2025-08-03 20:00:00',2,'10 mg','PO'),
(2,1,'2025-08-03 20:05:00',3,'500 mg','PO'),
(3,5,'2025-08-05 17:30:00',4,'500 mg','PO'),
(5,2,'2025-08-20 10:30:00',6,'10 mg','PO');

-- Lab results
INSERT INTO LabResult (encounter_id, lab_test_code, collected_dt, result_value, abnormal_flag) VALUES
(1,'CRP','2025-08-01 09:25:00', 4.2,'N'),
(2,'HB', '2025-08-03 13:00:00',13.4,'N'),
(2,'GLU','2025-08-03 13:05:00',145.0,'H'),
(3,'CRP','2025-08-05 16:10:00',12.8,'H'),
(4,'A1C','2025-08-12 09:10:00',7.2,'H'),
(5,'HB', '2025-08-20 10:15:00',12.1,'N'),
(7,'GLU','2025-09-01 10:00:00',132.0,'H'),
(8,'A1C','2025-09-02 13:30:00',7.8,'H'),
(9,'HB', '2025-09-03 16:00:00',13.9,'N'),
(10,'GLU','2025-09-05 11:30:00',118.0,'H');

-- Allergies & patient allergies
INSERT INTO Allergy (substance, severity) VALUES
('Penicillin','Severe'),
('Peanuts','Moderate'),
('Latex','Mild'),
('Aspirin','Moderate'),
('Seafood','Severe');

INSERT INTO PatientAllergy (patient_id, allergy_id, noted_dt, active_flag) VALUES
(1,1,'2024-04-01 10:00:00',TRUE),
(2,2,'2022-12-15 09:00:00',TRUE),
(3,3,'2023-06-20 14:00:00',TRUE),
(4,4,'2021-03-10 08:30:00',FALSE),
(5,5,'2020-11-05 16:45:00',TRUE);

-- =========================
-- 4) CLAIMS
-- =========================
INSERT INTO Claim (encounter_id, plan_id, claim_number, claim_dt, amount, status) VALUES
(1,1,'CLM-2025-0001','2025-08-02', 120.00,'Paid'),
(2,2,'CLM-2025-0002','2025-08-06', 980.50,'Paid'),
(3,3,'CLM-2025-0003','2025-08-06', 220.00,'Denied'),
(4,1,'CLM-2025-0004','2025-08-13',  75.00,'Pending'),
(5,4,'CLM-2025-0005','2025-08-23', 650.00,'Paid'),
(7,2,'CLM-2025-0006','2025-09-02', 140.00,'Pending'),
(8,3,'CLM-2025-0007','2025-09-03', 180.00,'Pending'),
(9,5,'CLM-2025-0008','2025-09-04', 750.00,'Paid');

SET FOREIGN_KEY_CHECKS = 1;

-- =========================
-- 5) VIEWS (2 required)
-- =========================

-- View 1: SUMMARY / AGGREGATION
-- Purpose: Operational summary by department and month:
--   * number of encounters
--   * average length of stay (in days) for encounters with admit+discharge
--   * number of unique patients
CREATE OR REPLACE VIEW v_department_monthly_summary AS
SELECT
  d.name                                  AS department,
  DATE_FORMAT(e.admit_dt, '%Y-%m')        AS month_key,
  COUNT(*)                                AS encounter_count,
  COUNT(DISTINCT e.patient_id)            AS unique_patients,
  ROUND(AVG(
    CASE
      WHEN e.admit_dt IS NOT NULL AND e.discharge_dt IS NOT NULL
      THEN TIMESTAMPDIFF(HOUR, e.admit_dt, e.discharge_dt) / 24
      ELSE NULL
    END
  ), 2)                                    AS avg_length_of_stay_days
FROM Encounter e
JOIN Department d ON d.department_id = e.department_id
-- consider outpatient too; admit_dt may be NULL; they contribute to counts but not LOS
GROUP BY d.name, DATE_FORMAT(e.admit_dt, '%Y-%m')
ORDER BY month_key, department;

-- view
-- SELECT * FROM v_department_monthly_summary;

-- View 2: PERFORMANCE / TREND
-- Purpose: Financial trend of claims by month and plan:
--   * total_claims, total_amount, avg_amount
--   * payer and plan context to analyze performance over time
CREATE OR REPLACE VIEW v_claims_trend_monthly AS
SELECT
  p.name                            AS payer,
  ip.plan_name                      AS plan,
  DATE_FORMAT(c.claim_dt, '%Y-%m')  AS month_key,
  COUNT(*)                          AS total_claims,
  ROUND(SUM(c.amount), 2)           AS total_amount,
  ROUND(AVG(c.amount), 2)           AS avg_amount
FROM Claim c
JOIN InsurancePlan ip ON ip.plan_id = c.plan_id
JOIN Payer         p  ON p.payer_id = ip.payer_id
GROUP BY p.name, ip.plan_name, DATE_FORMAT(c.claim_dt, '%Y-%m')
ORDER BY month_key, payer, plan;


-- View
-- SELECT * FROM v_claims_trend_monthly;
