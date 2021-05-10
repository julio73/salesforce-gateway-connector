# Salesforce Gateway Connector
Scaffolding for building payment gateway connectors within salesforce.

The repo contains three main classes. They illustrate a process for implementing payment gateway connections within Salesforce. The native approach offers more security and tighter integration to Salesforce features (eg: testing, custom metadata, etc.). All classes use `XYZ` as the namespace. The implementation use ApexClass API version `42.0`.

1 - Interface
--
First, an interface holds the underlying principles of a gateway. For instance:
   1. Ability to retrieve a payment profile for processing
   2. Ability to process a payment request at checkout
   3. Ability to process a response, if any, returned after checkout
Points 2. and 3. apply to several classes of gateways that use page hosted URLs or direct transaction URLs for payment processing.


See [XYZ_Payment_Interface](classes/XYZ_Payment_Interface.cls).

2 - Abstract class
--
An abstract class uses the principles from the interface for a given service (eg. a payment platform) and acts as an inspector for gateway connections to the service. This class registers each gateway within strategies corresponding to external configurations stored as custom metadata.
This allows administrators to configure the gateways by editing custom metadata entries. In case of faulty or missing configurations, the associated test class returns failures to highlight misconfigurations.


See [XYZ_Gateway](classes/XYZ_Gateway.cls) and [XYZ_Gateway_Test](classes/XYZ_Gateway_Test.cls).

3 - Extending Class
--
Each extending gateway class abides by the principle of the interface. The purpose of the gateway is to link user actions to gateway processes. For instance, if a payment request demands a PayPal transaction, the first matching strategy with an implementation for PayPal processes the transaction. When a URL comes back to Salesforce with transaction details, the first matching strategy capable of processing the response updates the payment request.


See [XYZ_Gateway_OTHER](classes/XYZ_Gateway_OTHER.cls).

Notes
--
- A utility class (`XYZ_Utils`) can hold static values or methods shared across the gateways.
- Given a controller with an instance of `XYZ_Payment_Interface` named `myPaymentInterface`, one can successfully:
  - Initiate a payment request and receive a response with `myPaymentInterface.processPayment(newPaymentRequest)` where `newPaymentRequest` is a saved `Payment_Request__c` object with the necessary fields filled.
  - Process a response returned from a gateway on the current page with `myPaymentInterface.processResponseIfSupported(ApexPages.currentPage())`, assuming the strategy for the response exists and is properly configured.
