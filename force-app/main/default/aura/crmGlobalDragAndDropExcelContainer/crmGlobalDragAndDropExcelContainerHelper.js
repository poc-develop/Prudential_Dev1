/* global $A */
({
    navigateTosObjectFunction : function(){
    var urlEvent = $A.get("e.force:navigateToURL");
    urlEvent.setParams({
      "url": "/lightning/o/Case/list?filterName=__Recent"
    });
    urlEvent.fire();
    $A.get('e.force:refreshView').fire();
    }
})