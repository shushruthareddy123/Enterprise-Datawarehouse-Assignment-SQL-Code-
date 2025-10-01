-- ===============================
--  Healthcare DB (3NF) 
--  LO1, LO2 Implementation
--  Includes PK/FK, constraints,
--  M:N junctions, and indexes
-- ===============================

CREATE DATABASE IF NOT EXISTS healthcare
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE healthcare;

-- For deterministic FK creation order
SET FOREIGN_KEY_CHECKS = 0;

-- =========================
-- Core reference entities
-- =========================
CREATE TABLE Patient (
  patient_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  nhs_no       VARCHAR(32) UNIQUE,
  first_name   VARCHAR(80)  NOT NULL,
  last_name    VARCHAR(80)  NOT NULL,
  sex          ENUM('M','F','X') NOT NULL,
  dob          DATE NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Provider (
  provider_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  -- Optional business identifier; unique if present
  provider_code VARCHAR(30) UNIQUE,
  name          VARCHAR(120) NOT NULL,
  role          ENUM('Physician','Nurse','Other') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Department (
  department_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name          VARCHAR(120) NOT NULL,
  UNIQUE KEY uq_department_name (name)
) ENGINE=InnoDB;

-- Provider can belong to multiple Departments (M:N)
CREATE TABLE ProviderDepartment (
  provider_id   BIGINT NOT NULL,
  department_id BIGINT NOT NULL,
  start_dt      DATE,
  end_dt        DATE,
  PRIMARY KEY (provider_id, department_id),
  CONSTRAINT fk_pd_provider   FOREIGN KEY (provider_id)   REFERENCES Provider(provider_id)   ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pd_department FOREIGN KEY (department_id) REFERENCES Department(department_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================
-- Scheduling & encounters
-- =========================
CREATE TABLE Appointment (
  appointment_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  patient_id     BIGINT NOT NULL,
  provider_id    BIGINT NOT NULL,
  department_id  BIGINT NOT NULL,
  appt_dt        DATETIME NOT NULL,
  status         ENUM('Scheduled','Seen','NoShow','Cancelled') NOT NULL,
  CONSTRAINT fk_appt_patient    FOREIGN KEY (patient_id)    REFERENCES Patient(patient_id)      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_appt_provider   FOREIGN KEY (provider_id)   REFERENCES Provider(provider_id)     ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_appt_department FOREIGN KEY (department_id) REFERENCES Department(department_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Encounter (
  encounter_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  patient_id     BIGINT NOT NULL,
  provider_id    BIGINT NOT NULL,
  department_id  BIGINT NOT NULL,
  type           ENUM('Inpatient','Outpatient','ER') NOT NULL,
  admit_dt       DATETIME,
  discharge_dt   DATETIME,
  status         ENUM('Open','Closed','Cancelled') NOT NULL DEFAULT 'Open',
  appointment_id BIGINT NULL,
  CONSTRAINT fk_enc_patient     FOREIGN KEY (patient_id)     REFERENCES Patient(patient_id)      ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_enc_provider    FOREIGN KEY (provider_id)    REFERENCES Provider(provider_id)     ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_enc_department  FOREIGN KEY (department_id)  REFERENCES Department(department_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_enc_appt        FOREIGN KEY (appointment_id) REFERENCES Appointment(appointment_id) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT chk_enc_dates CHECK (discharge_dt IS NULL OR admit_dt IS NULL OR discharge_dt >= admit_dt)
) ENGINE=InnoDB;

-- =========================
-- Clinical vocabularies
-- =========================
CREATE TABLE Diagnosis (
  diagnosis_code VARCHAR(10) PRIMARY KEY,
  description    VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE ProcedureCode (
  procedure_code VARCHAR(10) PRIMARY KEY,
  description    VARCHAR(255) NOT NULL
) ENGINE=InnoDB;

CREATE TABLE Medication (
  medication_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  generic_name  VARCHAR(120) NOT NULL,
  brand_name    VARCHAR(120)
) ENGINE=InnoDB;

CREATE TABLE LabTest (
  lab_test_code VARCHAR(20) PRIMARY KEY,
  name          VARCHAR(120) NOT NULL,
  unit          VARCHAR(30)
) ENGINE=InnoDB;

-- =========================
-- 3NF
-- =========================
-- M:N: Encounters ↔ Diagnoses
CREATE TABLE EncounterDiagnosis (
  encounter_id    BIGINT NOT NULL,
  diagnosis_code  VARCHAR(10) NOT NULL,
  seq_no          INT NOT NULL DEFAULT 1,
  is_primary      BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (encounter_id, diagnosis_code, seq_no),
  CONSTRAINT fk_ed_encounter FOREIGN KEY (encounter_id)   REFERENCES Encounter(encounter_id)     ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ed_diag      FOREIGN KEY (diagnosis_code) REFERENCES Diagnosis(diagnosis_code)   ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- M:N: Encounters ↔ Procedures
CREATE TABLE EncounterProcedure (
  encounter_id   BIGINT NOT NULL,
  procedure_code VARCHAR(10) NOT NULL,
  performed_dt   DATETIME NOT NULL,
  quantity       INT DEFAULT 1,
  PRIMARY KEY (encounter_id, procedure_code, performed_dt),
  CONSTRAINT fk_ep_encounter FOREIGN KEY (encounter_id)   REFERENCES Encounter(encounter_id)      ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ep_proc      FOREIGN KEY (procedure_code) REFERENCES ProcedureCode(procedure_code) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Orders (prescriptions) vs administrations (3NF separation)
CREATE TABLE Prescription (
  prescription_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  encounter_id    BIGINT NOT NULL,
  medication_id   BIGINT NOT NULL,
  dose            VARCHAR(60),
  frequency       VARCHAR(60),
  route           VARCHAR(40),
  duration        VARCHAR(40),
  instructions    VARCHAR(255),
  CONSTRAINT fk_rx_encounter FOREIGN KEY (encounter_id)  REFERENCES Encounter(encounter_id)   ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_rx_med       FOREIGN KEY (medication_id) REFERENCES Medication(medication_id)  ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE MedicationAdministration (
  encounter_id     BIGINT NOT NULL,
  medication_id    BIGINT NOT NULL,
  admin_dt         DATETIME NOT NULL,
  prescription_id  BIGINT NULL,
  dose             VARCHAR(60),
  route            VARCHAR(40),
  PRIMARY KEY (encounter_id, medication_id, admin_dt),
  CONSTRAINT fk_ma_encounter   FOREIGN KEY (encounter_id)    REFERENCES Encounter(encounter_id)    ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_ma_medication  FOREIGN KEY (medication_id)   REFERENCES Medication(medication_id)   ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_ma_rx          FOREIGN KEY (prescription_id) REFERENCES Prescription(prescription_id) ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE LabResult (
  lab_result_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  encounter_id  BIGINT NOT NULL,
  lab_test_code VARCHAR(20) NOT NULL,
  collected_dt  DATETIME NOT NULL,
  result_value  DECIMAL(12,4),
  abnormal_flag ENUM('L','H','N') DEFAULT 'N',
  CONSTRAINT fk_lr_encounter FOREIGN KEY (encounter_id)  REFERENCES Encounter(encounter_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_lr_labtest   FOREIGN KEY (lab_test_code) REFERENCES LabTest(lab_test_code)  ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Allergies and patient ↔ allergy (M:N)
CREATE TABLE Allergy (
  allergy_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  substance  VARCHAR(120) NOT NULL,
  severity   ENUM('Mild','Moderate','Severe') NOT NULL
) ENGINE=InnoDB;

CREATE TABLE PatientAllergy (
  patient_id  BIGINT NOT NULL,
  allergy_id  BIGINT NOT NULL,
  noted_dt    DATETIME NOT NULL,
  active_flag BOOLEAN DEFAULT TRUE,
  PRIMARY KEY (patient_id, allergy_id, noted_dt),
  CONSTRAINT fk_pa_patient FOREIGN KEY (patient_id) REFERENCES Patient(patient_id) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_pa_allergy FOREIGN KEY (allergy_id) REFERENCES Allergy(allergy_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================
-- Payer / Plan / Claims
-- =========================
CREATE TABLE Payer (
  payer_id BIGINT PRIMARY KEY AUTO_INCREMENT,
  name     VARCHAR(120) NOT NULL
) ENGINE=InnoDB;

-- 3NF: plan is separate from payer (plan_type depends on plan, not payer)
CREATE TABLE InsurancePlan (
  plan_id   BIGINT PRIMARY KEY AUTO_INCREMENT,
  payer_id  BIGINT NOT NULL,
  plan_name VARCHAR(120) NOT NULL,
  plan_type VARCHAR(60)  NOT NULL,
  UNIQUE KEY uq_plan_per_payer (payer_id, plan_name),
  CONSTRAINT fk_plan_payer FOREIGN KEY (payer_id) REFERENCES Payer(payer_id) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE Claim (
  claim_id     BIGINT PRIMARY KEY AUTO_INCREMENT,
  encounter_id BIGINT NOT NULL,
  plan_id      BIGINT NOT NULL,
  claim_number VARCHAR(40),
  claim_dt     DATE NOT NULL,
  amount       DECIMAL(12,2) NOT NULL,
  status       ENUM('Paid','Denied','Pending') NOT NULL,
  UNIQUE KEY uq_claim_number (claim_number),
  CONSTRAINT fk_claim_encounter FOREIGN KEY (encounter_id) REFERENCES Encounter(encounter_id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT fk_claim_plan      FOREIGN KEY (plan_id)      REFERENCES InsurancePlan(plan_id) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =========================
-- Indexes (≥ 2 for perf)
-- =========================
-- finds encounters for a patient around a date;
-- finds a provider’s appointments; diagnostics & results lookups.
CREATE INDEX idx_encounter_patient_admit   ON Encounter(patient_id, admit_dt);
CREATE INDEX idx_appointment_provider_dt   ON Appointment(provider_id, appt_dt);
CREATE INDEX idx_labresult_encounter_test  ON LabResult(encounter_id, lab_test_code);
CREATE INDEX idx_encdiag_diag              ON EncounterDiagnosis(diagnosis_code);
CREATE INDEX idx_rx_encounter_medication   ON Prescription(encounter_id, medication_id);

SET FOREIGN_KEY_CHECKS = 1;
