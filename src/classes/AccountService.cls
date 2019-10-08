public class AccountService {

	private static IAccountService service(){
		return (IAccountService) fflibext_Application.Service.newInstance(IAccountService.class);
	}

	public static List<Account> updateAccountAddresses(List<Participation__c> participationList){
		return service().updateAccountAddresses(participationList);
	}

	public class AccountServiceException extends Exception {}

}