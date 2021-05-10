/**
 * Contains for 3 sample payment methods for illustration.
 * Each corresponding gateway must extend this class to formulate a valid payment gateway.
 * This abstract class must then refer to the gateway in order to acknowledge it as a payment processor.
 */
public abstract class XYZ_Gateway implements XYZ_Payment_Interface {
    
    private XYZ_Gateway_Config__mdt selectedGatewayProfile { get; set; }
    
    public class FailedGatewayConnectionException extends Exception {}
    
	public static final Map<String, Set<XYZ_Gateway_Config__mdt>> enabledGatewayProfilesByReceivingEntity;
    @TestVisible private static final Set<XYZ_Utils.PaymentMethod> supportedStrategies;
    @TestVisible private static final Map<XYZ_Utils.PaymentMethod, Set<XYZ_Gateway_Config__mdt>> supportedGatewayProfilesByStrategy;
    
    /**
     * At instantiation, the supported payment strategies are retrieved with their configuration details.
     * Each strategy may have multiple configurations enabled for payment procesing. For example,
     * the Receiving_Entity__c value can help differentiate accounts for transcation allocation.
     */
    static {
        enabledGatewayProfilesByReceivingEntity = new Map<String, Set<XYZ_Gateway_Config__mdt>>();
        supportedStrategies = new Set<XYZ_Utils.PaymentMethod>{
            XYZ_Utils.PaymentMethod.PAYPAL
            ,XYZ_Utils.PaymentMethod.STRIPE
            ,XYZ_Utils.PaymentMethod.OTHER
        };
        supportedGatewayProfilesByStrategy = new Map<XYZ_Utils.PaymentMethod, Set<XYZ_Gateway_Config__mdt>>();
        List<XYZ_Gateway_Config__mdt> gatewayProfiles = [select QualifiedApiName, Payment_Method__c, Accepts_Only_3D_Secure__c, Allowed_Bank_Cards__c, Currency_Code__c, Action_Code__c,
                                                         Maximum_Transaction__c, Minimum_Transaction__c, Public_Name__c, Terminal_ID__c, Terminal_Authenticator__c, Receiving_Entity__c,
                                                         Terminal_URL_Page_Hosted__c, Terminal_URL_Direct_Transaction__c, Transaction_Fee__c, Tracking_ID_Prefix__c, Enabled_Gateway__c from XYZ_Gateway_Config__mdt];
        Set<XYZ_Gateway_Config__mdt> correspondingProfiles;
        for(XYZ_Utils.PaymentMethod strategy : supportedStrategies) {
            correspondingProfiles = new Set<XYZ_Gateway_Config__mdt>();
            for(XYZ_Gateway_Config__mdt profile : gatewayProfiles) {
                if (String.valueOf(profile.Payment_Method__c).equals(strategy.name())) {
                    correspondingProfiles.add(profile);
                    if (profile.Enabled_Gateway__c) {
                        if (enabledGatewayProfilesByReceivingEntity.get(profile.Receiving_Entity__c) == null) {
                            enabledGatewayProfilesByReceivingEntity.put(profile.Receiving_Entity__c, new Set<XYZ_Gateway_Config__mdt>());
                        }
                        enabledGatewayProfilesByReceivingEntity.get(profile.Receiving_Entity__c).add(profile);
                    }
                }
            }
            supportedGatewayProfilesByStrategy.put(strategy, correspondingProfiles);
        }
    }
    
    /**
     * Constructs the class corresponding to the payment method and the entity
     * to whom the transaction returns are sent.
     *
     * @param paymentMethod (XYZ_Utils.PaymentMethod): The payment method.
     * @param payingTo (String): The receiving entity.
     */
    public XYZ_Gateway(XYZ_Utils.PaymentMethod paymentMethod, String payingTo) {
        String labelToRetrieve = paymentMethod.name() + String.valueOf(payingTo);
        List<XYZ_Gateway_Config__mdt> configs = [select QualifiedApiName, Payment_Method__c, Accepts_Only_3D_Secure__c, Allowed_Bank_Cards__c, Currency_Code__c,
                                                 Action_Code__c, Maximum_Transaction__c, Minimum_Transaction__c, Public_Name__c, Terminal_ID__c, Terminal_Authenticator__c,
                                                 Terminal_URL_Page_Hosted__c, Terminal_URL_Direct_Transaction__c, Transaction_Fee__c, Tracking_ID_Prefix__c
                                                 from  XYZ_Gateway_Config__mdt where QualifiedApiName = :labelToRetrieve];
        if (!configs.isEmpty()) {
            selectedGatewayProfile = configs.get(0);
        }
    }
    
    /**
     * Interface implementation to return a string response from processing a payment from checkout.
     *
     * @param payment (Payment_Request__c): The payment request.
     * @return String
     */
    public String processPayment(Payment_Request__c payment) {
        if (payment == null)
            return null;
        try {
            URL redirectUrl = generatePaymentUrl(payment);
            if (redirectUrl != null) {
                return redirectUrl.toExternalForm();
            }
            else {
                return generatePaymentFormQuery(payment);
            }
        }
        catch(Exception e) {
            return e.getMessage();
        }
    }
    
    /**
     * Returns a string from processing a response from a gateway. The response would typically be
     * a redirect (page reference) from the connected gateway. Returns null if the response
     * is invalid or no gateway class is implemented to process the response.
     *
     * @param responseContent (Object): Object response coming from gateway.
     * @return String
     */
    public String processResponseIfSupported(Object responseContent) {
        String result = null;
        if ((responseContent != null) && (responseContent instanceOf PageReference)) {
            PageReference currentPage = (PageReference) responseContent;
            Response processedResponse = null;
            if (supportedStrategies.contains(XYZ_Utils.PaymentMethod.PAYPAL)) {
                processedResponse = new XYZ_Gateway_PAYPAL(XYZ_Utils.DEFAULT_RECIPIENT_ENTITY).generateResponse(currentPage);
            }
            else if (supportedStrategies.contains(XYZ_Utils.PaymentMethod.STRIPE)) {
                processedResponse = new XYZ_Gateway_STRIPE(XYZ_Utils.DEFAULT_RECIPIENT_ENTITY).generateResponse(currentPage);
            }
            else if (supportedStrategies.contains(XYZ_Utils.PaymentMethod.OTHER)) {
                processedResponse = new XYZ_Gateway_OTHER(XYZ_Utils.DEFAULT_RECIPIENT_ENTITY).generateResponse(currentPage);
            }
            if (processdResponse != null) {
                result = processedResponse.process();
                if (String.isNotBlank(result)) {
                    return result;
                }
            }
        }
        return result;
    }
    
    public XYZ_Gateway_Config__mdt getPaymentProfile() {
        return selectedGatewayProfile;
    }
    
    /**
     * Virtual method extended by any gateway class providing a redirect URL to the
     * connected gateway in order to process the payment request. Typically used by
     * hosted payment gateways with unique URL per transaction.
     *
     * @param paymentId (Payment_Request__c): The payment request.
     * @return URL validated url to redirect to the hosted gateway.
     */
    public virtual URL generatePaymentUrl(Payment_Request__c paymentId) {
        return null;
    }
    
    /**
     * Virtual method extended by any gateway class relying on submitting a form on frontend
     * to redirect to the gateway. Typically used by hosted payment gateways with generated
     * form content without a unique URL per transaction. Expected to auto submit at checkout
     * for a redirect to the gateway.
     * 
     * IMPORTANT: Form tag html attributes are quoted with @ signs in order to distinguish them from input keys.
     *      eg: 'method' -> '@method@' or 'enctype' -> '@enctype@'
     *
     * @param paymentId (Payment_Request__c): The payment request.
     * @return String JSON payload containing directives to build the redirect form.
     */
    public virtual String generatePaymentFormQuery(Payment_Request__c paymentId) {
        return null;
    }

    /**
     * Abstract method to be extended by any gateway to generate its own custom response object.
     * The response signature should be unique as it will identify the gateway used during checkout.
     *
     * @param currentPage (PageReference): The page reference.
     * @return Response
     */
    public abstract Response generateResponse(PageReference currentPage);
    
    /**
     * It is expected that a gateway connected to the payment platform would have
     * a response object that can process its own response and thus implements this interface
     * and its method(s).
     */
    public interface Response {
        String process();
    }

    /**
     * Validates that a payment request has all the required fields set to be processed by the given payment method.
     * Throws exceptions if the expected conditions are not met.
     *
     * @param payment (Payment_Request__c): The payment request.
     * @param paymentMethod (XYZ_Utils.PaymentMethod): The payment method.
     */
    public void validatePaymentRequestForProcessing(Payment_Request__c payment, XYZ_Utils.PaymentMethod paymentMethod) {
        Set<Schema.DescribeFieldResult> requiredFields = new Set<Schema.DescribeFieldResult>();
        requiredFields.add(Payment_Request__c.Payment_Method__c.getDescribe());
        requiredFields.add(Payment_Request__c.Tracking_ID__c.getDescribe());
        requiredFields.add(Payment_Request__c.Amount_Transacted__c.getDescribe());
        requiredFields.add(Payment_Request__c.Payer_Email__c.getDescribe());
        
        String paymentJSONString = JSON.serialize(payment);
        Map<String, Object> paymentAsMap = (Map<String, Object>) JSON.deserializeUntyped(paymentJSONString);
        Set<String> collectedFields = paymentAsMap.keyset();
        Object valueContainer;
        for(Schema.DescribeFieldResult requiredField : requiredFields) {
            if (collectedFields.contains(requiredField.getName())) {
                valueContainer = paymentAsMap.get(requiredField.getName());
                if ((valueContainer == null) || (String.isBlank(String.valueOf(valueContainer)))) {
                    throw new FailedGatewayConnectionException('Value required for the following field: ' + requiredField.getLabel());
                }
            }
            else throw new FailedGatewayConnectionException('Payment missing required field: ' + requiredField.getLabel());
        }
        
        if (! String.valueOf(payment.Payment_Method__c).equals(paymentMethod.name()))
            throw new FailedGatewayConnectionException('Payment method is not supported by this gateway');
    }
	
}