/*
 * For how to install see:
 *
 * "https://git.hiddenalpha.ch/UnspecifiedGarbage.git/tree/doc/note/firefox/firefox.txt"
 */
;(function(){

    function main(){
        console.log("Hi, I'm a nonsense example plugin");
        enableBlinkingBorder();
    }

    function enableBlinkingBorder(){
        setBorderOn();
        setTimeout(function(){
            setBorderOff();
            setTimeout(enableBlinkingBorder, 500);
        }, 500);
    }

    function setBorderOn(){
        document.body.style.border = "5px solid red";
    }

    function setBorderOff(){
        document.body.style.border = "5px dotted red";
    }

    main();
}());
