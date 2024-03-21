/**
* Author: Anjali Bhusarapu
* Created Date: 21-03-2024
* Description: This class will initiate the parts sync process
**/
public class CQ_ImportPartController {
    
    
    /**
     * 
     * Author: Anjali Bhusarapu
     * Created Date: 21-03-2024
     * Description: This method will get a response from an external system and sync with the parts.
     * Returns:
     * ResponseWrapper - This will return statusCode and responseMessage.
     **/
    
    @AuraEnabled
    public static ResponseWrapper SyncParts() {
        // Initialize response wrapper to sent it to front end.
        ResponseWrapper rw = new ResponseWrapper();        
        try {
            // get custom settings on Parts.
            List<Part_Settings__c> partSettingsList = [SELECT API_Key__c,Content_type__c,End_Point__c FROM Part_Settings__c]; 
            
            // Check all the fields have data or not.
            if (partSettingsList.size() > 0 && (partSettingsList[0].Content_Type__c != null && partSettingsList[0].Api_Key__c != null && partSettingsList[0].End_Point__c != null)) {
                
                // callout on GET method using custom settings data.
                string authorizationHeader;
                string APIKey = partSettingsList[0].API_Key__c;
                
                HttpRequest http = new HttpRequest();
                http.setMethod('GET'); 
                
                http.setEndpoint(partSettingsList[0].End_Point__c);
                Blob headerValue = Blob.valueOf(APIkey + ':');
                authorizationHeader = 'BASIC ' +EncodingUtil.base64Encode(headerValue);
                http.setHeader('Authorization', authorizationHeader); 
                http.setHeader('content-type', partSettingsList[0].Content_type__c);
                http.setHeader('x-api-key', partSettingsList[0].API_Key__c);
                
                Http ht = new Http();
                HTTPResponse response = ht.send(http);            
                system.debug('res body--->'+response.getBody());
                
                
                // check status code
                if (response.getStatusCode() == 200) {
                    // get the response data
                    String partsListFromResponse = response.getBody();
                    // added the response in a list.
                    List<Object> deserializedPartsList = (List<Object>) JSON.deserializeUntyped(partsListFromResponse);
                    
                    // set to store part IDs.
                    Set<String> partIdsSet = new Set<String>();
                    
                    // get part IDs from response then add in a set.
                    if (!deserializedPartsList.isEmpty()) {
                        for (Object obj : deserializedPartsList) {
                            Map<String, Object> partDataMap = (Map<String, Object>) obj;
                            system.debug('partDataMap---'+partDataMap);
                            partIdsSet.add((String) partDataMap.get(CQ_Constant_Variables.RESPONSE_PART_ID));
                            system.debug('partIdsSet---'+partIdsSet);
                        }
                    }
                    
                    
                    // Retrieve the Accounts with specified names
                    List<Account> AccountList = [SELECT Id, Name FROM Account WHERE Name like: CQ_Constant_Variables.HIGH_VOLUME OR Name like: CQ_Constant_Variables.LOW_VOLUME];
                    
                    Map<String, Id> accountMap = new Map<String, Id>();
                    
                    // Create map of account names to IDs
                    if (!AccountList.isEmpty()) {
                        for (Account acc : AccountList) {
                            accountMap.put(acc.Name, acc.Id);
                        }
                    }
                    
                    List<SQX_Part__c> SQX_partsList = new List<SQX_Part__c>();
                    // Query existing parts based on IDs from response
                    if (!partIdsSet.isEmpty()) {
                        SQX_partsList = [SELECT Id, Name, Active__c, Part_Number__c FROM SQX_Part__c WHERE Part_Number__c IN: partIdsSet];
                    }
                    
                    // Mapping the part number and Id 
                    Map<String, String> partmap = new Map<String, String>();
                    if (!SQX_partsList.isEmpty()) {
                        for (SQX_Part__c prt : SQX_partsList) {
                            partmap.put(prt.Part_Number__c, prt.Id);
                        }
                    }
                    
                    
                    List<SQX_Part__c> newPartsList = new List<SQX_Part__c>();
                    
                    // Create new parts based on response data
                    if (!deserializedPartsList.isEmpty()) {
                        for (Object obj : deserializedPartsList) {
                            Map<String, Object> mapFromDeserializedObject = (Map<String, Object>) obj;
                            SQX_Part__c SQX_Part = new SQX_Part__c();
                            if (partmap.get((String) mapFromDeserializedObject.get(CQ_Constant_Variables.RESPONSE_PART_ID)) != null) {
                                SQX_Part.Id = partmap.get((String) mapFromDeserializedObject.get(CQ_Constant_Variables.RESPONSE_PART_ID));
                            }
                            SQX_Part.Name = (String) mapFromDeserializedObject.get(CQ_Constant_Variables.RESPONSE_PART_NAME);
                            SQX_Part.Part_Number__c = (String) mapFromDeserializedObject.get(CQ_Constant_Variables.RESPONSE_PART_ID);
                            SQX_Part.Active__c = true;
                            Integer totalQuantityShipped = (Integer) mapFromDeserializedObject.get(CQ_Constant_Variables.RESPONSE_TOTAL_QUANTITY_SHIPPED);
                            // Determine account based on quantity shipped
                            if (totalQuantityShipped < 99) {
                                if (accountMap.get('High Volume') != null) {
                                    SQX_Part.Related_Account__c = accountMap.get('High Volume');
                                }
                            } else if (totalQuantityShipped >= 99) {
                                if (accountMap.get('Low Volume') != null) {
                                    SQX_Part.Related_Account__c = accountMap.get('Low Volume');
                                }
                            }
                            newPartsList.add(SQX_Part);
                        }
                    }
                    
                    // Upsert new parts
                    if (!newPartsList.isEmpty()) {
                        upsert newPartsList;
                    }
                    rw.statusCode = response.getStatusCode(); 
                    rw.responseMessage = 'Success';
                    
                } 
                else {
                    // Set status code and message from response
                    rw.statusCode = response.getStatusCode(); 
                    rw.responseMessage = response.getStatus(); 
                }
                
            } else {
                // Set status code and message for missing configuration
                rw.statusCode = null; 
                rw.responseMessage = CQ_Constant_Variables.NO_CONFIGURATION_MESSAGE; 
            }
            
        }
        // Catch any exceptions and set response message accordingly
        catch (Exception ex) {
            rw.statusCode = null; 
            rw.responseMessage = ex.getMessage(); 
        }        
        return rw;     
    }
    
    // This wrapper class will store data from the response.
    public class ResponseWrapper {
        @AuraEnabled public Integer statusCode {get; set;} // Status code of the response
        @AuraEnabled public String responseMessage {get; set;} // Response message
    }
}