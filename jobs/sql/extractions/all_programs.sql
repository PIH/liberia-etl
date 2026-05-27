SET @locale = GLOBAL_PROPERTY_VALUE('default_locale', 'en');
SET @partition = '${partitionNum}';

-- Get patient identifier types
SELECT patient_identifier_type_id INTO @identifier_type FROM patient_identifier_type pit WHERE uuid = '1a2acce0-7426-11e5-a837-0800200c9a66';
SELECT patient_identifier_type_id INTO @kgh_identifier_type FROM patient_identifier_type pit WHERE uuid = 'c09a1d24-7162-11eb-8aa6-0242ac110002';

-- Drop and create temporary table
DROP TEMPORARY TABLE IF EXISTS temp_all_programs;

CREATE TEMPORARY TABLE temp_all_programs (
	patient_program_id    INT,
    patient_id            INT,
    emr_id                VARCHAR(50),
    program_name          VARCHAR(50),
    date_enrolled         DATE,
    date_completed        DATE,
    program_outcome_concept_id INT(11),
    program_outcome       VARCHAR(255),
    creator               INT(11),
    user_entered          TEXT,
    index_asc             INT,
    index_desc            INT
);

-- Insert program data
INSERT INTO temp_all_programs (
	patient_program_id,
    patient_id,
    program_name,
    date_enrolled,
    date_completed,
    program_outcome_concept_id,
    creator
)
SELECT 
    pp.patient_program_id,
	pp.patient_id,
    p.name AS program_name,
    pp.date_enrolled,
    pp.date_completed,
    pp.outcome_concept_id,
    pp.creator
FROM 
    patient_program pp
    LEFT JOIN program p ON pp.program_id = p.program_id
WHERE 
    pp.voided = 0;

update temp_all_programs t 
set emr_id  = patient_identifier(patient_id, metadata_uuid('org.openmrs.module.emrapi', 'emr.primaryIdentifierType'));	

UPDATE temp_all_programs ap 
set program_outcome = concept_name(program_outcome_concept_id, @locale);

UPDATE temp_all_programs ap 
set user_entered = person_name_of_user(creator);


-- Final output
SELECT 
    CONCAT(@partition, "-", patient_program_id) AS patient_program_id,
    CONCAT(@partition, "-", patient_id) AS patient_id,
    emr_id,
    program_name,
    date_enrolled,
    date_completed,
    program_outcome,
    user_entered,
    index_asc,
    index_desc
FROM 
    temp_all_programs;
