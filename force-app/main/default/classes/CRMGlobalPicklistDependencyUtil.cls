/**
 * @description       : get picklist fields dependency
 * @author            : Hassan
 * @group             : 
 * @last modified on  : 2025-09-23
**/
public with sharing class CRMGlobalPicklistDependencyUtil {
    public static Map<String, List<String>> getDependentOptions(String objName, String ctrlField, String depField) {
        Map<String, List<String>> dependencies = new Map<String, List<String>>();
        
        try {
            Schema.DescribeFieldResult ctrlDescribe = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(ctrlField).getDescribe();
            Schema.DescribeFieldResult depDescribe = Schema.getGlobalDescribe().get(objName).getDescribe().fields.getMap().get(depField).getDescribe();
        
            List<Schema.PicklistEntry> ctrlEntries = ctrlDescribe.getPicklistValues();
            List<Schema.PicklistEntry> depEntries = depDescribe.getPicklistValues();
        
            // 初始化依赖映射
            for (Schema.PicklistEntry ctrlEntry : ctrlEntries) {
                dependencies.put(ctrlEntry.getLabel(), new List<String>());
            }
        
            // 处理每个依赖字段值
            for (Schema.PicklistEntry depEntry : depEntries) {
                System.debug('depEntry:'+JSON.serialize(depEntry));
                Map<String,Object> depEntryMap = (Map<String,Object>)JSON.deserializeUntyped(JSON.serialize(depEntry));
                System.debug('depEntryMap:'+depEntryMap.get('validFor'));
                
                if (depEntryMap.get('validFor') == null) {
                    continue; // 跳过没有validFor的条目
                }
                
                Blob decoded = EncodingUtil.base64Decode(String.valueOf(depEntryMap.get('validFor')));
                
                // 将Blob转换为字节数组的正确方法
                String hexString = EncodingUtil.convertToHex(decoded);
                List<Integer> bytes = new List<Integer>();
                
                // 将十六进制字符串转换为字节列表的正确方法
                for (Integer i = 0; i < hexString.length(); i += 2) {
                    String byteStr = hexString.substring(i, Math.min(i + 2, hexString.length()));
                    // 修复：使用正确的十六进制转换方法
                    Integer byteValue = hexToDecimal(byteStr);
                    bytes.add(byteValue);
                }
                
                for (Integer i = 0; i < ctrlEntries.size(); i++) {
                    Integer byteIndex = i / 8;
                    Integer bitIndex = 7 - math.MOD(i, 8);
                    
                    // 检查字节索引是否在范围内
                    if (byteIndex >= bytes.size()) {
                        continue;
                    }
                    
                    Integer byteValue = bytes[byteIndex]; // 现在可以使用索引访问了
                    
                    if ((byteValue >> bitIndex & 1) == 1) {
                        dependencies.get(ctrlEntries[i].getLabel()).add(depEntry.getLabel());
                    }
                }
            }
        } catch (Exception e) {
            System.debug('getDependentOptions错误: ' + e.getMessage() + ' at ' + e.getLineNumber());
        }
        return dependencies;
    }

    // 十六进制字符串转换为十进制整数
    private static Integer hexToDecimal(String hexStr) {
        // 创建十六进制字符到数字的映射
        Map<String, Integer> hexMap = new Map<String, Integer>{
            '0' => 0, '1' => 1, '2' => 2, '3' => 3, '4' => 4, 
            '5' => 5, '6' => 6, '7' => 7, '8' => 8, '9' => 9,
            'A' => 10, 'B' => 11, 'C' => 12, 'D' => 13, 'E' => 14, 'F' => 15,
            'a' => 10, 'b' => 11, 'c' => 12, 'd' => 13, 'e' => 14, 'f' => 15
        };
        
        Integer result = 0;
        for (Integer i = 0; i < hexStr.length(); i++) {
            String hexChar = hexStr.substring(i, i + 1);
            Integer digitValue = hexMap.get(hexChar);
            if (digitValue == null) {
                digitValue = 0; // 默认值
            }
            result = result * 16 + digitValue;
        }
        return result;
    }
}