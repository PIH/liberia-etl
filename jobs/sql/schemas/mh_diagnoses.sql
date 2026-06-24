create table mh_diagnoses
(
  patient_id            varchar(50),
  emr_id                varchar(50),
  encounter_id          varchar(50),
  encounter_type        varchar(255),
  encounter_datetime    datetime,
  encounter_location    varchar(255),
  date_entered          datetime,
  user_entered          varchar(255),
  encounter_provider    varchar(255),
  diagnosis_order       varchar(50),
  diagnosis             varchar(255)
);
