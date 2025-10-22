({
    doInit : function(component) {
        
        component.set('v.isOpen', true);
        component.set("v.title", 'Import Call List');
        
        var flow = component.find('flow');
        flow.startFlow('Data_Ingestion_Job_Import_Call_List');
    },
 
    closeModal : function(component, event, helper) {
        component.set("v.isOpen", false);
        var workspaceAPI = component.find("workspace");
        workspaceAPI.getFocusedTabInfo().then(function(response) {
            var focusedTabId = response.tabId;
            workspaceAPI.closeTab({tabId: focusedTabId});
        })
        .catch(function(error) {
            console.log(error);
        });
        helper.navigateTosObjectFunction();
    },

    closeModalOnFinish : function(component, event, helper) {
        if(event.getParam('status') === "FINISHED") {
            component.set("v.isOpen", false);
            var workspaceAPI = component.find("workspace");
            workspaceAPI.getFocusedTabInfo().then(function(response) {
                var focusedTabId = response.tabId;
                workspaceAPI.closeTab({tabId: focusedTabId});
            })
            .catch(function(error) {
                console.log(error);
            });
            helper.navigateTosObjectFunction();
        }
    }
})