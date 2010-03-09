xsltproc style/fo.xsl simple.xml > simple.fo &&  fop -fo simple.fo -pdf simple.pdf
xsltproc style/html.xsl simple.xml
