/*
 * For how to install see:
 *
 * "https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/doc/note/firefox/firefox.txt"
 */
;(function(){ try{

    var NDEBUG = false;
    var N = null;
    var setTimeout;


    function main(){
        var app = Object.seal({
            ui: {},
            bloatyChecklistDone: false,
        });
        if( !NDEBUG ){ setTimeout = setTimeoutWithCatch.bind(0, app); /* fix broken tooling */ }
        document.addEventListener("DOMContentLoaded", onDOMContentLoaded.bind(N, app));
    }


    function onDOMContentLoaded( app ){
        hideBloatyChecklist(app);
        hideBloatyDevelopment(app);
    }


    function getBloatyChecklistBtn( app ){
        if( ! app.ui.bloatyChecklistBtn ){
            app.ui.bloatyChecklistBtn = fetchUiRefOrNull(app, document, 'button[aria-label="Checklists"]');
        }
        return app.ui.bloatyChecklistBtn;
    }


    function getBloatyDevelopmentBtn( app ){
        if( ! app.ui.bloatyDevelopmentBtn ){
            app.ui.bloatyDevelopmentBtn = fetchUiRefOrNull(app, document, 'button[aria-label="Development"]');
        }
        return app.ui.bloatyDevelopmentBtn;
    }


    function hideBloatyChecklist( app ){
        if( app.bloatyChecklistDone ){ console.debug("bloatyChecklistBtn now hidden"); return; }
        var btn = getBloatyChecklistBtn(app);
        do{
            if( ! btn ){ console.debug("Button not found. DOM maybe not yet ready?"); break; }
            var isExpanded = isAriaBtnExpanded(app, btn);
            console.log("isExpanded is "+ isExpanded +" ("+ typeof(isExpanded) +")");
            if( isExpanded === true ){
                console.debug("btn.click()");
                btn.click();
            }else if( isExpanded === false ){
                app.bloatyChecklistDone = true;
            }else{
                console.debug("Neither true nor false: "+ typeof(isExpanded) +" "+ isExpanded);
            }
        }while(0);
        /*try later*/
        setTimeout(hideBloatyChecklist, 16, app);
    }


    function hideBloatyDevelopment( app ){
        if( app.bloatyChecklistDone ){ console.debug("bloatyDevelopment now hidden"); return; }
        var btn = getBloatyDevelopmentBtn(app);
        do{
            if( ! btn ){ console.debug("Button not found. DOM maybe not yet ready?"); break; }
            var isExpanded = isAriaBtnExpanded(app, btn);
            if( isExpanded === true ){
                console.debug("bloatyDevelopmentBtn.click()");
                btn.click();
            }else if( isExpanded === false ){
                app.bloatyDevelopmentDone = true;
            }else{
                console.debug("Neither true nor false: "+ typeof(isExpanded) +" "+ isExpanded);
            }
        }while(0);
        /*try later*/
        setTimeout(hideBloatyDevelopment, 16, app);
    }


    function isAriaBtnExpanded( app, btnElem ){
        var value = btnElem.getAttribute("aria-expanded");
        if( value === "true" ){
            return true;
        }else if( value === "false" ){
            return false;
        }else{
            throw Error("btn.attrib[aria-expand] is '"+ value +"'");
        }
    }


    function fetchUiRefOrNull( app, searchRoot, query ){
        var elems = searchRoot.querySelectorAll(query);
        if( elems.length > 1 ){ console.error(Error("Not unique: "+ query)); return null; }
        if( elems.length !== 1 ){ return null; }
        return elems[0];
    }


    function setTimeoutWithCatch( app, func, ms, a1, a2, a3, a4, a5, a6 ){
        if( NDEBUG ){ console.error("Why is this code in use?"); return; }
        if( typeof(app) != "object" ){ console.error("E_20230718192813 ", app); return; }
        if( typeof(func) != "function" ){ console.error("E_20230718192821", func); return; }
        if( typeof(ms) != "number" ){ console.error("E_20230718192830", ms); return; }
        var oldStack = Error();
        window.setTimeout(function(){
            try{
                func(a1, a2, a3, a4, a5, a6);
            }catch( ex ){
                console.error(ex, oldStack); throw ex;
            }
        }, ms);
    }


    main();

}catch(ex){console.error(ex); throw ex;}}());
