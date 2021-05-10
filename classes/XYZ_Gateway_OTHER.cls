public class XYZ_Gateway_OTHER extends XYZ_Gateway {
    
    private static final XYZ_Utils.PaymentMethod paymentMethod = XYZ_Utils.PaymentMethod.OTHER;
    
    public XYZ_Gateway_OTHER(String payingTo) {
        super(paymentMethod, payingTo); 
    }
	
    public override URL generatePaymentUrl(Payment_Request__c payment) {
        validatePaymentRequestForProcessing(payment, paymentMethod);
        return generatePageHostedPaymentUrl(payment);
    }
    
    private URL generatePageHostedPaymentUrl(Payment_Request__c payment) {
        // Generate XML request
		HttpRequest req = buildSimpleXmlHttpRequest(payment);
        
        // Send to gateway
        Http http = new Http();
        HttpResponse res;
        try {
            res = http.send(req);
        }
        catch(Exception e) {
            throw new FailedGatewayConnectionException(e.getMessage());
        }
        
        // Check response from request
        if ((res.getStatusCode() == 200) && res.getBody().contains('someIdentifier') && res.getBody().contains('transactionId')) {
            Dom.Document body = res.getBodyDocument();
            dom.XmlNode root = body.getRootElement();
            String targetUrl = root.getChildElement('targetUrl', null).getText();
            String transactionId = root.getChildElement('transactionId', null).getText();
            URL redirect = new URL(targetUrl + transactionId);
            return redirect;
        }
        throw new FailedGatewayConnectionException('No successful response from the gateway');
    }
    
    private HttpRequest buildSimpleXmlHttpRequest(Payment_Request__c payment) {
        dom.Document payload = new dom.Document();
        
        dom.XmlNode payloadContent = payload.createRootElement('request', null, null);
        
        payloadContent.addChildElement('action', null, null).addTextNode(String.valueOf(getPaymentProfile().Action_Code__c));
        payloadContent.addChildElement('amount', null, null).addTextNode(String.valueOf(payment.Amount_Transacted__c + getPaymentProfile().Transaction_Fee__c));
        payloadContent.addChildElement('email', null, null).addTextNode(payment.Payer_Email__c);
        payloadContent.addChildElement('trackingId', null, null).addTextNode(payment.Tracking_ID__c);
        //... etc other fields to fill in
        
        HttpRequest req = new HttpRequest();
        
        req.setMethod('POST');
        req.setHeader('Content-Type', 'text/xml;charset=utf-8');
        req.setBody(payload.toXmlString());
        req.setTimeout(30*1000); // or XYZ_Utils.SOME_DEFAULT_TIMEOUT_PERIOD
        req.setEndpoint(getPaymentProfile().Terminal_URL_Page_Hosted__c);
        req.setClientCertificateName(XYZ_Utils.SOME_VERIFICATION_CERTIFICATE_FILE_DESCRIPTOR);
        
        return req;
    }
    
    public override Response generateResponse(PageReference currentPage) {
        return new OTHER_Response(currentPage);
    }
    
    public class OTHER_Response implements Response {
        public String responsecode { get; protected set; }
        public String result { get; protected set; }
        public String trackingId { get; protected set; }
        public String transactionId { get; protected set; }
        public Boolean valid { get { return (valid != null) && valid; } protected set; }
        public Boolean processed { get { return (processed != null) && processed; } protected set; }
        
        public OTHER_Response(PageReference currentPage) {
            this.valid = false;
            if (currentPage != null) {
                String _responsecode =  currentPage.getParameters().get('responsecode');
                String _result = currentPage.getParameters().get('result');
                String _trackingId = currentPage.getParameters().get('trackingId');
                String _transactionId = currentPage.getParameters().get('transactionId');
                if(String.isNotBlank(_responsecode) && String.isNotBlank(_result) && String.isNotBlank(_trackingId) && String.isNotBlank(_transactionId)) {
                    this.responsecode = String.escapeSingleQuotes(_responsecode);
                    this.trackingId = String.escapeSingleQuotes(_trackingId);
                    this.result = String.escapeSingleQuotes(_result);
                    this.transactionId = String.escapeSingleQuotes(_transactionId);
                    this.valid = true;
                }
            }
        }
        
        public String process() {
            String output = null;
            if (this.valid && !this.processed) {
                List<Payment_Request__c> payments = [select Id, Name, Status__c, Invoice__c, Amount_Received__c, Amount_Transacted__c, Response_Code__c,
                                                     External_Transaction_ID__c, Description__c from Payment_Request__c where Tracking_ID__c = :trackingId limit 1];
                if (payments.size() > 0) {
                    Payment_Request__c payment = payments.get(0);
                    if ((payment != null) && (payment.Status__c == 'Incomplete')) {
                        if ((result == 'successful') && (responsecode == '123')) {
                            payment.Status__c = 'Successful';
                            payment.Amount_Received__c = payment.Amount_Transacted__c;
                        }
                        else if (responsecode == '456') {
                            payment.Status__c = 'Pending';
                        }
                        else if (responsecode == '789') {
                            payment.Status__c = 'Abandoned';
                        }
                        // ... etc, other status to apply
                        else {
                            payment.Status__c = 'Failed';
                        }
                        payment.Response_Code__c = responsecode;
                        payment.External_Transaction_ID__c = transactionId;
                        
                        update payment;
                        
                        this.processed = true;
                        
                        output = XYZ_Utils.getPaymentStringForRedirect(payment);
                    }
                }
            }
            return output;
        }
    }

}