/*
	Author: Jeff Weyhrauch
	Date: 5-18-2020
	Name: Payments2ServiceImpl.cls
	Purpose:
		The implementation for the operations and work we plan to do on the Payment2Utils object or as a result of the
		Payment2Utils object being updated. Which implementation is used is determined by custom metadata.
 */
public class Payments2ServiceImpl implements IPayments2Service{

    /**Update SystemSearchString Field with Transaction Amount,Transaction Date,
    *  and Payment Date.
    */
    public static void updateSystemSearchStringList(List<Payment2__c> paymentList){
        for(Payment2__c payment : paymentList){
            String systemSearchString = '$'+payment.Transaction_Amount__c;
            if (payment.Transaction_Date__c != null) {
                Date transactionDate = Date.newInstance(payment.Transaction_Date__c.year(), payment.Transaction_Date__c.month(), payment.Transaction_Date__c.day());
                systemSearchString += ' | ' + transactionDate.format();
            }
            if (payment.Payment_Date__c != null) {
                systemSearchString += ' | ' + payment.Payment_Date__c.format();
            }
            payment.System_Search_String__c = systemSearchString;
        }
    }

	public static void sendEmailReceipt(Map<Id,Payment2__c> existingRecords, List<Payment2__c> newRecords) {
		// There is a fair amount of complexity required in order to get the email associated with a Payment2 record
		// that is passed to this method.
		// It looks roughly like this:
		// Payment2 => Order => OpportunityContactRole(viaOpportunityId)
		//
		// For each Payment2 record we have to do the following:
		//		1. Determine if the Payment2 is a Payment or a refund
		//		2. If a refund - get the parent Payment which is the actual payment for the Payment2 that is passed in
		//		3. Get the Order associated with the Payment2
		//		4. Get the OpportunityContactRole associated with the Order Opportunity. The email that the receipt
		//		will be sent to is 'owned' by the Contact.email on the OpportunityContactRole
		//
		// Create a Set for all of the PaymentIds in newRecords and existingRecords
		Set<Id> paymentRecordIds = new Set<id>();
		if (existingRecords != null && existingRecords.size() > 0) {
			paymentRecordIds.addAll(existingRecords.keySet());
		}
		for(Payment2__c p2 : newRecords){
			paymentRecordIds.add(p2.Id);
		}

		// Retrieve all of the Orders associated with these payments
		List<Payment2__c> payments = PaymentsSelector2.newInstance().selectById(paymentRecordIds);

		//Get the Payment2 Record Type map
		Map<String, Id> rtMap = Utils.getRecordTypeIdMap('Payment2__c');

		// getOrdersPaymentIds Contains the payment Ids that have orders associated with them
		Set<Id> getOrdersPaymentIds = new Set<Id>();

		// refundPaymentParentIds are the payment ids whose child is a refund
		// Since a refund does not have an associated order, we have to get the parent Payment of the refund
		// The Id of the parent is stored in this set and used in a select to get the order associated with the refund
		Set<Id> refundPaymentParentIds = new Set<Id>();
		Boolean addResult = getOrdersPaymentIds.addAll(paymentRecordIds);
		// paymentToRefundMap maps refunds to payments
		Map<Id, Id> paymentToRefundMap = new Map<Id, Id>();
		for (Payment2__c p2 : payments) {
			if (p2.Payment_Type__c == 'NIST-Handled Refund' || p2.Payment_Type__c == 'Credit Card Refund'){
				// This payment is a refund
				paymentToRefundMap.put(p2.Id, p2.Payment_2__c);
				// Add the actual Payment Id to the set that is used to Select
				refundPaymentParentIds.add(p2.Payment_2__c);
				// Add the actual payment to the set that will be used to Select Orders
				getOrdersPaymentIds.add(p2.Payment_2__c);
				// Take out the Payment2.Id associated with a refund
				getOrdersPaymentIds.remove(p2.Id);
			}
		}

		List<Payment2__c> refundParentPayment2 = PaymentsSelector2.newInstance().selectById(refundPaymentParentIds);
		// Add the orders associated with Parent Payments to the set of orderIds that we will select
		for(Payment2__c p2 : refundParentPayment2){
			getOrdersPaymentIds.add(p2.Id);
		}
		// Get the Orders.OpportunityId for orders associated with getOrdersPaymentIds
		Map<Id, Id> orderToOppMap = new Map<Id, Id>();
		Map<Id, Id> paymentToOrderMap = new Map<Id, Id>();
		List<Order> getOpportunitiesFromTheseOrders = OrdersSelector.newInstance().selectByPaymentId(getOrdersPaymentIds);
		// getOpportunityContactRoles
		Set<Id> getOpportunityContactRoles = new Set<Id>();
		for(Order o : getOpportunitiesFromTheseOrders){
			// getOpportunityContactRoles is used to select OpportunityContactRoles
			getOpportunityContactRoles.add(o.OpportunityId);
			orderToOppMap.put(o.Id, o.OpportunityId);
			paymentToOrderMap.put(o.Payment2__c, o.Id);
		}

		// Create a list of all OpportunityContactRole where the Contact isPrimary from the Opportunities
		List<OpportunityContactRole> emailsToSend = OpportunityContactRolesSelector.newInstance().selectByOpportunityId(getOpportunityContactRoles, true);

		// Tie everything together creating the Payment to email map
		Map<Id, String> oppToEmailMap = new Map<Id, String>();
		for(OpportunityContactRole ocr : emailsToSend){
			oppToEmailMap.put(ocr.OpportunityId, ocr.Contact.Email);
		}

		// Create a CSV containing all of the emails in the OpportunityContactRole isPrimary list
		// Create an Id, String Map before the following loop
		for(Payment2__c payment2 : newRecords) {
			Id thisPaymentId;
			String thisEmail;

			// The code can be run either from insert or update
			// When Insert - the email should always be sent
			// When Update - this method will be triggered twice and we only want to run the email section on the first pass
			Boolean emailCondition = false;
			if (existingRecords == null || existingRecords.size() == 0) {
				emailCondition = true;
			} else if(existingRecords.get(payment2.Id).Receipt_Ready__c == false){
				emailCondition = true;
			}

			if(emailCondition && payment2.Receipt_Ready__c == true && payment2.Receipt_Allowed__c == true) {
				//if(payment2.Receipt_Ready__c == true && payment2.Receipt_Allowed__c == true) {
				//receipt ready flag was just checked
				// If the Payment2 is a refund - use it's parent
				if (refundPaymentParentIds != null && (!refundPaymentParentIds.contains(payment2.Id))) {
					thisPaymentId = paymentToRefundMap.get(payment2.Id);
				} else {
					thisPaymentId = payment2.Id;
				}

				//Get the email address(es) to which to send the receipt
				if (payment2.RecordTypeId == rtMap.get('External_Credit_Card_or_ACH_Payment')) {
					//This payment is for an external payment.
					//Grab the email address from the payment record
					thisEmail = payment2.Receipt_Email_Address__c;
				} else {
				// paymentToOrderMap.get(thisPaymentId) gives us the Order associated with the Payment2
				// orderToOppMap.get gives us the Opportunity for the Payment2
				// oppToEmailMap.get gives us the email associated with the Payment2
				thisEmail = oppToEmailMap.get(orderToOppMap.get(paymentToOrderMap.get(thisPaymentId)));
				}
				String returnMessage = REST_EmailTransactionReceipt.emailReceipt(thisEmail, payment2.Id);
			}
		}
	}

	public static String beginPayment(Id orderId) {
		REST_BeginPaymentParams params = populateBeginPaymentParams(orderId);
		return REST_BeginPayment.beginPayment(params);
	}

	private static REST_BeginPaymentParams populateBeginPaymentParams(Id orderId) {
		REST_BeginPaymentParams params = new REST_BeginPaymentParams();
		params.confirmationPage = getBaseUrl() + '/one/one.app#/alohaRedirect/apex/Payment2Confirmation';
		params.failurePage = getBaseUrl() + '/one/one.app#/alohaRedirect/apex/Payment2Confirmation';
		params.orderId = orderId;
		params.internalCaller = true;
		return params;
	}

	private static String getBaseUrl() {
		return URL.getSalesforceBaseUrl().toExternalForm();
	}

	public static String confirmPayment(String accountType, String paymentId, String token, String orderId) {
		return REST_ConfirmPayment.beginConfirmPayment(accountType, paymentId, token, orderId);
	}

	public static Payment2__c createPayment(REST_BeginPaymentParams params) {
		//Check for missing data
		if (String.isBlank(params.orderId) &&
			(String.isBlank(params.accountType) ||
				String.isBlank(params.transactionAmount) ||
				String.isBlank(params.projectCode) ||
				String.isBlank(params.taskCode) ||
				String.isBlank(params.objectClass) ||
				String.isBlank(params.organizationCode) ||
				String.isBlank(params.originatingOffice ) ||
				String.isBlank(params.organizationName))) {
			throw new IllegalArgumentException('Either orderId or these values are required: accountType, transactionAmount, projectCode, collectionPost,  fulfillmentPost, organizationName');
		}

		RecordLog.push('Payment.createPayment');
		RecordLog.message('Order Id: ' + params.orderId);

		//Begin to create the payment record
		Payment2__c payment = new Payment2__c();

		populatePaymentDetailsFromParameters(payment, params);

		RecordLog.message('Account Type: ' + 		payment.Account_Type__c);
		RecordLog.message('Organization Name: ' + 	payment.Organization_Name__c);
		RecordLog.message('Project Code: ' + 		payment.Project_Code__c);
		RecordLog.message('Transaction Amount: ' + 	payment.Transaction_Amount__c);
		RecordLog.message('Task Code: ' + 			payment.Task_Code__c);
		RecordLog.message('Object Class: ' + 		payment.Object_Class__c);
		RecordLog.message('Invoice Date: ' + 		payment.Invoice_Date__c);
		RecordLog.message('Invoice Id: ' + 			payment.Invoice_Id__c);
		RecordLog.message('Originating Office: ' +  payment.Fulfillment_Post_Acronym__c);

		insertPaymentDML(payment);

		return payment;
	}

	public static String authorizePayment(PaymentAuthenticationDetails paymentAuthenticationDetails) {
		//Handle exceptions in the calling method
		IPayment payment = (IPayment) di_Injector.Org.getInstance('PaymentProcessor');
		return payment.authorizePayment(paymentAuthenticationDetails);
	}

	public static String getPaymentProcessorData(Id paymentId, REST_BeginPaymentParams params) {

		//Check for required fields
		if (paymentId == null || String.isBlank(params.confirmationPage) || String.isBlank(params.failurePage)) {
			throw new IllegalArgumentException('paymentId, params.confirmationPage, and params.failurePage are required parameters.');
		}

		//Since Name is an Auto-Number field, must query the paymentObject to get the value
		List<Payment2__c> payments = PaymentsSelector2.newInstance().selectById(new Set<Id>{paymentId});
		Payment2__c payment = payments[0];

		String paymentIdentifier = payment.Name;
		RecordLog.message('Payment Identifier: ' + paymentIdentifier);

		PaymentAuthenticationDetails details = new PaymentAuthenticationDetails();
		details.paymentId = payment.Id;
		details.paymentIdentifier = paymentIdentifier;
		details.transactionType = 'Sale';
		details.transactionAmount = String.valueOf(payment.Transaction_Amount__c);

		details.successUrl = params.confirmationPage + '?paymentId=' + payment.Id + '&acctType='
			+ payment.Account_Type__c;
		if (String.isNotBlank(params.orderId)) {
			details.successUrl += '&orderId=' + params.orderId;
		}
		RecordLog.message('Success Url: ' + details.successUrl);

		details.cancelUrl = params.failurePage + '?cancel=true';
		RecordLog.message('Cancel Url: ' + details.cancelUrl);

		if (String.isNotBlank(params.accountHolderName)) {
			details.accountHolderName = params.accountHolderName;
		}
		RecordLog.message('Account Holder Name: ' + details.accountHolderName);

		if (String.isNotBlank(params.billingAddress)) {
			details.billingAddress = params.billingAddress;
		}
		RecordLog.message('Billing Address: ' + details.billingAddress);

		if (String.isNotBlank(params.billingCity)) {
			details.billingCity = params.billingCity;
		}
		RecordLog.message('Billing City: ' + details.billingCity);

		if (String.isNotBlank(params.billingStateCode)) {
			details.billingStateCode = params.billingStateCode;
		}
		RecordLog.message('Billing State Code: ' + details.billingStateCode);

		if (String.isNotBlank(params.billingZip)) {
			details.billingZip = params.billingZip;
		}
		RecordLog.message('Billing Zip Code: ' + details.billingZip);

		if (String.isNotBlank(params.billingCountryCode)) {
			details.billingCountryCode = params.billingCountryCode;
		}
		RecordLog.message('Billing Country Code: ' + details.billingCountryCode);

		//details.email = users[0].Contact.Email;  //Do not populate now.  Currently unused at Pay.gov.
		//If do populate email, do not allow plus sign in email address or Pay.gov will error.
		details.accountType = payment.Account_Type__c;
		String remoteAccountName = Payment2Utils.getRemoteAccountName(payment.Account_Type__c);
		RecordLog.message('Remote Account Name: ' + remoteAccountName);
		details.remoteAccountName = remoteAccountName;
		RecordLog.emit(payment.Id);
		return JSON.serialize(details);
	}

	public static List<Payment2__c> getTransactions(String accountType, String paymentMethod, String transactionType, String fromDateString, String toDateString, String downloaded) {
		try {
			String transactionStatus;
			String recordTypeId;
			String paymentType;
			Boolean nonTransmittedOnly = true;

			//From Datetime
			Date fromDate = Date.parse(fromDateString);
			Datetime fromDatetime = Datetime.newInstance(fromDate.year(), fromDate.month(), fromDate.day(),0,0,0);

			//To Datetime
			Date toDate = Date.parse(toDateString);
			Datetime toDatetime =  Datetime.newInstance(toDate.year(), toDate.month(), toDate.day(),23,59,59);

			Map<String, Id> rtMap = Utils.getRecordTypeIdMap('Payment2__c');

			if (transactionType == 'Payments') {
				recordTypeId = rtMap.get('Credit_Card_or_ACH_Payment');
				if (paymentMethod == 'Credit Card') {
					paymentType = 'PLASTIC_CARD';
					transactionStatus = 'Success';
				} else if (paymentMethod == 'ACH') {
					paymentType = 'ACH';
					transactionStatus = 'Received';
				}
			} else if (transactionType == 'Refunds') {
				recordTypeId = rtMap.get('Credit_Card_Refund');
				transactionStatus = 'Success';
				paymentType = 'Credit Card Refund';
			}

			if (downloaded == 'All') {
				nonTransmittedOnly = false;
			}

			return PaymentsSelector2.newInstance().selectByTransactionDetails(accountType, paymentType, recordTypeId, transactionStatus, fromDatetime, toDatetime, nonTransmittedOnly);
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	public static Order getOrderByPaidNonPaidOnly(String orderId, Boolean nonPaidOnly, Boolean paidOnly) {
		try {
			Set<Id> orderIds = new Set<Id>{orderId};//
			List<Order> orders = OrdersSelector.newInstance().selectByPaidNonPaidOnly(orderIds, nonPaidOnly, paidOnly);
			if (orders.size() > 0) {
				return orders[0];
			}
			return null;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	public static List<Order> getOrdersByContractId(String contractId, Boolean onlyCreditCardPayments, Boolean nonPaidOnly, Boolean paidOnly) {
		try {
			Set<Id> contractIds = new Set<Id>{contractId};
			List<Order> orders = OrdersSelector.newInstance().selectByContractId(contractIds, onlyCreditCardPayments, nonPaidOnly, paidOnly);
			return orders;
		} catch (Exception e) {
			throw new AuraHandledException(e.getMessage());
		}
	}

	private static Payment2__c populatePaymentDetailsFromOrder(REST_BeginPaymentParams params, Payment2__c payment) {
		List<Order> orderListWithDetails = OrdersSelector.newInstance().selectWithOrderItemDetails(new Set<Id>{params.orderId}, true);

		payment.Organization_Name__c = orderListWithDetails[0].Opportunity.Account.Name;
		RecordLog.message('Organization Name: ' + payment.Organization_Name__c);
		payment.Opportunity_Owner__c = orderListWithDetails[0].Opportunity.Owner.Name;
		RecordLog.message('Opportunity Owner: ' + payment.Opportunity_Owner__c);
		payment.Opportunity_Created_Date__c = orderListWithDetails[0].Opportunity.CreatedDate;
		RecordLog.message('Opportunity Created Date: ' + payment.Opportunity_Created_Date__c);
		payment.Collection_Post_Name__c = orderListWithDetails[0].Opportunity.Collection_Post__r.Name;
		RecordLog.message('Collection Post Name: ' + payment.Collection_Post_Name__c);
		payment.Collection_Post_Org_Code__c = orderListWithDetails[0].Opportunity.Collection_Post__r.Org_Code__c;
		RecordLog.message('Collection Post Org Code: ' + payment.Collection_Post_Org_Code__c);
		payment.Collection_Post_Acronym__c = orderListWithDetails[0].Opportunity.Collection_Post__r.Acronym__c;
		RecordLog.message('Collection Post Acronym: ' + payment.Collection_Post_Acronym__c);
		payment.Fulfillment_Post_Name__c = orderListWithDetails[0].Opportunity.Fulfillment_Post__r.Name;
		RecordLog.message('Fulfillment Post Name: ' + payment.Fulfillment_Post_Name__c);
		payment.Fulfillment_Post_Org_Code__c = orderListWithDetails[0].Opportunity.Fulfillment_Post__r.Org_Code__c;
		RecordLog.message('Fulfillment Post Org Code: ' + payment.Fulfillment_Post_Org_Code__c);
		payment.Fulfillment_Post_Acronym__c = orderListWithDetails[0].Opportunity.Fulfillment_Post__r.Acronym__c;
		RecordLog.message('Fulfillment Post Acronym: ' + payment.Fulfillment_Post_Acronym__c);

		payment.Contract__c = orderListWithDetails[0].ContractId;
		RecordLog.message('Contract Id: ' + payment.Contract__c);

		payment.Account_Type__c = orderListWithDetails[0].Type;

		if (orderListWithDetails[0].OrderItems != null
			&& orderListWithDetails[0].OrderItems.size() > 0
			&& String.isNotBlank(orderListWithDetails[0].OrderItems[0].Accounting_Code__c)) {
			payment.Project_Code__c = orderListWithDetails[0].OrderItems[0].Accounting_Code__c.Left(4) + '231';
		} else {
			throw new Payment2Utils.PaymentException('Project Code is missing.');
		}

		payment.Transaction_Amount__c = orderListWithDetails[0].TotalAmount;

		return payment;
	}

	private static void populatePaymentDetailsFromParameters(Payment2__c payment, REST_BeginPaymentParams params) {
		String recordTypeName;
		if (String.isNotBlank(params.orderId)) {
			recordTypeName = 'Credit_Card_or_ACH_Payment';
		} else {
			recordTypeName = 'External_Credit_Card_or_ACH_Payment';
		}
		payment.RecordTypeId = Utils.getRecordTypeIdMap('Payment2__c').get(recordTypeName);

		RecordLog.message('Record Type Id: ' + payment.RecordTypeId);

		if (String.isNotBlank(params.projectCode)) {
			payment.Project_Code__c = params.projectCode;
		}

		if (String.isNotBlank(params.accountType)) {
			payment.Account_Type__c = params.accountType;
		}

		if (String.isNotBlank(params.transactionAmount)) {
			payment.Transaction_Amount__c = Decimal.valueOf(params.transactionAmount);
		}

		if (String.isNotBlank(params.organizationName)) {
			payment.Organization_Name__c = params.organizationName;
		}

		if (String.isNotBlank(params.taskCode )) {
			payment.Task_Code__c = params.taskCode ;
		}

		if (String.isNotBlank(params.objectClass)) {
			payment.Object_Class__c  = params.objectClass ;
		}

		if (String.isNotBlank(params.invoiceDate)) {
			payment.Invoice_Date__c = params.invoiceDate ;
		}

		if (String.isNotBlank(params.invoiceId )) {
			payment.Invoice_Id__c  = params.invoiceId ;
		}

		if (String.isNotBlank(params.organizationCode )) {
			payment.Fulfillment_Post_Org_Code__c = params.organizationCode ;
		}

		if (String.isNotBlank(params.originatingOffice )) {
			payment.Fulfillment_Post_Acronym__c = params.originatingOffice;
		}

		if (String.isNotBlank(params.receiptEmailAddresses )) {
			payment.Receipt_Email_Address__c = params.receiptEmailAddresses;
		}

		if (String.isNotBlank(params.orderId)) {
			payment = populatePaymentDetailsFromOrder(params, payment);
		}
	}

	private static void insertPaymentDML(Payment2__c payment) {
		RecordLog.message('Inserting Payment');
		try {
			fflib_SObjectUnitOfWork uow = new fflib_SObjectUnitOfWork(new List<SObjectType> {Payment2__c.SObjectType});
			uow.registerNew(payment);
			uow.commitWork();
		} catch (Exception e) {
			RecordLog.message('Exception: ' + e.getMessage());
			RecordLog.emit('No Payment Id');
			throw e;
		}
		RecordLog.message('Payment inserted');
	}

	/**
	 * Format User Info field values for sending to pay.gov
	 *
	 * @param userElement A value that will be passed to pay.gov.
	 * @param charLimit The character limit allowed by pay.gov.
	 */
	// Formats user info field values for sending to pay.gov
	private static String userElementFormat(String userElement, Integer charLimit) {
		if (userElement != null) {
			userElement = userElement.length() > charLimit ? userElement.substring(0, charLimit) : userElement;
		}
		return userElement;
	}

	/**
	 * Get the current fiscal year
	 */
	private static String getCurrentFiscalYear() {
		Date currentDate = Date.today();  //Check for GMT
		Integer year = currentDate.year();
		Integer month = currentDate.month();
		if (month > 9) {
			year++;
		}
		return String.valueOf(year);
	}

	/**
	 * Get the time zone offset, which allows GMT dates to be converted to Washington DC time.
	 */
	private static Integer getTimeZoneOffset() {
		Timezone tz = Timezone.getTimeZone('America/New_York');
		// Create a date after the 2007 shift of DST into November
		DateTime dt = system.now();
		//tz.getOffset(dt)  == -18000000 (== -5 hours, which is EST)
		Integer offsetSeconds = tz.getOffset(dt)/1000*-1;  //1000 is to convert milliseconds to seconds and -1 is to add seconds instead of subtract
		return offsetSeconds;
	}

}
