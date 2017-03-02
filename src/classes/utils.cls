public without sharing class utils {

	//Gets API name of the passed Object
	public static String getSObjectName(SObject o) {
		Schema.DescribeSObjectResult dsr = o.getSObjectType().getDescribe();
		String sObjectName = dsr.getName();
		return sObjectName;
	}
	//Gets a map of Record Type Ids to Developer Names for the object name
	public static Map<Id,String> getRecordTypeDeveloperNameMap(String sObjectName){
		Map<Id,String> returnMap = new Map<Id,String>();
		for(RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType =: sObjectName]){
			returnMap.put(rt.Id, rt.DeveloperName);
		}
		return returnMap;
	}
	public static Map<Id,String> getRecordTypeDeveloperNameMap(SObject o){
		String sObjectName = getSObjectName(o);
		Map<Id,String> returnMap = getRecordTypeDeveloperNameMap(sObjectName);
		return returnMap;
	}
	//Gets a map of Record Type Developer Names to Record Type Ids for the object name
	public static Map<String,Id> getRecordTypeIdMap(String sObjectName){
		Map<String,Id> returnMap = new Map<String,Id>();
		for(RecordType rt : [SELECT Id, DeveloperName FROM RecordType WHERE SObjectType =: sObjectName]){
			returnMap.put(rt.DeveloperName, rt.Id);
		}
		return returnMap;
	}
	public static Map<String,Id> getRecordTypeIdMap(SObject o){
		String sObjectName = getSObjectName(o);
		Map<String,Id> returnMap = getRecordTypeIdMap(sObjectName);
		return returnMap;
	}
	//Gets a map of an object's fields in the form: String object name, List<String> field names
	public static Map<String,List<String>> getObjectToFieldMap(String sObjectName) {
		Map<String,List<String>> returnMap = new Map<String,List<String>>();
		List<String> fieldList = new List<String>();
		Schema.DescribeSObjectResult dsr = Schema.getGlobalDescribe().get(sObjectName).getDescribe();
		Map<String,Schema.SObjectField> tempFieldMap = dsr.fields.getMap();
		for(String fieldName : tempFieldMap.keySet()) {
			fieldList.add(fieldName);
		}
		returnMap.put(sObjectName, fieldList);
		return returnMap;

	}
	public static Map<String,List<String>> getObjectToFieldMap(SObject o) {
		String sObjectName = getSObjectName(o);
		Map<String,List<String>> returnMap = getObjectToFieldMap(sObjectName);
		return returnMap;
	}
	//Gets a map of an object's fields in the form: String object name, List<String> field names
	public static Map<String,Schema.SObjectField> getFieldMap(String sObjectName) {
		Map<String,Schema.SObjectField> returnMap = new Map<String,Schema.SObjectField>();
		List<String> fieldList = new List<String>();
		Schema.DescribeSObjectResult dsr = Schema.getGlobalDescribe().get(sObjectName).getDescribe();
		returnMap = dsr.fields.getMap();
		return returnMap;

	}
	public static Map<String,Schema.SObjectField> getFieldMap(SObject o) {
		String sObjectName = getSObjectName(o);
		Map<String,Schema.SObjectField> returnMap = getFieldMap(sObjectName);
		return returnMap;
	}
}