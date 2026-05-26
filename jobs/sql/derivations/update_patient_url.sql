update ap
set patient_url = 
CASE
	when patient_url like '%kouka%' then
		concat('https://kouka.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
	when site = 'pleebo' then
		concat('https://pleebo.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
	when site = 'jjdossen' then
		concat('https://jjdossen.pih-emr.org/openmrs/coreapps/clinicianfacing/patient.page?patientId=', patient_uuid)
END
from all_patients ap ;
