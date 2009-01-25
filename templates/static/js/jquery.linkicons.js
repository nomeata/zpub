jQuery(function($) {

$(".filelist a[href$='_html']").parent("li").addClass("htmldir");
$(".filelist a[href$='.pdf']").addClass("pdf");
$(".filelist a[href$='.chm']").addClass("chm");
$(".filelist a[href$='.zip']").addClass("zip");

/*
$("#content a[href$='.doc'], a[href$='.txt'], a[href$='.rft']").addClass("txt");
*/
});
