/**
 * @descrtion an interface for SObject processing
 * Lead Management
 */
public interface CRMPHKLSObjectServiceInterface {
    Database.SaveResult insertRecord(SObject record);
    Boolean processData();
}