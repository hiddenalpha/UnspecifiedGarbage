/*
 * [How to install](UnspecifiedGarbage/doc/note/firefox/firefox.txt)
 */
;(function(){ try{

    var NDEBUG = false;
    var STATUS_INIT = 1;
    var NOOP = function(){};
    var LOGERR = console.error.bind(console);
    var N = null;
    var setTimeout, logErrors, LOGDBG;


    function main(){
        var app = Object.seal({
            ui: {},
            lastClickEpochMs: 0,
            wantChecklistExpanded: false,
            wantDevelopmentExpanaded: false,
            wantBigTemplateExpanded: false,
        });
        if( NDEBUG ){
            setTimeout = window.setTimeout;
            logErrors = function(app, fn){ fn(arguments.slice(2)); }
            LOGDBG = NOOP;
        }else{ /* fix broken tooling */
            setTimeout = setTimeoutWithCatch.bind(0, app);
            logErrors = logErrorsImpl.bind(N, app);
            LOGDBG = console.debug.bind(console, "[gaga-plugin]");
        }
        document.addEventListener("DOMContentLoaded", logErrors.bind(N, onDOMContentLoaded, app));
        scheduleNextStateCheck(app);
        LOGDBG("gaga-plugin initialized");
    }


    function onDOMContentLoaded( app ){
        LOGDBG("onDOMContentLoaded()");
        attachDomObserver(app);
    }


    function attachDomObserver( app ){
        new MutationObserver(onDomHasChangedSomehow.bind(N, app))
            .observe(document, { subtree:true, childList:true, attributes:true });
    }


    function scheduleNextStateCheck( app ){
        //LOGDBG("scheduleNextStateCheck()");
        if( app.stateCheckTimer ){
            LOGDBG("Why is stateCheckTimer not zero?", app.stateCheckTimer);
        }
        app.stateCheckTimer = setTimeout(function(){
            app.stateCheckTimer = null;
            scheduleNextStateCheck(app);
            performStateCheck(app);
        }, 42);
    }


    function performStateCheck( app ){
        var buttons = [ "checklistBtn", "developmentBtn", "bigTemplateBtn" ];
        var wantKey = [ "wantChecklistExpanded", "wantDevelopmentExpanaded", "wantBigTemplateExpanded" ];
        for( var i = 0 ; i < buttons.length ; ++i ){
            var btnKey = buttons[i];
            var btnElem = getBloatyButton(app, btnKey);
            if( !btnElem ) continue;
            var isExpanded = isAriaBtnExpanded(app, btnElem)
            var wantExpanded = app[wantKey[i]];
            //LOGDBG(btnKey +" expanded is", isExpanded);
            if( isExpanded && !wantExpanded ){
                collapseAriaBtn(app, btnElem);
            }
        }
    }


    function onDomHasChangedSomehow( app, changes, mutationObserver ){
        var nowEpochMs = Date.now();
        LOGDBG("DOM Change detected!");
        /*refresh dom refs so check will work on correct elems*/
        Object.keys(app.ui).forEach(function( key ){
            app.ui[key] = null;
        });
    }


    function onBloatyChecklistBtnMousedown( app ){
        app.wantChecklistExpanded = !app.wantChecklistExpanded;
    }


    function onBloatyDevelopmentBtnMousedown( app ){
        app.wantDevelopmentExpanaded = !app.wantDevelopmentExpanaded;
    }


    function onBloatyBigTemplateBtnMousedown( app ){
        app.wantBigTemplateExpanded = !app.wantBigTemplateExpanded;
    }


    function getBloatyButton( app, btnKey ){
        if(0){
        }else if( btnKey == "checklistBtn" ){
            var selector = "button[aria-label=Checklists]";
            var uiKey = "bloatyChecklistBtn";
            var onMousedown = onBloatyChecklistBtnMousedown;
        }else if( btnKey == "developmentBtn" ){
            var selector = "button[aria-label=Development]";
            var uiKey = "bloatyDevelopmentBtn";
            var onMousedown = onBloatyDevelopmentBtnMousedown;
        }else if(  btnKey == "bigTemplateBtn" ){
            var selector = "button[aria-label=BigTemplate]";
            var uiKey = "bloatyBigTemplateBtn";
            var onMousedown = onBloatyBigTemplateBtnMousedown;
        }else{
            throw Error(btnKey);
        }
        if( !app.ui[uiKey] ){
            var btn = fetchUiRefOrNull(app, document, selector);
            if( btn ){
                btn.addEventListener("mousedown", logErrors.bind(N, onMousedown, app));
                app.ui[uiKey] = btn;
            }
        }
        return app.ui[uiKey];
    }


    function collapseAriaBtn( app, btnElem ){
        do{
            var isExpanded = isAriaBtnExpanded(app, btnElem);
            if( isExpanded === true ){
                LOGDBG("click()");
                btnElem.click();
            }else if( isExpanded === false ){
                break;
            }else{
                throw Error("Neither true nor false "+ typeof(isExpanded) +" "+ isExpanded);
            }
        }while(0);
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
