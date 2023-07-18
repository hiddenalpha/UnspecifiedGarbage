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
    var N = null;
    var setTimeout, logErrors;


    function main(){
        var app = Object.seal({
            ui: {},
            bloatyChecklistDone: STATUS_INIT,
            bloatyDevelopmentDone: STATUS_INIT,
            lastClickEpochMs: 0,
        });
        if( NDEBUG ){
            setTimeout = window.setTimeout;
            logErrors = function(app, fn){ fn(arguments.slice(2)); }
        }else{ /* fix broken tooling */
            setTimeout = setTimeoutWithCatch.bind(0, app);
            logErrors = logErrorsImpl.bind(N, app);
        }
        document.addEventListener("DOMContentLoaded", logErrors.bind(N, onDOMContentLoaded, app));
    }


    function onDOMContentLoaded( app ){
        cleanupClutter(app);
        tryStuffWithObserver(app);
    }


    function tryStuffWithObserver( app ){
        var elem = getBloatyChecklistBtn(app);
        if( !elem ){ throw Error("whops"); }
        new MutationObserver(onFooHasChanged.bind(N, app))
            .observe(document, { subtree:true, childList:true, attributes:true, characterData:true });
    }


    function onFooHasChanged( app, changes, mutationObserver ){
        var nowEpochMs = Date.now();
        if( (app.lastClickEpochMs + 2000) > nowEpochMs ){ console.debug("ignore, likely was triggered by user."); return; }
        var needsReEval = false;
        for( var change of changes ){
            var isAriaExpanded = (change.attributeName == "aria-expanded");
            var isChildAdded = (change.addedNodes.length > 0);
            var isChildRemoved = (change.removedNodes.length > 0);
            var isChildAddedOrRemoved = isChildAdded || isChildRemoved;
            if( !isAriaExpanded && !isChildAddedOrRemoved ) continue;
            var isButton = (change.target.nodeName == "BUTTON");
            if( !isButton ) continue;
            if( isAriaExpanded ){
                console.debug("Suspicious, isExpanded: ", change.target);
                needsReEval = true; break;
            }
            if( !isChildAddedOrRemoved ) continue;
            var isBloatyChecklistBtnStillThere = document.body.contains(getBloatyChecklistBtn(app));
            if( !isBloatyChecklistBtnStillThere ){
                console.debug("Suspicious, btn lost: ");
                needsReEval = true; break;
            }
            var isBloatyDevelopmentBtnStillThere = document.body.contains(getBloatyDevelopmentBtn(app));
            if( !isBloatyDevelopmentBtnStillThere ){
                console.debug("Suspicious, btn lost: ");
                needsReEval = true; break;
            }
        }
        if( needsReEval ){
            console.debug("Change detected! Eval again");
            app.ui.bloatyChecklistBtn = null;
            app.ui.bloatyDevelopmentBtn = null;
            setTimeout(cleanupClutter, 42, app);
        //}else{
        //    console.log("Changes seen, but nothing suspicious.");
        }
    }


    function cleanupClutter( app ){
        if( app.bloatyChecklistDone != STATUS_RUNNING ){
            app.bloatyChecklistDone = STATUS_OBSOLETE
            setTimeout(hideBloatyChecklist, 0, app);
        }
        if( app.bloatyDevelopmentDone != STATUS_RUNNING ){
            app.bloatyDevelopmentDone = STATUS_OBSOLETE;
            setTimeout(hideBloatyDevelopment, 0, app);
        }
    }


    function getBloatyChecklistBtn( app ){
        if( ! app.ui.bloatyChecklistBtn ){
            var btn = app.ui.bloatyChecklistBtn = fetchUiRefOrNull(app, document, 'button[aria-label="Checklists"]');
            btn.addEventListener("mousedown", logErrors.bind(N, function(app){app.lastClickEpochMs = Date.now();}, app));
        }
        return app.ui.bloatyChecklistBtn;
    }


    function getBloatyDevelopmentBtn( app ){
        if( ! app.ui.bloatyDevelopmentBtn ){
            var btn = app.ui.bloatyDevelopmentBtn = fetchUiRefOrNull(app, document, 'button[aria-label="Development"]');
            btn.addEventListener("mousedown", logErrors.bind(N, function(app){app.lastClickEpochMs = Date.now();}, app));
        }
        return app.ui.bloatyDevelopmentBtn;
    }


    function hideBloatyChecklist( app ){
        if( app.bloatyChecklistDone == STATUS_DONE ){ console.debug("bloatyChecklistBtn now hidden", app.ui.bloatyChecklistBtn); return; }
        app.bloatyChecklistDone == STATUS_RUNNING;
        var btn = getBloatyChecklistBtn(app);
        do{
            if( ! btn ){ console.debug("Button not found. DOM maybe not yet ready?"); break; }
            var isExpanded = isAriaBtnExpanded(app, btn);
            if( isExpanded === true ){
                console.debug("bloatyChecklistBtn.click()");
                btn.click();
            }else if( isExpanded === false ){
                app.bloatyChecklistDone = STATUS_DONE;
            }else{
                console.debug("Neither true nor false: "+ typeof(isExpanded) +" "+ isExpanded);
            }
        }while(0);
        /*try later*/
        setTimeout(hideBloatyChecklist, 16, app);
    }


    function hideBloatyDevelopment( app ){
        if( app.bloatyDevelopmentDone == STATUS_DONE ){ console.debug("bloatyDevelopmentBtn now hidden", app.ui.bloatyDevelopmentBtn); return; }
        app.bloatyDevelopmentDone == STATUS_RUNNING;
        var btn = getBloatyDevelopmentBtn(app);
        do{
            if( ! btn ){ console.debug("Button not found. DOM maybe not yet ready?"); break; }
            var isExpanded = isAriaBtnExpanded(app, btn);
            if( isExpanded === true ){
                console.debug("bloatyDevelopmentBtn.click()");
                btn.click();
            }else if( isExpanded === false ){
                app.bloatyDevelopmentDone = STATUS_DONE;
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
        window.setTimeout(logErrors, ms, func, a1, a2, a3, a4, a5, a6);
        //window.setTimeout(function(){
        //    try{
        //        func(a1, a2, a3, a4, a5, a6);
        //    }catch( ex ){
        //        console.error(ex, oldStack); throw ex;
        //    }
        //}, ms);
    }


    function logErrorsImpl( app, func, a1, a2, a3, a4, a5, a6, a7, a8, a9 ){
        try{
            func(a1, a2, a3, a4, a5, a6, a7, a8, a9);
        }catch( ex ){
            console.error(ex);
        }
    }


    main();

}catch(ex){console.error(ex); throw ex;}}());
