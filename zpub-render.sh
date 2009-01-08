#!/bin/bash

# Script to render a specific revision of a document

USAGE='
$ zpub-render.sh $CUST $REV $DOC $STYLE $OUTDIR

where
 $CUST:   Basename of the customers directory in $ZPUB/
 $REV:    SVN-Revision to render
 $DOC:    Document to render (subdirectory of repository)
 $STYLE:  Style to use (subdirectory of $ZPUB/CUST/style/$STLYE
 $OUTDIR: Directory to write to (will be created)
'

# validate!:
# xmllint  --noout --xinclude  --postvalid ../duva-formgen-doku/formulargenerator.xml 

set -e

ZPUB=/opt/zpub

CUST="$1"
REV="$2"
DOC="$3"
STYLE="$4"
OUTDIR="$5"

if [ -z "$CUST" -o -z "$REV" -o -z "$DOC" -o -z "$STYLE" -o -z "OUTDIR" ]
then
  echo "Parameter list not complete."
  echo "$USAGE"
  exit 1
fi

for dir in "$ZPUB/$CUST" "$ZPUB/$CUST/style/$STYLE" "$ZPUB/$CUST/repos/source";
do
  if [ ! -d "$dir" ]
  then
    echo "$dir is not a directory."
    exit 1
  fi
done

export SP_ENCODING=utf-8

export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar
#export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar:/usr/share/java/xalan2.jar:/usr/share/java/saxon.jar:/usr/share/java/saxon-6.5.5.jar
#export CLASSPATH=$CLASSPATH:$ZPUB/tools/fop-hyph.jar:/usr/share/java/xalan2.jar:/usr/share/java/saxon.jar

function makehtmlhelp {
	outdir="$OUTDIR/htmlhelp-temp"
	
	test -d "$outdir" || mkdir -p "$outdir"
	cd "$outdir"
	xsltproc					\
		--stringparam htmlhelp.chm "$DOCNAME.chm"	\
		--stringparam htmlhelp.hpc "$DOCNAME.hpc"	\
		--stringparam htmlhelp.hhk "$DOCNAME.hhk"	\
		 $ZPUB/$CUST/style/$STYLE/htmlhelp.xsl $OUTDIR/source/$DOCNAME.xml

	mkdir -p images 
	cp -fl /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.gif images/
	cp -flr $OUTDIR/source/$DOC/images/* images/
	cp -flr $ZPUB/$CUST/style/$STYLE/htmlhelp-shared/* .
	wine 'C:\Programme\HTML Help Workshop\hhc.exe' htmlhelp.hhp || true
	test -e "$DOCNAME.chm" && find ! -name "$DOCNAME.chm" -delete
	mv "$DOCNAME.chm" ../
	cd ..
	rmdir "$outdir"
}

function makehtml {
	outdir="$OUTDIR/${DOCNAME}_html"

	test -d "$outdir"|| mkdir -p "$outdir"
	cd "$outdir"
	xsltproc $ZPUB/$CUST/style/$STYLE/htmlhelp.xsl $OUTDIR/source/$DOCNAME.xml
	
	mkdir -p images 
	cp -fl /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.gif images/
	cp -flr $OUTDIR/source/images/* images/
	cp -flr $ZPUB/$CUST/style/$STYLE/htmlhelp-shared/* .
	rm -f ../${DOCNAME}_html.zip
	zip -r ../${DOCNAME}_html.zip .
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
	outdir="$OUTDIR"
	
	test -d "$outdir"|| mkdir -p "$outdir"
	cd "$outdir"
	
	fop -xml $OUTDIR/source/$DOCNAME.xml -xsl $ZPUB/$CUST/style/$STYLE/fo.xsl -pdf $DOCNAME.pdf
	#rm $1.fo
}


test -d "$OUTDIR"  || mkdir -p "$OUTDIR"
cd "$OUTDIR"
echo $$ > zpub-render-in-progress
exec &> >(tee zpub-render.log)

test -d "source" && rm -rf "source"
echo "Exporting sources to $OUTDIR/source"
svn export -r $REV "file://$ZPUB/$CUST/repos/source/$DOC" source
cd "source"
DOCNAME=$(basename *.xml .xml)

if [ ! -r "$DOCNAME.xml" ]
then
  echo "Could not find document source ($DOCNAME)"
  exit 1
fi

#makehtmlhelp 
makehtml 
#makepdf

cd "$OUTDIR"
echo "Successfully generated output, deleting source directory"
rm -rf "$OUTDIR/source"
rm -f zpub-render-in-progress
