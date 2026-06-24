create table epilepsy_visits
(
  patient_id            varchar(50),
  emr_id                varchar(50),
  encounter_id          varchar(50),
  encounter_date        date,
  provider_name         varchar(255),
  encounter_location    varchar(255),
  onset_date            date,
  general_seizure_type  varchar(500),
  medications           varchar(500),
  disposition           varchar(255),
  next_appointment_date date,
  date_entered          date,
  user_entered          varchar(255),
  index_asc             int,
  index_desc            int
);
