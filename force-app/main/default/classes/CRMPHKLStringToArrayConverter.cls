/**
 * @description Apex Class for Flow to convert string to array using semicolon separator
 * @author Kyle
 * @date 2024
 */
public with sharing class CRMPHKLStringToArrayConverter {
    
    /**
     * @description Convert a string to a list of strings using semicolon as separator
     * @param inputString The input string to be converted
     * @return List<String> The converted list of strings
     */
    @InvocableMethod(label='Convert String to Array' description='Convert a string to an array using semicolon separator')
    public static List<List<String>> convertStringToArray(List<String> inputString) {
        List<List<String>> result = new List<List<String>>();
        
        for (String str : inputString) {
            List<String> stringArray = new List<String>();
            
            if (String.isNotBlank(str)) {
                // Split by semicolon and trim whitespace
                String[] parts = str.split(';');
                for (String part : parts) {
                    if (String.isNotBlank(part.trim())) {
                        stringArray.add(part.trim());
                    }
                }
            }
            
            result.add(stringArray);
        }
        
        return result;
    }
    
    /**
     * @description Convert a single string to a list of strings using semicolon as separator
     * @param inputString The input string to be converted
     * @return List<String> The converted list of strings
     */
    public static List<String> convertSingleStringToArray(String inputString) {
        List<String> stringArray = new List<String>();
        
        if (String.isNotBlank(inputString)) {
            // Split by semicolon and trim whitespace
            String[] parts = inputString.split(';');
            for (String part : parts) {
                if (String.isNotBlank(part.trim())) {
                    stringArray.add(part.trim());
                }
            }
        }
        
        return stringArray;
    }
}