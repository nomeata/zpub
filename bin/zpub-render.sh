#!/bin/bash

# Copyright 2009 Joachim Breitner
# 
# Licensed under the EUPL, Version 1.1 or – as soon they will be approved
# by the European Commission – subsequent versions of the EUPL (the
# "Licence"); you may not use this work except in compliance with the
# Licence.
# You may obtain a copy of the Licence at:
# 
# http://ec.europa.eu/idabc/eupl
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the Licence is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# Licence for the specific language governing permissions and limitations
# under the Licence.


# Script to render a specific revision of a document

USAGE='
$ zpub-render.sh $CUST $REV $DOC $STYLE

where
 $CUST:   Basename of the customers directory in $ZPUB_INSTANCES/
 $REV:    SVN-Revision to render
 $DOC:    Document to render (subdirectory of repository)
 $STYLE:  Style to use (subdirectory of $ZPUB_INSTANCES/CUST/style/$STLYE
'

# validate!:
# xmllint  --noout --xinclude  --postvalid xml-file.xml

set -e

ZPUB_PATHS="${ZPUB_PATHS:=path-files/zpub-paths-tmp}"

if ! [ -r "$ZPUB_PATHS" ]
then
  echo "Cannot read file $ZPUB_PATHS in variable \$ZPUB_PATHS"
  exit 1
fi

. $ZPUB_PATHS

CUST="$1"
REV="$2"
DOC="$3"
STYLE="$4"
OUTDIR="$ZPUB_INSTANCES/$CUST/output/$DOC/archive/$REV/$STYLE"

if [ -z "$CUST" -o -z "$REV" -o -z "$DOC" -o -z "$STYLE" ]
then
  echo "Parameter list not complete."
  echo "$USAGE"
  exit 1
fi

for dir in "$ZPUB_INSTANCES/$CUST" "$ZPUB_INSTANCES/$CUST/style/$STYLE" "$ZPUB_INSTANCES/$CUST/repos/source";
do
  if [ ! -d "$dir" ]
  then
    echo "$dir is not a directory."
    exit 1
  fi
done

export SP_ENCODING=utf-8

export FOP_HYPHENATION_PATH=$ZPUB_SHARED/tools/fop-hyph.jar

function makehtmlhelp {
	outdir="$OUTDIR/htmlhelp-temp"
	
	test -d "$outdir" || mkdir -p "$outdir"
	cd "$outdir"
	xsltproc					\
		--stringparam htmlhelp.chm "$DOCNAME.chm"	\
		--stringparam htmlhelp.hpc "$DOCNAME.hpc"	\
		--stringparam htmlhelp.hhk "$DOCNAME.hhk"	\
		 ../style/htmlhelp.xsl ../source/"$DOCNAME.xml"

	mkdir -p images
	cp -fl /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.gif images/
	test -d ../style/htmlhelp-shared && cp -flr ../style/htmlhelp-shared/* .
	test -d ../source/images/ && rsync -r ../source/images/ images/
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
	xsltproc ../style/html.xsl ../source/"$DOCNAME.xml"
	
	mkdir -p images style
	cp -fl /usr/share/xml/docbook/stylesheet/nwalsh/images/callouts/*.png style/
	test -d ../style/html-shared && cp -flr ../style/html-shared/* .
	test -d ../source/images/ && rsync -r ../source/images/ images/
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
	
	xsltproc style/fo.xsl source/"$DOCNAME.xml" > source/"$DOCNAME.fo"
	fopopts=""
	test -e "style/fop.xconf" && fopopts="-c style/fop.xconf"
	fop $fopopts -fo source/"$DOCNAME.fo" -pdf "$DOCNAME.pdf"
	rm source/"$DOCNAME.fo"

	# fop uses xalan, xalan has bugs
	#fop -xml source/"$DOCNAME.xml" -xsl style/fo.xsl -pdf "$DOCNAME.pdf"
}


test -d "$OUTDIR"  || mkdir -p "$OUTDIR"
cd "$OUTDIR"
echo $$ > zpub-render-in-progress
exec &> >(tee zpub-render.log)


test -L "style" && rm -f "style"
ln -s $ZPUB_INSTANCES/$CUST/style/$STYLE style

test -d "source" && rm -rf "source"
echo "Exporting sources to $OUTDIR/source"
svn export -r $REV "file://$ZPUB_INSTANCES/$CUST/repos/source/$DOC" source
cd "source"
DOCNAME="$(basename *.xml .xml)"

if [ ! -r "$DOCNAME.xml" ]
then
  echo "Could not find document source ($DOCNAME)"
  exit 1
fi

makehtmlhelp 
makehtml 
makepdf

cd "$OUTDIR"
echo "Successfully generated output, deleting source directory"
rm -rf "$OUTDIR/source"
rm -f  "$OUTDIR/style"
rm -f zpub-render-in-progress
