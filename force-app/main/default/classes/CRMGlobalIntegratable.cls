/**
 * @description Interface for classes that can participate in Integration as data objects
 * Lead Management
 */
public interface CRMGlobalIntegratable {
    String getApiConfigKey();
    String serializeToJson();
    void deserializeFromJson(String serializedData);
}