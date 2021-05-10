public interface XYZ_Payment_Interface {
    
    /**
     * It is expected that a gateway connected to the payment platform would have
     * the following capabilities:
     * 1. Ability to retrieve a payment profile object for the connected gateway.
     * 2. Ability to process a payment request generated at checkout by a user action.
     * 3. Ability to process a response object returned from the connected gateway, if any.
     * 
     * Thus the corresponding methods below to be extended by the class implementing the interface.
     */
    
    String processPayment(Payment_Request__c payment);
    
    String processResponseIfSupported(Object responseContent);
    
    Object getPaymentProfile();
    
}