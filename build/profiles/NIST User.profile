<?xml version="1.0" encoding="UTF-8"?>
<Profile xmlns="http://soap.sforce.com/2006/04/metadata">
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Task_Code__c</field>
        <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Order.System_Search_String__c</field>
        <readable>false</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.System_Search_String__c</field>
        <readable>false</readable>
    </fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.Collection_Post_Acronym__c</field>
                <readable>true</readable>
        </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Invoice_Date__c</field>
	<readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
                <editable>false</editable>
                <field>Payment2__c.Collection_Post_Name__c</field>
                <readable>true</readable>
    </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Invoice_Id__c</field>
        <readable>true</readable>
    </fieldPermissions>
        <fieldPermissions>
                <editable>false</editable>
                <field>Payment2__c.Collection_Post_Org_Code__c</field>
                <readable>true</readable>
        </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Object_Class__c</field>
        <readable>true</readable>
    </fieldPermissions>
        <fieldPermissions>
                <editable>false</editable>
                <field>Payment2__c.Fulfillment_Post_Acronym__c</field>
                <readable>true</readable>
        </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Receipt_Allowed__c</field>
        <readable>true</readable>
    </fieldPermissions>
        <fieldPermissions>
                <editable>false</editable>
                <field>Payment2__c.Collection_Post_Name__c</field>
                <readable>true</readable>
        </fieldPermissions>
    <fieldPermissions>
        <editable>false</editable>
        <field>Payment2__c.Receipt_Email_Address__c</field>
        <readable>true</readable>
    </fieldPermissions>
        <fieldPermissions>
                <editable>false</editable>
                <field>Payment2__c.Fulfillment_Post_Org_Code__c</field>
                <readable>true</readable>
        </fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.Opportunity_Created_Date__c</field>
		<readable>true</readable>
	</fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.Opportunity_Owner__c</field>
		<readable>true</readable>
	</fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.Organization_Name__c</field>
		<readable>true</readable>
	</fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.Project_Code__c</field>
		<readable>true</readable>
	</fieldPermissions>
	<fieldPermissions>
		<editable>false</editable>
		<field>Payment2__c.System_Search_String__c</field>
		<readable>true</readable>
	</fieldPermissions>
    <layoutAssignments>
        <layout>Payment2__c-External Credit Card or ACH Payment</layout>
        <recordType>Payment2__c.External_Credit_Card_or_ACH_Payment</recordType>
    </layoutAssignments>
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>ContactPointEmail</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
    <objectPermissions>
        <allowCreate>false</allowCreate>
        <allowDelete>false</allowDelete>
        <allowEdit>false</allowEdit>
        <allowRead>true</allowRead>
        <modifyAllRecords>false</modifyAllRecords>
        <object>ContactPointPhone</object>
        <viewAllRecords>false</viewAllRecords>
    </objectPermissions>
	<recordTypeVisibilities>
		<default>false</default>
		<recordType>Payment2__c.Bank_Transfer_Payment</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
	<recordTypeVisibilities>
		<default>false</default>
		<recordType>Payment2__c.Cash_Payment</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
	<recordTypeVisibilities>
		<default>false</default>
		<recordType>Payment2__c.Check_Payment</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
	<recordTypeVisibilities>
		<default>false</default>
		<recordType>Payment2__c.Credit_Card_Refund</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
	<recordTypeVisibilities>
		<default>true</default>
		<personAccountDefault>true</personAccountDefault>
		<recordType>Payment2__c.Credit_Card_or_ACH_Payment</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
	<recordTypeVisibilities>
		<default>false</default>
		<recordType>Payment2__c.NIST_Issued_Refund</recordType>
		<visible>true</visible>
	</recordTypeVisibilities>
    <recordTypeVisibilities>
        <default>false</default>
        <recordType>Payment2__c.External_Credit_Card_or_ACH_Payment</recordType>
        <visible>true</visible>
    </recordTypeVisibilities>
	<tabVisibilities>
		<tab>Action_Items</tab>
		<visibility>DefaultOn</visibility>
	</tabVisibilities>
	<tabVisibilities>
		<tab>standard-report</tab>
		<visibility>DefaultOn</visibility>
	</tabVisibilities>
    <userPermissions>
        <enabled>true</enabled>
        <name>TransferAnyCase</name>
    </userPermissions>
</Profile>
