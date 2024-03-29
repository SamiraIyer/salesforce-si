/**
 * Services service interface.
 *
 * @author Andrew La Russa
 */
public interface IOpportunitiesSvcServices extends IOpportunitiesSvcBase {

	void createContractOrderAndOrderItemsWhenSowApproved(Set<Id> opportunityIds);
	void createContractOrderAndOrderItemsWhenSowApproved(List<SObject> records, Map<Id, SObject> existingRecords);
	void setStages(List<SObject> records);
	void setStages(List<SObject> records, Map<Id, SObject> existingRecords);
}