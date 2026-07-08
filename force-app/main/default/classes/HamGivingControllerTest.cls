@IsTest
public with sharing class HamGivingControllerTest {
     @IsTest
     static void testIsExperienceSite(){
        
        Test.startTest();
        HamGivingController.isExperienceSite();
        Test.stopTest();
        
     }

     @IsTest
     static void testGetCommUserContactId(){
      
      Test.startTest();
      HamGivingController.getCommUserContactId(UserInfo.getUserId());
      Test.stopTest();
      
     }

     @IsTest
     static void testGetHamilonFundDesignations(){
        
        Test.startTest();
        HamGivingController.getHamilonFundDesignations();
        Test.stopTest();
        
     }

     @IsTest
     static void testGetOtherDesignations(){
        
        Test.startTest();
        HamGivingController.getOtherDesignations('foo');
        Test.stopTest();
        
     }

     @IsTest
     static void testGetPledges(){
        
        Test.startTest();
        HamGivingController.getPledges('foo');
        Test.stopTest();
        
     }
}