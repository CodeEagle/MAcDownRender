(function () {

 var seqs = document.querySelectorAll("code.language-seq");
 var i;
 for (i = 0; i < seqs.length; i++) {
     var code = seqs[i].textContent
 		var id = "x-seq-"+i;
 		seqs[i].setAttribute("id", id);
		seqs[i].textContent = "";
 		var diagram = Diagram.parse(code);
   	diagram.drawSVG(id,{theme: 'simple'});
 }
 var pres =document.querySelectorAll("pre.language-seq");
 var j;
 for (j = 0; j < pres.length; j++) {
   pres[j].className =  pres[j].className.replace
      ( /(?:^|\s)line-numbers(?!\S)/g , '' );
 }
})();
