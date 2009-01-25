jQuery(function($) {

$(".filelist a[href$='_html']").parent("li").addClass("htmldir");
$(".filelist a[href$='.pdf']").parent("li").addClass("pdf");
$(".filelist a[href$='.chm']").parent("li").addClass("chm");
$(".filelist a[href$='.zip']").parent("li").addClass("zip");

/*
$("#content a[href$='.doc'], a[href$='.txt'], a[href$='.rft']").addClass("txt");
*/
});
