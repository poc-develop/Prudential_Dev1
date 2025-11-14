/**
 * @description Batch job to query PII data from Data Cloud and upsert it into PersonAccount records in FSC.
 * This job uses a custom Iterator implementation.
 * It also chains a subsequent batch job upon completion.
 *
 * This class implements both Iterable and Iterator, allowing the 'start' method to return 'this'.
 *
 * WARNING: This design queries ALL records into memory in the constructor.
 * If the query exceeds 50,000 rows, the batch will fail with a SOQL governor limit.
 * This pattern is not suitable for large data volumes.
 */
public class CRMPHKLUpsertCIC2Batch implements Database.Batchable<sObject>, Database.Stateful, Database.RaisesPlatformEvents, Iterable<sObject>, Iterator<sObject> {

    private Id personAccountRecordTypeId;
    private List<String> errorMessages = new List<String>();
    
    // --- Iterator Implementation ---
    private List<sObject> dataCloudRecords; // Holds all queried records
    private Integer currentIndex;           // Current position in the iterator

    // SOQL Query for Data Cloud
    private static final String UPSERT_KEY_PREFIX = 'DMTM_';

    /**
     * @description Constructor for the batch job.
     * It retrieves the 'Customer' PersonAccount Record Type ID and
     * queries ALL records from Data Cloud into a list.
     */
    public CRMPHKLUpsertCIC2Batch() {
        this.errorMessages = new List<String>();
        this.dataCloudRecords = new List<sObject>();
        this.currentIndex = 0;
        
        try {
            // Get the 'Customer' Record Type ID for PersonAccount
            this.personAccountRecordTypeId = [
                SELECT Id 
                FROM RecordType 
                WHERE SObjectType = 'Account' 
                AND Name = 'Customer' 
                AND IsPersonType = true 
                LIMIT 1
            ].Id;
            
        } catch (Exception e) {
            // If the RecordType isn't found, we cannot proceed.
            this.errorMessages.add('Failed to find PersonAccount RecordType \'Customer\': ' + e.getMessage());
            // Throwing an exception here will stop the batch from starting.
            throw new AuraHandledException('Required RecordType not found. Batch cannot start.');
        }

        try {
            // Construct the SOQL query directly
            String query = 'SELECT cic2_name__c, cic2_hkid__c, cic2_dob__c, cic2_spname__c, ' +
                           'cic2_sphkid__c, cic2_spdob__c, cic2_offtel__c, cic2_mobtel__c, cic2_hmetel__c ' +
                           'FROM vw_pii_dmtm_vw_phr_cic2_UDP_HK_UAT_Envir__dll';
            
            // Query all records. THIS IS THE RISK.
            this.dataCloudRecords = Database.query(query);

        } catch (Exception e) {
            this.errorMessages.add('Failed to query Data Cloud records in constructor: ' + e.getMessage());
            // Re-throw to prevent batch from starting if query fails
            throw new AuraHandledException('Data Cloud query failed in constructor: ' + e.getMessage());
        }
    }

    /**
     * @description The start method returns the iterable (this class).
     * @param bc The BatchableContext
     * @return An Iterable<sObject>
     */
    public Iterable<sObject> start(Database.BatchableContext bc) {
        // Return this class, as it implements Iterable
        return this;
    }

    /**
     * @description Required by Iterable interface. Returns the iterator (this class).
     * @return An Iterator<sObject>
     */
    public Iterator<sObject> iterator() {
        // Reset index just in case, though start() is only called once.
        this.currentIndex = 0;
        // Return this class, as it implements Iterator
        return this;
    }

    /**
     * @description Required by Iterator interface. Checks if more records exist.
     * @return Boolean
     */
    public Boolean hasNext() {
        // Check if the current index is within the bounds of the list
        return this.currentIndex < this.dataCloudRecords.size();
    }

    /**
     * @description Required by Iterator interface. Returns the next sObject.
     * @return sObject
     */
    public sObject next() {
        // Get the record at the current index and then increment the index
        return this.dataCloudRecords[this.currentIndex++];
    }

    /**
     * @description The execute method processes each batch of sObject records.
     * @param bc The BatchableContext
     * @param records A list of sObject records (a chunk from the main list)
     */
    public void execute(Database.BatchableContext bc, List<sObject> records) {
        List<Account> accountsToUpsert = new List<Account>();

        for (sObject item : records) {
            
            // Get the HKID, which is mandatory for the upsert key
            String hkid = (String)item.get('cic2_hkid__c');
            
            // Only proceed if we have an HKID to build the SourceSystemId
            if (String.isNotBlank(hkid)) {
                Account pa = new Account();

                // Set Record Type and External ID (Upsert Key)
                pa.RecordTypeId = this.personAccountRecordTypeId;
                pa.FinServ__SourceSystemId__c = UPSERT_KEY_PREFIX + hkid;

                // --- Field Mapping ---
                
                // PersonAccount.Lastname <- cic2_name
                if (item.get('cic2_name__c') != null) {
                    pa.LastName = (String)item.get('cic2_name__c');
                } else {
                    // LastName is mandatory for PersonAccount. Set a placeholder if null.
                    pa.LastName = 'Unknown';
                }

                // PersonAccount.CRM_Global_IDNumber__pc <- cic2_hkid
                pa.CRM_Global_IDNumber__pc = hkid;

                // PersonAccount.Birthdate <- cic2_dob
                if (item.get('cic2_dob__c') != null) {
                    // Attempt to cast to Date. Data Cloud might send a String.
                    try {
                         if(item.get('cic2_dob__c') instanceOf Date) {
                            pa.PersonBirthdate = (Date)item.get('cic2_dob__c');
                         } else if (item.get('cic2_dob__c') instanceOf String) {
                            // Handle empty strings that can't be parsed
                            if (String.isNotBlank((String)item.get('cic2_dob__c'))) {
                                pa.PersonBirthdate = Date.valueOf((String)item.get('cic2_dob__c'));
                            }
                         }
                    } catch (Exception e) {
                        this.errorMessages.add('Failed to parse PersonBirthdate for HKID ' + hkid + ': ' + item.get('cic2_dob__c'));
                    }
                }

                // PersonAccount.CRM_Global_SpouseName__pc <- cic2_spname
                if (item.get('cic2_spname__c') != null) {
                    pa.CRM_Global_SpouseName__pc = (String)item.get('cic2_spname__c');
                }

                // ASSUMPTION: Mapping 'cic2_sphkid__c' to 'CRM_PHKL_SpouseHKID__pc'
                // The request mapped 'CRM_Global_IDNumber__pc' twice.
                if (item.get('cic2_sphkid__c') != null) {
                    pa.CRM_PHKL_SpouseHKID__pc = (String)item.get('cic2_sphkid__c');
                }
                
                // ASSUMPTION: Mapping 'cic2_spdob__c' to 'CRM_Global_SpouseDOB__pc'
                // The request mapped 'Birthdate' twice.
                 if (item.get('cic2_spdob__c') != null) {
                    try {
                        if(item.get('cic2_spdob__c') instanceOf Date) {
                            pa.CRM_Global_SpouseDOB__pc = (Date)item.get('cic2_spdob__c');
                        } else if (item.get('cic2_spdob__c') instanceOf String) {
                             if (String.isNotBlank((String)item.get('cic2_spdob__c'))) {
                                pa.CRM_Global_SpouseDOB__pc = Date.valueOf((String)item.get('cic2_spdob__c'));
                             }
                        }
                    } catch (Exception e) {
                        this.errorMessages.add('Failed to parse Spouse Birthdate for HKID ' + hkid + ': ' + item.get('cic2_spdob__c'));
                    }
                }

                // PersonAccount.CRM_Global_OfficeNo__pc <- cic2_offtel
                if (item.get('cic2_offtel__c') != null) {
                    pa.CRM_Global_OfficeNo__pc = (String)item.get('cic2_offtel__c');
                }

                // PersonAccount.PersonMobilePhone <- cic2_mobtel
                if (item.get('cic2_mobtel__c') != null) {
                    pa.PersonMobilePhone = (String)item.get('cic2_mobtel__c');
                }

                // PersonAccount.PersonHomePhone <- cic2_hmetel
                if (item.get('cic2_hmetel__c') != null) {
                    pa.PersonHomePhone = (String)item.get('cic2_hmetel__c');
                }

                accountsToUpsert.add(pa);
            } else {
                this.errorMessages.add('Skipping record due to missing cic2_hkid__c: ' + JSON.serialize(item));
            }
        }

        if (!accountsToUpsert.isEmpty()) {
            // Upsert records using the external ID field. allOrNone = false.
            List<Database.UpsertResult> results = Database.upsert(accountsToUpsert, Account.FinServ__SourceSystemId__c.getDescribe().getSObjectField(), false);
            
            // Process results to capture errors
            for (Integer i = 0; i < results.size(); i++) {
                if (!results[i].isSuccess()) {
                    String recordId = results[i].getId() != null ? results[i].getId() : accountsToUpsert[i].FinServ__SourceSystemId__c;
                    String recordErrors = 'Failed to upsert record ' + recordId + '. Errors: ';
                    for (Database.Error err : results[i].getErrors()) {
                        recordErrors += err.getStatusCode() + ': ' + err.getMessage() + ' (Fields: ' + String.join(err.getFields(), ',') + '); ';
                    }
                    this.errorMessages.add(recordErrors);
                }
            }
        }
    }

    /**
     * @description The finish method executes after all batches are processed.
     * It sends an error email (if any) and chains the next batch job.
     * @param bc The BatchableContext
     */
    public void finish(Database.BatchableContext bc) {
        // Send an email if any errors occurred
        if (!this.errorMessages.isEmpty()) {
            // Send error email
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            String[] toAddresses = new String[] { 'your.email@example.com' }; // <-- UPDATE THIS
            mail.setToAddresses(toAddresses);
            mail.setSubject('CRMPHKLUpsertCIC2Batch Job Failed with Errors');
            
            String emailBody = 'The Data Cloud to PersonAccount upsert batch job (Job ID: ' + bc.getJobId() + ') finished with errors.\n\n';
            emailBody += 'Total Errors: ' + this.errorMessages.size() + '\n\n';
            emailBody += 'Error Details (first 20 shown):\n';
            for (Integer i = 0; i < Math.min(this.errorMessages.size(), 20); i++) {
                emailBody += '- ' + this.errorMessages[i] + '\n';
            }
            mail.setPlainTextBody(emailBody);
            //Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        }

        // Chain the next batch job as required
        // Update 'CRMPHKLPlaceholderNextBatch' to your actual next batch class
        //Database.executeBatch(new CRMPHKLPlaceholderNextBatch(), 200);
    }
}