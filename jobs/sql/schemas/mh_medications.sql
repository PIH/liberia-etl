create table mh_medications
(
  patient_id                      varchar(50),
  emr_id                          varchar(50),
  encounter_id                    varchar(50),
  encounter_type                  varchar(255),
  obs_group_id                    varchar(50),
  encounter_date                  date,
  provider                        varchar(50),
  date_entered                    date,
  user_entered                    varchar(50),
  drug_short_name                 varchar(255),
  drug_name                       varchar(255),
  dose                            float,
  dose_unit                       varchar(255),
  dose_frequency                  varchar(50),
  duration                        float,
  duration_unit                   varchar(50),
  route                           varchar(50),
  additional_medication_comments  varchar(255),
  index_asc                       int,
  index_desc                      int
);
