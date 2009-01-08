#!/bin/bash

# validate!:
# xmllint  --noout --xinclude  --postvalid ../duva-formgen-doku/formulargenerator.xml 

set -e

ZPUB=/opt/zpub

CUST=$ZPUB/duva

export SP_ENCODING=utf-8

export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar
#export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar:/usr/share/java/xalan2.jar:/usr/share/java/saxon.jar:/usr/share/java/saxon-6.5.5.jar
#export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar:/usr/share/java/xalan2.jar:/usr/share/java/saxon.jar

# These variables are filled by the main
# loop, and then used by the functions
# $CUST/source/$DOC/$DOCNAME.xml
# $CUST/style/$STYLE/format.xsl
DOC=
DOCNAME=
STYLE=handbuch # only one so far

function makehtmlhelp {
	outdir="$CUST/output/$DOC/htmlhelp-temp"
	
	test -d "$outdir" || mkdir -p "$outdir"
	cd "$outdir"
	xsltproc					\
		--stringparam htmlhelp.chm "$DOCNAME.chm"	\
		--stringparam htmlhelp.hpc "$DOCNAME.hpc"	\
		--stringparam htmlhelp.hhk "$DOCNAME.hhk"	\
		 $CUST/style/$STYLE/htmlhelp.xsl $CUST/source/$DOC/$DOCNAME.xml

	mkdir -p images 
	cp -r /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.gif images/
	cp -r $CUST/source/$DOC/images/* images/
	cp -r $CUST/style/$STYLE/htmlhelp-shared/* .
	wine 'C:\Programme\HTML Help Workshop\hhc.exe' htmlhelp.hhp || true
	test -e "$DOCNAME.chm" && find ! -name "$DOCNAME.chm" -delete
	mv "$DOCNAME.chm" ../
	cd ..
	rmdir "$outdir"
}

function makehtml {
	outdir="$CUST/output/$DOC/$DOCNAME_html"

	test -d "$outdir"|| mkdir -p "$outdir"
	cd "$outdir"
	xsltproc $CUST/style/$STYLE/htmlhelp.xsl $CUST/source/$DOC/$DOCNAME.xml
	
	mkdir -p images 
	cp -v /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.gif images/
	cp -vr $CUST/source/$DOC/images/* images/
	cp -vr $CUST/style/$STYLE//htmlhelp-shared/* .
	rm -f ../$DOCNAME_html.zip
	zip -r ../$DOCNAME_html.zip .
}


#function makertf {
#	test -d output/rtf || mkdir output/rtf
#	rm -f output/rtf/*
##	test -d images |  mv images images.DISABLED
#	xsltproc $DUVASHARED/duva-shared-rtf.xsl $1.xml > output/rtf/$1.fo
#	fop output/rtf/$1.fo -rtf output/rtf/$1.rtf
##	mv images.DISABLED images
#}



function makepdf {
	outdir="$CUST/output/$DOC"
	
	test -d "$outdir"|| mkdir -p "$outdir"
	cd "$outdir"
	
	fop -xml $CUST/source/$DOC/$DOCNAME.xml -xsl $CUST/style/$STYLE/fo.xsl -pdf $DOCNAME.pdf
	#rm $1.fo
}



for docpath in $CUST/source/*
do
	if ! [ -d "$docpath" ]; then echo "Skipping non-directory $docpath"; fi
	
	cd "$docpath"
	DOC=$(basename $docpath)
	DOCNAME=$(basename *.xml .xml)

	echo "Running zpub for $DOC/$DOCNAME.xml"
	echo "(Customer $CUST, Style $STYLE)"
	echo

#	makehtmlhelp 
#	makehtml 
	makepdf
done
