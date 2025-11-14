/**
 * @description Test class for StringToArrayConverter
 * @author Kyle
 * @date 2024
 */
@isTest
public class CRMPHKLStringToArrayConverterTest {
    
    @isTest
    static void testConvertStringToArrayWithValidInput() {
        // Test data
        List<String> inputStrings = new List<String>{
            'Apple;Banana;Cherry',
            'Red;Green;Blue',
            'One;Two;Three;Four'
        };
        
        // Execute method
        Test.startTest();
        List<List<String>> result = CRMPHKLStringToArrayConverter.convertStringToArray(inputStrings);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(3, result.size(), 'Should return 3 lists');
        
        // Check first list
        List<String> firstList = result[0];
        System.assertEquals(3, firstList.size(), 'First list should have 3 elements');
        System.assertEquals('Apple', firstList[0], 'First element should be Apple');
        System.assertEquals('Banana', firstList[1], 'Second element should be Banana');
        System.assertEquals('Cherry', firstList[2], 'Third element should be Cherry');
        
        // Check second list
        List<String> secondList = result[1];
        System.assertEquals(3, secondList.size(), 'Second list should have 3 elements');
        System.assertEquals('Red', secondList[0], 'First element should be Red');
        System.assertEquals('Green', secondList[1], 'Second element should be Green');
        System.assertEquals('Blue', secondList[2], 'Third element should be Blue');
        
        // Check third list
        List<String> thirdList = result[2];
        System.assertEquals(4, thirdList.size(), 'Third list should have 4 elements');
        System.assertEquals('One', thirdList[0], 'First element should be One');
        System.assertEquals('Two', thirdList[1], 'Second element should be Two');
        System.assertEquals('Three', thirdList[2], 'Third element should be Three');
        System.assertEquals('Four', thirdList[3], 'Fourth element should be Four');
    }
    
    @isTest
    static void testConvertStringToArrayWithEmptyInput() {
        // Test data
        List<String> inputStrings = new List<String>{
            '',
            null,
            '   '
        };
        
        // Execute method
        Test.startTest();
        List<List<String>> result = CRMPHKLStringToArrayConverter.convertStringToArray(inputStrings);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(3, result.size(), 'Should return 3 lists');
        
        for (List<String> stringList : result) {
            System.assertEquals(0, stringList.size(), 'All lists should be empty');
        }
    }
    
    @isTest
    static void testConvertStringToArrayWithWhitespace() {
        // Test data
        List<String> inputStrings = new List<String>{
            ' Apple ; Banana ; Cherry ',
            'Red ;Green; Blue',
            'One; Two ;Three; Four '
        };
        
        // Execute method
        Test.startTest();
        List<List<String>> result = CRMPHKLStringToArrayConverter.convertStringToArray(inputStrings);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(3, result.size(), 'Should return 3 lists');
        
        // Check first list (whitespace should be trimmed)
        List<String> firstList = result[0];
        System.assertEquals(3, firstList.size(), 'First list should have 3 elements');
        System.assertEquals('Apple', firstList[0], 'First element should be Apple (trimmed)');
        System.assertEquals('Banana', firstList[1], 'Second element should be Banana (trimmed)');
        System.assertEquals('Cherry', firstList[2], 'Third element should be Cherry (trimmed)');
        
        // Check second list
        List<String> secondList = result[1];
        System.assertEquals(3, secondList.size(), 'Second list should have 3 elements');
        System.assertEquals('Red', secondList[0], 'First element should be Red (trimmed)');
        System.assertEquals('Green', secondList[1], 'Second element should be Green (trimmed)');
        System.assertEquals('Blue', secondList[2], 'Third element should be Blue (trimmed)');
        
        // Check third list
        List<String> thirdList = result[2];
        System.assertEquals(4, thirdList.size(), 'Third list should have 4 elements');
        System.assertEquals('One', thirdList[0], 'First element should be One (trimmed)');
        System.assertEquals('Two', thirdList[1], 'Second element should be Two (trimmed)');
        System.assertEquals('Three', thirdList[2], 'Third element should be Three (trimmed)');
        System.assertEquals('Four', thirdList[3], 'Fourth element should be Four (trimmed)');
    }
    
    @isTest
    static void testConvertSingleStringToArrayWithValidInput() {
        // Test data
        String inputString = 'Apple;Banana;Cherry';
        
        // Execute method
        Test.startTest();
        List<String> result = CRMPHKLStringToArrayConverter.convertSingleStringToArray(inputString);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(3, result.size(), 'Should return 3 elements');
        System.assertEquals('Apple', result[0], 'First element should be Apple');
        System.assertEquals('Banana', result[1], 'Second element should be Banana');
        System.assertEquals('Cherry', result[2], 'Third element should be Cherry');
    }
    
    @isTest
    static void testConvertSingleStringToArrayWithEmptyInput() {
        // Test data
        String inputString = '';
        
        // Execute method
        Test.startTest();
        List<String> result = CRMPHKLStringToArrayConverter.convertSingleStringToArray(inputString);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testConvertSingleStringToArrayWithNullInput() {
        // Test data
        String inputString = null;
        
        // Execute method
        Test.startTest();
        List<String> result = CRMPHKLStringToArrayConverter.convertSingleStringToArray(inputString);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(0, result.size(), 'Should return empty list');
    }
    
    @isTest
    static void testConvertSingleStringToArrayWithWhitespace() {
        // Test data
        String inputString = ' Apple ; Banana ; Cherry ';
        
        // Execute method
        Test.startTest();
        List<String> result = CRMPHKLStringToArrayConverter.convertSingleStringToArray(inputString);
        Test.stopTest();
        
        // Assertions
        System.assertEquals(3, result.size(), 'Should return 3 elements');
        System.assertEquals('Apple', result[0], 'First element should be Apple (trimmed)');
        System.assertEquals('Banana', result[1], 'Second element should be Banana (trimmed)');
        System.assertEquals('Cherry', result[2], 'Third element should be Cherry (trimmed)');
    }
}