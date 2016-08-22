(function () {
var flows = document.querySelectorAll("code.language-flow");
var i;
for (i = 0; i < flows.length; i++) {
    var code = flows[i].textContent;
		var id = "x-flow-"+i;
		flows[i].setAttribute("id", id);
		flows[i].textContent = "";
		var diagram = flowchart.parse(code);
  	diagram.drawSVG(id);
}

var pres =document.querySelectorAll("pre.language-flow");
var j;
for (j = 0; j < pres.length; j++) {
	pres[j].className =  pres[j].className.replace
      ( /(?:^|\s)line-numbers(?!\S)/g , '' );
}
})();
