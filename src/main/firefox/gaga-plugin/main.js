/*
 * For how to install see:
 *
 * "https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/doc/note/firefox/firefox.txt"
 */
;(function(){ try{

    var NDEBUG = false;
    var STATUS_INIT = 1;
    var STATUS_RUNNING = 2;
    var STATUS_DONE = 3;
    var STATUS_OBSOLETE = 4;
    var NOOP = function(){};
    var LOGERR = console.error.bind(console);
    var N = null;
    var setTimeout, logErrors, LOGDBG;


    function main(){
        var app = Object.seal({
            ui: {},
            status: Object.seal({
                checklistBtn: STATUS_INIT,
                developmentBtn: STATUS_INIT,
            }),
            lastClickEpochMs: 0,
        });
        if( NDEBUG ){
            setTimeout = window.setTimeout;
            logErrors = function(app, fn){ fn(arguments.slice(2)); }
            LOGDBG = NOOP;
        }else{ /* fix broken tooling */
            setTimeout = setTimeoutWithCatch.bind(0, app);
            logErrors = logErrorsImpl.bind(N, app);
            LOGDBG = console.debug.bind(console);
        }
        document.addEventListener("DOMContentLoaded", logErrors.bind(N, onDOMContentLoaded, app));
    }


    function onDOMContentLoaded( app ){
        cleanupClutter(app);
        attachDomObserver(app);
    }


    function attachDomObserver( app ){
        new MutationObserver(onDomHasChangedSomehow.bind(N, app))
            .observe(document, { subtree:true, childList:true, attributes:true });
    }


    function onDomHasChangedSomehow( app, changes, mutationObserver ){
        var nowEpochMs = Date.now();
        if( (app.lastClickEpochMs + 2000) > nowEpochMs ){
            LOGDBG("ignore, likely triggered by user.");
            return; }
        var needsReEval = false;
        for( var change of changes ){
            if( change.target.nodeName != "BUTTON" ) continue;
            var isAriaExpanded = (change.attributeName == "aria-expanded");
            var isChildAdded = (change.addedNodes.length > 0);
            var isChildRemoved = (change.removedNodes.length > 0);
            var isChildAddedOrRemoved = isChildAdded || isChildRemoved;
            if( !isAriaExpanded && !isChildAddedOrRemoved ) continue;
            if( isAriaExpanded ){
                LOGDBG("Suspicious, isExpanded: ", change.target);
                needsReEval = true; break;
            }
            if( !isChildAddedOrRemoved ) continue;
            var isBloatyChecklistBtnStillThere = document.body.contains(getBloatyChecklistBtn(app));
            if( !isBloatyChecklistBtnStillThere ){
                LOGDBG("Suspicious, btn lost");
                needsReEval = true; break;
            }
            var isBloatyDevelopmentBtnStillThere = document.body.contains(getBloatyDevelopmentBtn(app));
            if( !isBloatyDevelopmentBtnStillThere ){
                LOGDBG("Suspicious, btn lost");
                needsReEval = true; break;
            }
        }
        if( needsReEval ){
            LOGDBG("Change detected! Eval again");
            app.ui.bloatyChecklistBtn = null;
            app.ui.bloatyDevelopmentBtn = null;
            setTimeout(cleanupClutter, 42, app);
        }
    }


    function cleanupClutter( app ){
        if( app.bloatyChecklistDone != STATUS_RUNNING ){
            app.bloatyChecklistDone = STATUS_OBSOLETE
            setTimeout(hideBloatyButton, 0, app, "checklistBtn");
        }
        if( app.bloatyDevelopmentDone != STATUS_RUNNING ){
            app.bloatyDevelopmentDone = STATUS_OBSOLETE;
            setTimeout(hideBloatyButton, 0, app, "developmentBtn");
        }
        if( app.bloatyDevelopmentDone != STATUS_RUNNING ){
            app.bloatyDevelopmentDone = STATUS_OBSOLETE;
            setTimeout(hideBloatyButton, 0, app, "bigTemplateBtn");
        }
    }


    function setLastClickTimeToNow( app ){ app.lastClickEpochMs = Date.now(); }


    function hideBloatyButton( app, btnKey ){
        if( app.status[btnKey] == STATUS_DONE ){
            LOGDBG(btnKey +" now hidden");
            return; }
        app.status[btnKey] == STATUS_RUNNING;
        var btn = getBloatyButton(app, btnKey);
        do{
            if( !btn ){ LOGDBG(btnKey +" not found. DOM maybe not yet ready?"); break; }
            var isExpanded = isAriaBtnExpanded(app, btn);
            if( isExpanded === true ){
                LOGDBG(btnKey +".click()");
                btn.click();
            }else if( isExpanded === false ){
                app.status[btnKey] = STATUS_DONE;
            }else{
                throw Error("Neither true nor false "+ typeof(isExpanded) +" "+ isExpanded);
            }
        }while(0);
        /* try later */
        setTimeout(hideBloatyButton, 16, app, btnKey);
    }


    function getBloatyButton( app, btnKey ){
        if(0){
        }else if( btnKey == "checklistBtn" ){
            var selector = "button[aria-label=Checklists]";
            var uiKey = "bloatyChecklistBtn";
        }else if( btnKey == "developmentBtn" ){
            var selector = "button[aria-label=Development]";
            var uiKey = "bloatyDevelopmentBtn";
        }else if(  btnKey == "bigTemplateBtn" ){
            var selector = "button[aria-label=BigTemplate]";
            var uiKey = "bloatyBigTemplateBtn";
        }else{
            throw Error(btnKey);
        }
        if( !app.ui[uiKey] ){
            var btn = fetchUiRefOrNull(app, document, selector);
            if( btn ){
                btn.addEventListener("mousedown", logErrors.bind(N, setLastClickTimeToNow, app));
                app.ui[uiKey] = btn;
            }
        }
        return app.ui[uiKey];
    }


    function isAriaBtnExpanded( app, btnElem ){
        var value = btnElem.getAttribute("aria-expanded");
        if( value === "true" ){
            return true;
        }else if( value === "false" ){
            return false;
        }else{
            throw Error("btn[aria-expand] is '"+ value +"'");
        }
    }


    function fetchUiRefOrNull( app, searchRoot, query ){
        var elems = searchRoot.querySelectorAll(query);
        if( elems.length > 1 ){ throw Error("Not unique: "+ query); }
        if( elems.length !== 1 ){ return null; }
        return elems[0];
    }


    function setTimeoutWithCatch( app, func, ms, a1, a2, a3, a4, a5, a6 ){
        if( typeof(app) != "object" ){ LOGERR("E_20230718192813 ", app); return; }
        if( typeof(func) != "function" ){ LOGERR("E_20230718192821", func); return; }
        if( typeof(ms) != "number" ){ LOGERR("E_20230718192830", ms); return; }
        window.setTimeout(logErrors, ms, func, a1, a2, a3, a4, a5, a6);
    }


    function logErrorsImpl( app, func, a1, a2, a3, a4, a5, a6, a7, a8, a9 ){
        try{
            func(a1, a2, a3, a4, a5, a6, a7, a8, a9);
        }catch( ex ){
            LOGERR(ex);
        }
    }


    main();

}catch(ex){console.error(ex); throw ex;}}());
