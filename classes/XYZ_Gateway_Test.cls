@isTest
public class XYZ_Gateway_Test {
    /**
     * The test runs validations for each gateway strategy. It verifies that listed supported strategies meet all the requirements.
     * It also spits useful error messages for first time configuration. It's a test driven approach to force complete implementation.
     */
    @isTest static void verifyStrategySetup() {
        Set<XYZ_Utils.PaymentMethod> myStrategies = XYZ_Gateway.supportedStrategies;
        
        System.assertEquals(false, XYZ_Gateway.supportedGatewayProfilesByStrategy.isEmpty());
        System.assertEquals(false, myStrategies.isEmpty(), 'Configuration warning: There should be at least some supported strategies.');
        
        System.assertNotEquals(null, XYZ_Gateway.enabledGatewayProfilesByReceivingEntity);
        System.assertEquals(false, XYZ_Gateway.enabledGatewayProfilesByReceivingEntity.get(XYZ_Utils.DEFAULT_RECIPIENT_ENTITY).isEmpty(),
                                    'Configuration warning: Enable at least one profile to be able to allow checkout.');
        
        Set<XYZ_Gateway_Config__mdt> currentProfiles;
        Set<String> currentProfileQualifiedApiNames = new Set<String>();
        for(XYZ_Utils.PaymentMethod strategy : myStrategies) {
            currentProfiles = XYZ_Gateway.supportedGatewayProfilesByStrategy.get(strategy);
            System.assertNotEquals(null, currentProfiles);
            System.assertEquals(false, currentProfiles.isEmpty(), 'All strategies must have a non empty supported set.');
            
            for(XYZ_Gateway_Config__mdt profile : currentProfiles) {
                System.assertEquals(profile.Payment_Method__c, strategy.name(), 'All supported profiles must match their strategies names.');
                if (profile.Enabled_Gateway__c) {
                    System.assert(XYZ_Gateway.enabledGatewayProfilesByReceivingEntity.get(profile.Receiving_Entity__c).contains(profile),
                                    'All enabled profiles must be added to list of enabled payment strategies.');
                }
                currentProfileQualifiedApiNames.add(profile.QualifiedApiName);
            }
        }

        for(Set<XYZ_Gateway_Config__mdt> profiles : XYZ_Gateway.enabledGatewayProfilesByReceivingEntity.values()) {
            for(XYZ_Gateway_Config__mdt profile : profiles) {
                System.assert(currentProfileQualifiedApiNames.contains(profile.QualifiedApiName),
                                'List of enabled gateway profiles should only contain actual profiles.');
            }
        }
    }
}