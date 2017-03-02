@isTest
public class SyncUtilityTest {
	private static Date petitionDate = System.today();
	private static String targetObjectName = '';
	private static Set<String> currentSources = new Set<String>();
	private static Map<String,String> currentFieldMappings = new Map<String,String>();	
	private static List<Investigation__c> iList {
		get {
			if(iList == null) {
				iList = [SELECT Id, RecordTypeId, AD_Investigation_Aligned_To__c, Calculated_Final_Signature__c, Petition__c FROM Investigation__c];
			}
			return iList;
		}
	}
	private static List<Petition__c> pList {
		get {
			if(pList == null) {
				pList = [SELECT Id, Commodity__c FROM Petition__c];
			}
			return pList;
		}
	}
	private static Investigation__c iAD {
		get {
			Id recordType = utils.getRecordTypeIdMap('Investigation__c').get('AD');
			iAD = [SELECT Id, RecordTypeId, AD_Investigation_Aligned_To__c, Calculated_Final_Signature__c, Petition__c FROM Investigation__c WHERE RecordTypeId =: recordType LIMIT 1];
			return iAD;
		}	
	}
	private static void targetObjectName(List<SObject> soList) {
		targetObjectName = utils.getSObjectName(soList[0]);
	}
	private static Set<String> currentSources(String s) {
		if(s != null) {
			currentSources.removeAll(currentSources);
			currentSources.add(s);
		} else if(targetObjectName == 'Investigation__c') {
			currentSources.removeAll(currentSources);
			currentSources.add('Petition__c');
			currentSources.add('Investigation__c');
		}
		return currentSources;
	}

	@isTest static void initializeInvestigation() {
		Test.startTest();
		targetObjectName(iList);
		SyncUtility.initialize(iList);//initializes, setting targetObjectName and investigationList in utility
		System.assertEquals(targetObjectName, SyncUtility.targetObjectName);
		System.assertEquals(iList, SyncUtility.investigationList);
		Test.stopTest();
	}
	@isTest static void setInvestigationSourceObjectNames() {
		Test.startTest();
		targetObjectName(iList);
		SyncUtility.initialize(iList);//initializes, setting targetObjectName and investigationList in utility
		SyncUtility.setSourceObjectNames(currentSources('Petition__c'), false);
		System.assertEquals(currentSources, SyncUtility.sourceObjectNames);//both have only Petition__c
		SyncUtility.setSourceObjectNames(currentSources, false);
		currentSources.removeAll(currentSources);//reset to size of 0
		System.assertNotEquals(currentSources, SyncUtility.sourceObjectNames);//currentSources size is 0, but that call all sources in utility
		SyncUtility.setSourceObjectNames(currentSources, true);
		System.assertNotEquals(currentSources, SyncUtility.sourceObjectNames);//currentSources still has Petition__c, but the boolean "true" set sourceObjectNames to all sources
		SyncUtility.setSourceObjectNames(currentSources(null), false);
		System.assertEquals(currentSources, SyncUtility.sourceObjectNames);//both have both Petition__c and Investigation__c by passing
		Test.stopTest();
	}
	@isTest static void setInvestigationSyncFieldMap() {
		Test.startTest();
		targetObjectName(iList);
		SyncUtility.initialize(iList);//initializes, setting targetObjectName and investigationList in utility
		SyncUtility.setSourceObjectNames(currentSources, true);//sets sourceObjectNames to all in utility
		SyncUtility.setSyncFieldMap();//grabs CMT for investigation
		System.assertNotEquals(null, SyncUtility.syncFieldMap.get('Petition__c'));//syncFieldMap has Petition values
		currentFieldMappings = SyncUtility.syncFieldMap.get('Petition__c');//map the Petition mappings to current
		System.assertEquals(currentFieldMappings.get('Petition_Case_Number__c'), 'Case_Number__c');//confirm a mapping is correct
		currentFieldMappings = SyncUtility.syncFieldMap.get('Investigation__c');//map the Investigation mappings to current
		System.assertEquals(currentFieldMappings.get('Calculated_Final_Signature__c'),'Calculated_Final_Signature__c');//confirm a mapping is correct
		Test.stopTest();
	}
	@isTest static void setInvestigationSourceObjectMap() {
		Test.startTest();
		targetObjectName(iList);
		SyncUtility.initialize(iList);//initializes, setting targetObjectName and investigationList in utility
		SyncUtility.setSourceObjectNames(currentSources(null), true);//sets sourceObjectNames to all in utility
		SyncUtility.setSyncFieldMap();//grabs CMT for investigation
		SyncUtility.setSourceObjectsMap();//map source objects to source map
		System.assertEquals('Foodstuffs', ((Petition__c)SyncUtility.sourceObjectsMap.get(pList[0].Id)).Commodity__c);//confirm source object map queried correctly
		for(Investigation__c i : iList) {
			if(i.RecordTypeId == utils.getRecordTypeIdMap(i).get('AD')){
				System.assertEquals(i.Id, SyncUtility.sourceObjectsMap.get(i.Id).Id);//the AD investigation was queried
			} else {
				System.assertEquals(null, SyncUtility.sourceObjectsMap.get(i.Id));//the CVD investigation was not queried
			}
		}
		Test.stopTest();
	}
	@isTest static void setInvestigationTargetObjectValues() {
		Test.startTest();
		Investigation__c i = TestUtils.createInvestigation('CVD', pList[0], false);
		i.AD_Investigation_Aligned_To__c = iAD.Id;
		iList.add(i);
		targetObjectName(iList);
		SyncUtility.initialize(iList);//initializes, setting targetObjectName and investigationList in utility
		SyncUtility.setSourceObjectNames(currentSources(null), true);//sets sourceObjectNames to all in utility
		SyncUtility.setSyncFieldMap();//grabs CMT for investigation
		SyncUtility.setSourceObjectsMap();//map source objects to source map
		SyncUtility.setTargetObjectValues();//set the source value to the target value
		System.assertEquals(i.Calculated_Final_Signature__c, iAD.Calculated_Final_Signature__c);//the CVD investigation is aligned to the AD
		System.assertEquals(i.Petition_Commodity__c, pList[0].Commodity__c);//the Petition synced to Investigation
		Test.stopTest();
	}


	@testSetup static void dataSetup() {
		Test.startTest();
		User testUser = TestUtils.createAdminUser(true, 'myemail@email.com.testita', 1);
		Petition__c testPetition = TestUtils.createPetition(petitionDate, 'AD ME', false);
		testPetition.Commodity__c = 'Foodstuffs';
		insert testPetition;
		Investigation__c testADinvestigation = TestUtils.createInvestigation('AD', testPetition, true);
		Investigation__c testCVDinvestigation = TestUtils.createInvestigation('CVD', testPetition, false);
		testCVDinvestigation.AD_Investigation_Aligned_To__c = testADinvestigation.Id;
		insert testCVDinvestigation;
	}
}