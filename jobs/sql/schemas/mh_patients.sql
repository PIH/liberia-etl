create table mh_patients
(
  patient_id       varchar(50),
  emr_id           varchar(50),
  mh_mrn           varchar(50),
  dob              date,
  gender           varchar(50),
  community        varchar(255),
  district         varchar(255),
  county           varchar(255),
  current_age      int,
  referred_by      varchar(255),
  referred_from    varchar(255),
  date_enrolled    date,
  outcome_date     date,
  counseling_plan  text,
  mh_diagnoses     text,
  program_outcome  varchar(255),
  index_asc        int,
  index_desc       int
);
