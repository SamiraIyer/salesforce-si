/**
 * 
 *    Created by Joshua Moody
 *    on Mar 31 2017
 *    MIL Corporation
 * 
 **/

public without sharing class StaffingAssignmentExtension {

    /***********************************************************
    * This class is the controller/extension for a page that displays
    * information about a record's staffing assignments. The original
    * design was to a related list or inline vf page.  That changed to
    * a separate page.  Then the requirement to do this same dml 
    * functionality for triggers was added.  With the changing direction
    * and multiple concurrent developers working on this class, it grew
    * in size and complexity and is now high candidate for a refactor.
    * This class provides methods to:
    * 1. Dynamically display in the correct UX (can be updated to 
    * using the lightningStylesheets tag, which is currently in beta)
    * 2. Display in a list all the staffing assignments for the 
    * parent record and the child(ren) related organization records
    * 3. Update the Staffing Assignments as needed
    * 4. Via a second constructor, it is also called from triggers to create the userless
    * staffing assignments that are added on insert of a parent
    * record.
    ***********************************************************/

    private static FINAL String PETITION = 'Petition__c';
    private static FINAL String INVESTIGATION = 'Investigation__c';
    private static FINAL String ORDER = 'ADCVD_Order__c';
    private static FINAL String SEGMENT = 'Segment__c';
    private static FINAL String RELATED_ORG = 'Related_Organization__c';

    /*********************************
    * Variables to manage UI
    ********************************/
    public Boolean isSalesforce1 {get {
        isSalesforce1 =uiUtils.isSalesforce1();
        return isSalesforce1;
        } set;
    }

    public Boolean isLightningExperience {get {
        isLightningExperience =uiUtils.isLightningExperience();
        return isLightningExperience;
        } set;
    }

    public Boolean isSalesforceClassic {get {
        isSalesforceClassic =uiUtils.isSalesforceClassic();
        return isSalesforceClassic;
        } set;
    }

    public Boolean noParentError {get; set;}
    public Boolean saveError {
        get{
            if (saveError == null) {
                saveError = false;
            }
            return saveError;
        } set;
    }

    /**********************************
     * Variables for a parent record
     *********************************/
    public SObject parentRecord {get {
        if (parentRecord == null && parentId != null) {
            String soqlQuery = 'SELECT Id, ADCVD_Case__c, ADCVD_Case_Number_Text__c, ADCVD_Case_Type_Text__c, Country_Text__c, Product_Text__c FROM ';
            String soqlQueryRO = 'SELECT Id,ADCVD_Case_Number_Text__c,Commodity_Text__c,ADCVD_Case_Type_Text__c,CBP_Case_Number_Text__c,Country_Text__c,Product_Text__c,Product_Short_Name_Text__c FROM ';
            soqlQuery = (parentSObjectType == 'Related_Organization__c')? (soqlQueryRO += parentSObjectType): (soqlQuery+=parentSObjectType);
            soqlQuery += ' WHERE Id =: parentId';
            System.debug('soqlQuery: '+ soqlQuery);
            List<SObject> tempList = database.query(soqlQuery);
            parentRecord = tempList[0];
        }
        return parentRecord;
        } set;
    }
    public static Map<Id,SObject> parentRecordMap = new Map<Id,SObject>();
    //Sets field names to add to the standard controller, making them available to reference for null checks
    public List<String> parentFieldNames {get {
        parentFieldNames = new List<String>();
        parentFieldNames.add(PETITION);
        parentFieldNames.add(INVESTIGATION);
        parentFieldNames.add(ORDER);
        parentFieldNames.add(SEGMENT);
        parentFieldNames.add(RELATED_ORG);
        return parentFieldNames;
        } set;
    }
    //Get the parentId by checking the parent fields on the Staffing Assignment
    public Id parentId {get {
        if(sa != null && parentId == null && !String.isBlank(parentSObjectType)) {
            parentId = (Id)sa.get(parentSObjectType);
        }
        return parentId;
        } set;
    }
    //Get the parentSObjectType name by checking the parent fields on the Staffing Assignment
    public String parentSObjectType {get {
        if(sa != null && parentSObjectType == null) {
            ParentSortingService pss = new ParentSortingService();
            parentSObjectType = pss.getParentSObjectType(sa, 'Staffing_Assignment__c');
        }
        return parentSObjectType;
        } set;
    }

    /***********************************
     * Variable for Staffing Assigment
     ***********************************/
    //Record created by constructor. Will hold a parentId in one of the lookup fields
    public Staffing_Assignment__c sa {get { 
        if(sa == null) {
            sa = new Staffing_Assignment__c();
        }
        return sa;
        } set;
    }
    public StaffingAssignmentWrapper sawOuterInstance {get; set;}
    public Integer addWrapper {get {
        if(addWrapper == null) {
            addWrapper = 1;
        }
        return addWrapper;
        } set;
    }

    /******************************************
     * Variables for User Select Option Lists
     *****************************************/
    @TestVisible private static Map<Id, User> adcvdUserMap {
        get {
            if (adcvdUserMap == null) {
                adcvdUserMap = new Map<Id,User>();
                for (User u : [SELECT Id, Name, Staffing_Role__c FROM User WHERE Staffing_Role__c != null ORDER BY Name Asc]) {
                    adcvdUserMap.put(u.Id, u);
                }
            }
            return adcvdUserMap;
        } set;
    }
    //SelectOption list with all users that have a staffing role
     public List<SelectOption> allUserSelectOptions {
         get {
        if(allUserSelectOptions == null) {
                allUserSelectOptions = new List<SelectOption>();
                for (User u : adcvdUserMap.values()) {
                    allUserSelectOptions.add(new SelectOption(u.Id, u.Name));
                }
                allUserSelectOptions.add(0,new SelectOption('','--Select a User--'));//add the default the list of all users only once
        }
        return allUserSelectOptions;
        } set;
    }
    //Map of Titles to SelectOption lists of users with a matching Staffing Role
    public Map<String, List<SelectOption>> userSelectOptions {
        get {
        if(userSelectOptions == null) {
            populateUserLists();
        }
        return userSelectOptions;
        } set;
    }
    //Map used to create SelectOption lists
    public Map<String, List<User>> userRoleMap {
        get {
        if(userRoleMap == null) {
                userRoleMap = new Map<String, List<User>>();
                for(User u: adcvdUserMap.values()) {
                    List<User> tempList = new List<User>();
                    if(userRoleMap.get(u.Staffing_Role__c) != null) {
                        tempList = userRoleMap.get(u.Staffing_Role__c);
                    }
                    tempList.add(u);
                    userRoleMap.put(u.Staffing_Role__c, tempList);
                }
        }
        return userRoleMap;
        } set;
    }
    //Set of all Ids from users with Staffing Roles
    public Set<Id> userIdSet {
        get {
        if(userIdSet == null) {
                userIdSet = getAdcvdUserMap().keySet();
        }
        return userIdSet;
        } set;
    }

    /**********************************************
     * Variables for Staff Assignments and Wrapper
     *********************************************/
    //List of staffing assignments returned for the parent
    public List<Staffing_Assignment__c> staffList {get {
        if(staffList == null) {
            staffList = new List<Staffing_Assignment__c>();
        }
        return staffList;
        } set;
    }
    //List of staffing assignment wrapper objects that will display in page
    public List<StaffingAssignmentWrapper> staffWrapperList {get {
        if(staffWrapperList == null) {
            staffWrapperList = new List<StaffingAssignmentWrapper>();
        }
        return staffWrapperList;
        } set;
    }
    
    @TestVisible 
    private Map<String,Integer> defaultUserRolesMap {get {
        if (defaultUserRolesMap == null) {
            defaultUserRolesMap = new Map<String,Integer>();
            for(Constant__mdt c : [SELECT Staffing_Role__c, Number_Value__c, ADCVD_Objects__r.Object_API_Name__c, ADCVD_Objects__r.Type__c, 
                                    ADCVD_Objects__r.Record_Type_Name__c
                                    FROM Constant__mdt WHERE Staffing_Assignment_Default__c =: true]) {
                if (c.Staffing_Role__c != null && c.Number_Value__c != null && c.ADCVD_Objects__r.Object_API_Name__c == parentSObjectType) {
                    defaultUserRolesMap.put(c.Staffing_Role__c, (Integer)c.Number_Value__c);
                }
            }
        }
        System.debug(defaultUserRolesMap);
        return defaultUserRolesMap;
        } set;
    }
    private Set<String> allUserRolesSet {get {
        if(allUserRolesSet == null) {
            allUserRolesSet = new Set<String>();
            List<Schema.PicklistEntry> pleList = Schema.Constant__mdt.Staffing_Role__c.getDescribe().getPicklistValues();
            for(Schema.PicklistEntry ple : pleList) {//add all titles from default list to title map
                allUserRolesSet.add(ple.getValue());
            }
        }  
       return allUserRolesSet;
        } set;
    } 
    private static Map<Id,Related_Organization__c> relOrgMap = new Map<Id,Related_Organization__c>();

    private static Set<Id> usersWithActiveRecusals = new Set<Id>();


    /*********************
     * Constructors
     *********************/
    public StaffingAssignmentExtension (ApexPages.StandardController stdController) {
        if (!Test.isRunningTest()) {stdController.addFields(parentFieldNames);}//add fields that will be referenced to avoid "field not retrieved by soql" error
        //If this is a page reload, there will be parameters, not a record
        if (ApexPages.currentPage().getParameters() != null && ApexPages.currentPage().getParameters().get('parentId') != null) {
            parentId = ApexPages.currentPage().getParameters().get('parentId');
            parentSObjectType = utils.findObjectNameFromRecordIdPrefix(parentId);
            if(ApexPages.currentPage().getParameters().get('addWrapper') != null) {//adding a wrapper
                addWrapper = ApexPages.currentPage().getParameters().get('addWrapper') != null ? 
                Integer.valueOf(ApexPages.currentPage().getParameters().get('addWrapper')) : 0;
            }
            sa = setSaParent(parentId, parentSObjectType);
            if (parentId == null || parentSObjectType == null) {
                checkParent();
                return;
            }
            parentRecordMap.put(parentId, parentRecord);
            init(sa, addWrapper);
        } else {
            sa = (Staffing_Assignment__c)stdController.getRecord();
            if (parentId == null || parentSObjectType == null) {
                checkParent();
                return;
            }
            parentRecordMap.put(parentId, parentRecord);
            init(sa);
        }
    }

    //Primary method to initialize data on page load
    private void init(Staffing_Assignment__c sa){
        saveError = false;
        setUsersWithActiveRecusals(parentId);
        staffList = getstaffList(parentId, parentSObjectType);
        staffWrapperList = addStaffWrapper(parentId, parentSObjectType, staffList, userIdSet, null);
        System.debug(staffWrapperList);
    }
    private void init(Staffing_Assignment__c sa, Integer addWrapper) {
        saveError = false;
        setUsersWithActiveRecusals(parentId);
        staffList = getstaffList(parentId, parentSObjectType);
        staffWrapperList = addStaffWrapper(parentId, parentSObjectType, staffList, userIdSet, addWrapper);
        System.debug(staffWrapperList);
    }
    //method mapped to "Add Staff Assignment" button
    public PageReference addRow(){
        Staffing_Assignment__c sa = createNewStaffingAssignment(parentId, parentRecord);//create a Staffing Assignment record with the parent Id field populated
        StaffingAssignmentWrapper saw = new staffingAssignmentWrapper(parentId, parentSObjectType, sa, sawOuterInstance.recusalStatusMap, 
                                                                        sawOuterInstance.recusalLinkMap, sawOuterInstance.recusalLinkTextMap);//create a wrapper, adding that Staffing Assignment
        staffWrapperList.add(saw);
        return null;
    }
    //method mapped to "Save"
    public PageReference save() {
        List<Staffing_Assignment__c> staffListToUpsert = new List<Staffing_Assignment__c>();
        List<Staffing_Assignment__c> staffListToDelete = new List<Staffing_Assignment__c>();
        for(staffingAssignmentWrapper saw: staffWrapperList) {
            //AD-467
            if(!String.isBlank(saw.sa.Title__c)){
                staffListToUpsert.add(saw.sa);//If Title field is populated, upsert
            } else if (String.isBlank(saw.sa.Title__c) && saw.sa.Id != null) {
                staffListToDelete.add(saw.sa);//If Title field is not populated, delete
            }
        }
        try {
            upsert staffListToUpsert;
        } catch (Exception e) {
            if (e.getMessage().contains('There is no Program Manager for this parent record. Please add one to continue.')) {
                e.setMessage('There is no Program Manager for this parent record. Please add one to continue.');
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
            }
            saveError = true;
        }
        try {
            delete staffListToDelete;
        } catch (Exception e) {
            if (e.getMessage().contains('There is no Program Manager for this parent record. Please add one to continue.')) {
                e.setMessage('There is no Program Manager for this parent record. Please add one to continue.');
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, e.getMessage()));
            }
            saveError = true;
        }
        return null;

    }

    public PageReference cancel() {
        return null;
    }

    public PageReference checkParent() {
        if(parentId == null || parentSObjectType == null) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR,
            'New Staffing Assignments cannot be created from this page. ' +
            'Navigate to the record that you would like to add a Staffing Assignment to and click the "New Staffing Assignment" button on that record\'s related list'));
            noParentError = true;
        }
        return null;
    }

    @TestVisible private String getReturnUrl() {
        return ApexPages.currentPage().getParameters().get('retURL');
    }
    @TestVisible private Map<Id,User> getAdcvdUserMap() {
        return adcvdUserMap;
    }
    @TestVisible private static void setUsersWithActiveRecusals (Id parentId) {
        Id caseId = (Id) fflibext_Application.Selector.newInstance(parentId.getSObjectType()).selectSObjectsById(new Set<Id>{parentId})[0].get('ADCVD_Case__c');
        ADCVD_CaseMapper caseMapper = (ADCVD_CaseMapper) ADCVD_CaseMapper.mapperMap.get('ADCVD_Case__c');
        caseMapper = caseMapper.getInstance(new Set<Id>{caseId});
        RecusalMapper recMapper = (RecusalMapper) caseMapper.getMapper('Recusal__c');
        usersWithActiveRecusals = recMapper.getInstance(adcvdUserMap.keySet()).getMapByUserIds().keySet();
    }
    //if existing, return matching Staffing Assignment. Else return a new one
    @TestVisible private Staffing_Assignment__c querySA(){
        if(parentId != null) {
            sa = [SELECT Id, ADCVD_Order__c, Investigation__c, Petition__c, 
                                Related_Organization__c, Segment__c FROM Staffing_Assignment__c 
                                WHERE Id =: parentId
                                OR ADCVD_Order__c =:parentId
                                OR Investigation__c =:parentId
                                OR Petition__c =:parentId
                                OR Related_Organization__c =:parentId
                                OR Segment__c =:parentId  LIMIT 1];
        } else {
            sa = new Staffing_Assignment__c();
        }
        return sa;
    }
    //Returns list of all Staffing Assignments for the parent
    @TestVisible private List<Staffing_Assignment__c> getStaffList(Id parentId, String parentSObjectType) {
        List<Related_Organization__c> relOrgList = new List<Related_Organization__c>();
        relOrgList = parentSObjectType == RELATED_ORG ? getRelOrgList(parentId) : null;
        if(staffList == null || staffList.isEmpty()) {
            Set<Id> parentIdSet = new Set<Id>{parentId};
            if (parentSObjectType != ORDER) {
                for (Related_Organization__c r : [SELECT Id FROM Related_Organization__c 
                                                WHERE Investigation__c =: parentId
                                                OR Petition__c =: parentId
                                                //OR Legal_Representation__c =: parentId
                                                OR Segment__c =: parentId]) {
                    parentIdSet.add(r.Id);
                }
            }
            //specify base query
            String soqlQuery = 'SELECT Id, ADCVD_Case__c, User__c, Title__c, User__r.Staffing_Role__c, Related_Organization__c, Related_Organization__r.Account__r.Name FROM Staffing_Assignment__c WHERE ';
            //specify object specific clause and query object, add to wrapper
            if (parentSObjectType != RELATED_ORG) {
                soqlQuery += parentSObjectType + ' IN: parentIdSet OR Related_Organization__c IN: parentIdSet ORDER BY User__c ASC NULLS LAST LIMIT 1000';
            } else {
                soqlQuery += parentSObjectType + ' IN: parentIdSet ORDER BY User__c ASC NULLS LAST LIMIT 1000';
            }
            System.debug(soqlQuery);
            List<Staffing_Assignment__c> queryList = database.query(soqlQuery);
            List<Staffing_Assignment__c> tempRelOrgList = new List<Staffing_Assignment__c>(queryList.size());
            List<Staffing_Assignment__c> tempStaffList = new List<Staffing_Assignment__c>(queryList.size());
            for (Staffing_Assignment__c s : queryList) {
                if (s.Related_Organization__c == null || s.Related_Organization__c == parentId) {
                    Integer tempInt = tempStaffList != null ? tempStaffList.size() - 1 : 0;
                    if (s.User__c != null) {
                        tempStaffList.add(0, s);//staff assignments with Users to the top of the list
                    } else {
                        tempStaffList.add(tempInt, s);//staff assignments without Users to the end of the list
                    }
                } else {
                    Integer tempInt = tempRelOrgList != null ? tempRelOrgList.size() - 1 : 0;
                    if (s.User__c != null) {
                        tempRelOrgList.add(0, s);
                    } else {
                        tempRelOrgList.add(tempInt, s);
                    }
                }
            }
            tempStaffList.addAll(tempRelOrgList);
            for (Staffing_Assignment__c s : tempStaffList) {
                if (s != null) {
                    s = setSaRelatedOrgParentId(relOrgList, s);
                    staffList.add(s);
                }
            }
        }
        return staffList;
    }

    @TestVisible private List<Related_Organization__c> getRelOrgList(Id parentId) {
        List<Related_Organization__c> returnList = new List<Related_Organization__c>();
        if (relOrgMap.isEmpty()) {
            for(Related_Organization__c r : [SELECT ADCVD_Order__c, ADCVD_Order__r.ADCVD_Order_Name__c, Investigation__c, Investigation__r.Investigation_Name__c, 
                                                    Litigation__c, Litigation__r.Litigation_Name__c, Litigation__r.Petition__c, Litigation__r.Petition__r.Petition_Name__c, 
                                                    Litigation__r.Investigation__c, Litigation__r.Investigation__r.Investigation_Name__c, 
                                                    Litigation__r.Segment__c, Litigation__r.Segment__r.Segment_Name__c, 
                                                    Petition__c, Petition__r.Petition_Name__c, Segment__c, Segment__r.Segment_Name__c
                                                FROM Related_Organization__c WHERE Id IN: parentRecordMap.keySet()]) {
                relOrgMap.put(r.Id, r);
            }
        }
        returnList.add(relOrgMap.get(parentId));
        return returnList;
    }
    //Initializes SelectOption lists
    @TestVisible private void populateUserLists(){
        userSelectOptions = new Map<String, List<SelectOption>>();
        //add all users to lists that are mapped to Staffing Roles
        for (String s: allUserRolesSet) {//Create Staffing Assignments for defaults
            List<User> userList = userRoleMap.get(s);//for each default Staffing Role, get the matching list of users
            List<SelectOption> userSelect = new List<SelectOption>();
            
            if(userList != null) {//for each user in this list (they all share same Staffing Role)
                for(User u : userList) {
                    userSelect.add(new SelectOption(u.Id, u.Name));//create a SelectOption
                }
                if(userList.size() > 0) {
                    userSelect.add(0,new SelectOption('', '--Select a User--'));//add the default if no user selected
                }
            } else {
                userSelect.add(new SelectOption('', '--Please update user records to have this AD CVD Title--'));//notify user if no users match this role
            }
            userSelectOptions.put(s, userSelect);//Staffing Role and list of users in map
        }
    }

    //method used to create initial Staffing Assignments, includes setting titles from defauls
    public static Staffing_Assignment__c createNewStaffingAssignment(String parentId, String title) {
        Staffing_Assignment__c newSA = createNewStaffingAssignment(parentId);
        newSA.Title__c = title;
        return newSA;
    }
    //method used to create Staffing Assignments via the "add row" method
    public static Staffing_Assignment__c createNewStaffingAssignment(String parentIdAsString, SObject parentRecord) {
        Staffing_Assignment__c newSA = createNewStaffingAssignment(parentIdAsString);
        if (String.isBlank(newSA.ADCVD_Case_Number_Text__c)) {
            ParentValuesService pvs = new ParentValuesService();
            newSA = (Staffing_Assignment__c)pvs.setCaseValuesFromParent(parentRecord, newSA);
        }
        return newSA;
    }
    
    public static Staffing_Assignment__c createNewStaffingAssignment(String parentIdAsString) {
        Staffing_Assignment__c newSA = new Staffing_Assignment__c();
        if(!String.isBlank(parentIdAsString)) {
            //Id exists only in this method
            Id parentId = (Id)parentIdAsString;
            //String exists only in this method
            String parentSObjectType = parentId.getSObjectType().getDescribe().getName();
            newSA.put(parentSObjectType, parentId);
        }
        if (parentRecordMap != null && parentRecordMap.containsKey((Id)parentIdAsString)) {
            ParentValuesService pvs = new ParentValuesService();
            newSA = (Staffing_Assignment__c)pvs.setCaseValuesFromParent(parentRecordMap.get((Id)parentIdAsString), newSA);
        }
        return newSA;
    }

    //method to add a list of staffing assignments to the wrapper - prepopulates blank values
    public List<StaffingAssignmentWrapper> addStaffWrapper(Id parentId, String parentSObjectType, List<Staffing_Assignment__c> staffList, Set<Id> userIdSet, Integer addWrapper) {
        //create a map to determine if the User Title is already specified
        List<StaffingAssignmentWrapper> returnList = new List<StaffingAssignmentWrapper>();
        Map<String, Boolean> userTitleExistsMap = new Map<String, Boolean>();
        List<Related_Organization__c> relOrgList = new List<Related_Organization__c>();
        relOrgList = parentSObjectType == RELATED_ORG ? getRelOrgList(parentId) : null;
        for(String s: defaultUserRolesMap.keySet()) {//add all titles from default list to title map
            for(Integer i = 0; i < defaultUserRolesMap.get(s); i++) {
                userTitleExistsMap.put(s, false);
            }
        }
        //add existing user titles to the map, overwriting any defaults that have usersfor them
        for(Staffing_Assignment__c sa: staffList) {
            userTitleExistsMap.put(sa.Title__c, true);
        }
        //if the title does not exist, create a new blank row
        for(String s: userTitleExistsMap.keySet()) {
            if(userTitleExistsMap.get(s) == false) {
                Staffing_Assignment__c sa = createNewStaffingAssignment(parentId, s);
                sa = setSaRelatedOrgParentId(relOrgList, sa);
                staffList.add(sa);
            }
        }
        //for all the Staffing Assignments with and without users, create the wrappers
        sawOuterInstance = new StaffingAssignmentWrapper(parentId, parentSObjectType, staffList, userIdSet);
        returnList = sawOuterInstance.innerWrapperList.clone();
        if(addWrapper != null) {
            for(Integer i = 0; i < addWrapper; i++) {
                Staffing_Assignment__c sa = createNewStaffingAssignment(parentId);//create a Staffing Assignment record with the parent Id field populated
                StaffingAssignmentWrapper saw = new staffingAssignmentWrapper(parentId, parentSObjectType, sa, sawOuterInstance.recusalStatusMap, 
                                                                                sawOuterInstance.recusalLinkMap, sawOuterInstance.recusalLinkTextMap);//create a wrapper, adding that Staffing Assignment
                returnList.add(saw);
            }
        }
        return returnList;
    }

    private Staffing_Assignment__c setSaParent(Id parentId, String parentSObjectType) {
        if(parentSObjectType != null && parentId != null) {
            if(parentSObjectType == PETITION) {
                sa.Petition__c = parentId;
            } else if(parentSObjectType == INVESTIGATION) {
                sa.Investigation__c = parentId;
            } else if(parentSObjectType == ORDER) {
                sa.ADCVD_Order__c = parentId;
            } else if(parentSObjectType == SEGMENT) {
                sa.Segment__c = parentId;
            } else if(parentSObjectType == RELATED_ORG) {
                sa.Related_Organization__c = parentId;
            }
        }
        return sa;
    }

    @TestVisible private Staffing_Assignment__c setSaRelatedOrgParentId(List<Related_Organization__c> relOrgList, Staffing_Assignment__c sa) {
        if (relOrgList != null) {
            for(Related_Organization__c r : relOrgList) {
                if (r.ADCVD_Order__c != null) {
                    sa.Related_Org_Parent_Id__c = r.ADCVD_Order__c;
                    sa.Related_Org_Parent_Name__c = r.ADCVD_Order__r.ADCVD_Order_Name__c;
                } else if (r.Investigation__c != null) {
                    sa.Related_Org_Parent_Id__c = r.Investigation__c;
                    sa.Related_Org_Parent_Name__c = r.Investigation__r.Investigation_Name__c;
                } else if (r.Litigation__c != null) {
                    if (r.Litigation__r.Petition__c != null) {
                        sa.Related_Org_Parent_Id__c = r.Litigation__r.Petition__c;
                        sa.Related_Org_Parent_Name__c = r.Litigation__r.Petition__r.Petition_Name__c;
                    } else if (r.Litigation__r.Investigation__c != null) {
                        sa.Related_Org_Parent_Id__c = r.Litigation__r.Investigation__c;
                        sa.Related_Org_Parent_Name__c = r.Litigation__r.Investigation__r.Investigation_Name__c;
                    } else if (r.Litigation__r.Segment__c != null) {
                        sa.Related_Org_Parent_Id__c = r.Litigation__r.Segment__c;
                        sa.Related_Org_Parent_Name__c = r.Litigation__r.Segment__r.Segment_Name__c;
                    }
                    
                } else if (r.Petition__c != null) {
                    sa.Related_Org_Parent_Id__c = r.Petition__c;
                    sa.Related_Org_Parent_Name__c = r.Petition__r.Petition_Name__c;
                } else if (r.Segment__c != null) {
                    sa.Related_Org_Parent_Id__c = r.Segment__c;
                    sa.Related_Org_Parent_Name__c = r.Segment__r.Segment_Name__c;
                }
            }
        }
        return sa;
    }

    //wrapper class for rendering the list(s) of staffing assignments
    public class StaffingAssignmentWrapper {
        //public contructor variable mappings set to private for clarification in page
        private Id parentId {get; set;}
        private String parentSObjectType {get; set;}
        private List<Staffing_Assignment__c> staffList {get; set;}
        private Set<Id> userIdSet {get; set;}

        //variables for page and outer extension class access
        public String relOrg {get; set;}
        public Staffing_Assignment__c sa {get; set;}
        public Boolean overrideRole {get; set;}//data does not exist on Staffing Assignment record, only used to toggle SelectOption lists
        public Map<Id,String> recusalStatusMap {get; set;}
        public Map<Id,String> recusalLinkMap {get; set;}
        public Map<Id,String> recusalLinkTextMap {get; set;}
        //List of staffing assignment wrapper objects that will display in page
        public List<StaffingAssignmentWrapper> innerWrapperList {get {
            if(innerWrapperList == null) {
                innerWrapperList = new List<StaffingAssignmentWrapper>();
            }
            return innerWrapperList;
            } set;
        }
        //constructor used to create a class instance for holding repeated variables
        public StaffingAssignmentWrapper(Id parentId, String parentSObjectType, List<Staffing_Assignment__c> staffList, Set<Id> userIdSet) {
            this.parentId = parentId;
            this.parentSObjectType = parentSObjectType;
            this.staffList = staffList;
            this.userIdSet = userIdSet;
            populateRecusalStatus(staffList[0].ADCVD_Case__c, userIdSet);
            //for all the Staffing Assignments with and without users, create the wrappers
            for(Staffing_Assignment__c sa : staffList) {
                StaffingAssignmentWrapper saw = new staffingAssignmentWrapper(parentId, parentSObjectType, sa, recusalStatusMap, recusalLinkMap, recusalLinkTextMap);
                innerWrapperList.add(saw);
            }
        }

        //constructor used to create each wrapper in the staffWrapperList
        private StaffingAssignmentWrapper(Id parentId, String parentSObjectType, Staffing_Assignment__c sa, 
                                            Map<Id,String> recusalStatusMap, Map<Id,String> recusalLinkMap, Map<Id,String> recusalLinkTextMap) {
            //Staffing Assignment variables
            this.sa = sa;
            this.parentId = parentId;
            this.parentSObjectType = parentSObjectType;
            this.overrideRole = initialOverrideRole(this.sa);
            //Recusal variables
            this.recusalStatusMap = recusalStatusMap;
            this.recusalLinkMap = recusalLinkMap;
            this.recusalLinkTextMap = recusalLinkTextMap;
            this.relOrg = sa.Related_Organization__r.Account__r.Name != null ? sa.Related_Organization__r.Account__r.Name : null;
        }
        //sets the default override for each wrapper object
        private Boolean initialOverrideRole(Staffing_Assignment__c sa) {
            overrideRole =  sa.Title__c != null && sa.User__r.Staffing_Role__c != null && sa.Title__c != sa.User__r.Staffing_Role__c ? true : false;
            return overrideRole;
        }
        //Initializes SelectOption lists
        private void populateRecusalStatus(Id caseId, Set<Id> userIdSet){
            recusalStatusMap = new Map<Id,String>();
            recusalLinkMap = new Map<Id,String>();
            recusalLinkTextMap = new Map<Id,String>();
            for (Id userId : userIdSet) {
                recusalStatusMap.put(userId, 'This user does not have any active recusals.');
                recusalLinkMap.put(userId, '');
                recusalLinkTextMap.put(userId, '');
                }
            for (Id userId : usersWithActiveRecusals) {
                recusalStatusMap.put(userId, 'This user has active recusals.' + '<br/>');
                String recusalLinkText = recusalStatusMap.containsKey(userId) ? 'Review Recusals' : '';
                String recusalLink = '/apex/ReviewRecusalPage?userId=' + userId + '&caseId=' + caseId;
                recusalLinkMap.put(userId, recusalLink);
                recusalLinkTextMap.put(userId, recusalLinkText);
            }
        }
    }
}
