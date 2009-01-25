jQuery(function($) {


$(".filelist a[href$='.pdf']").addClass("pdf");
$(".filelist a[href$='.chm']").addClass("chm");
$(".filelist a[href$='.zip']").addClass("zip");

$(".filelist a[href^='mailto:']").addClass("email");

$('.filelist a').filter(function() {
    return this.hostname && this.hostname !== location.hostname;
  }).addClass("external");

/*
$("#content a[href$='.doc'], a[href$='.txt'], a[href$='.rft']").addClass("txt");
*/
});
