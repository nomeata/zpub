#!/bin/bash

#
# General test runner functions
#

cmds=0
tests=0

function run () {
	let cmds++ || true
	printf "%q " "$@"
	echo
	"$@"
}

function failureExGot () {
	let tests++ || true
	echo "Expected: $1"
	echo "Got:      $2"
	exit 1
}

function assertOutput () {
	let tests++ || true
	echo "Checking output of $1"
	OUTPUT="$( $1 )"
	if ! test "$OUTPUT" = "$2"
	then
		failureExGot "$2" "$OUTPUT"
	fi
}

function assertOutputContains () {
	let tests++ || true
	echo "Checking output of $1"
	OUTPUT="$( $1 )"
	if ! fgrep -q "$2" <<__END__
$OUTPUT
__END__
	then
		echo "Did not find expected output $2"
		echo "Output was:"
		echo "$OUTPUT"
		exit 1;
	fi
}

function assertOutputContainsNot () {
	let tests++ || true
	echo "Checking output of $1"
	OUTPUT="$( $1 )"
	if fgrep -q "$2" <<__END__
$OUTPUT
__END__
	then
		echo "Found unwanted output $2"
		echo "Output was:"
		echo "$OUTPUT"
		exit 1;
	fi
}

function assertEmpty () {
	let tests++ || true
	echo "Ensuring $1 is empty"
	if [ -n "$(ls "$1")" ]
	then
		echo "Directory $1 is not empty!"
		ls "$1"
		exit 1;
	fi
}

function assertNotEmpty () {
	let tests++ || true
	echo "Ensuring $1 is empty"
	if [ -z "$(ls "$1")" ]
	then
		echo "Directory $1 is empty!"
		exit 1;
	fi
}

#
#  zpub-Specific functions
#

function web () {
	QUERY_STRING="$1" REMOTE_USER=tester REQUEST_METHOD=GET $ZPUB/bin/zpub-cgi.pl
}
function web_admin () {
	QUERY_STRING="$1" REMOTE_USER=admin REQUEST_METHOD=GET $ZPUB/bin/zpub-cgi.pl
}
function epub_dump () {
	acat -F zip "$1"  OEBPS/index.html|lynx -dump -stdin
}

function runSpooler () {
	run $ZPUB/bin/zpub-spooler.sh
	assertEmpty $ZPUB/spool/todo
	assertEmpty $ZPUB/spool/fail
	assertEmpty $ZPUB/spool/wip
}

set -eu
# set -x

export ZPUB_TEST=yes
ZPUB=/tmp/zpub

cd "$(dirname $0)/.."

run rm -rf $ZPUB

echo Installing zpub
run ./install.sh path-files/zpub-paths-test
echo Creating instance
run $ZPUB/bin/zpub-create-instance.sh test 'Test instance' test.zpub.de

echo -e "html\npdf\nhtmlhelp\nepub" > /tmp/zpub/test/conf/formats

echo Installing documentation
run $ZPUB/bin/zpub-update-docs.sh test
runSpooler

echo Checking that sensible things have been built
assertOutput "ls $ZPUB/test/output/zpub-Redakteurhandbuch/archive/" 1
assertOutput "readlink $ZPUB/test/output/zpub-Redakteurhandbuch/latest/plain" \
	$ZPUB/test/output/zpub-Redakteurhandbuch/archive/1/plain 
assertOutput "ls $ZPUB/test/output/zpub-Technik/archive/" 1
assertOutput "readlink $ZPUB/test/output/zpub-Technik/latest/plain" \
      	$ZPUB/test/output/zpub-Technik/archive/1/plain
assertOutputContains \
	"pdftotext $ZPUB/test/output/zpub-Technik/latest/plain/zpub-Technik.pdf  -" \
	"Zentrales Publikationssystem"

echo Checking the web page
assertOutputContains 'web cust=test' '/zpub-Redakteurhandbuch/'
assertOutputContains 'web cust=test' '/zpub-Technik/'
assertOutputContains 'web cust=test&doc=zpub-Technik' "PDF-Datei"
assertOutputContains 'web cust=test&doc=zpub-Technik' "Layout plain"
assertOutputContains 'web cust=test&doc=zpub-Technik' "Es wurde bisher keine Revision freigegeben."
assertOutput "cat $ZPUB/test/cache/documents" "$(echo zpub-Redakteurhandbuch; echo zpub-Technik)"

echo "Removing one document"
run svn rm file://$ZPUB/test/repos/source/zpub-Redakteurhandbuch/ -m 'Removing Redakteurhandbuch'
runSpooler
assertOutputContainsNot 'web cust=test' '/zpub-Redakteurhandbuch/'
assertOutputContains    'web cust=test' '/zpub-Technik/'
assertOutput "ls $ZPUB/test/output/zpub-Redakteurhandbuch/archive/" 1
assertOutput "ls $ZPUB/test/output/zpub-Technik/archive/" 1
assertOutput "cat $ZPUB/test/cache/documents" "$(echo zpub-Technik)"

echo "Creating checkout"
export CO=$ZPUB/test/co
run svn co file://$ZPUB/test/repos/source $CO


echo "Importing new document"
run rsync -ri tests/testdoc1/ $CO/Testdokument/
run svn add $CO/Testdokument/
run svn commit -m 'Import 1' $CO
runSpooler
assertOutputContains 'web cust=test' '/Testdokument/'
assertOutputContains 'web cust=test&doc=Testdokument' "Import 1"
assertOutput "ls $ZPUB/test/output/Testdokument/archive/" 3
assertOutput "ls $ZPUB/test/output/zpub-Redakteurhandbuch/archive/" 1
assertOutput "ls $ZPUB/test/output/zpub-Technik/archive/" 1
assertOutput "readlink $ZPUB/test/output/Testdokument/latest/plain" \
	$ZPUB/test/output/Testdokument/archive/3/plain
assertOutput "cat $ZPUB/test/cache/documents" "$(echo Testdokument;echo zpub-Technik)"

echo "Changing document"
run rsync -ri tests/testdoc2/ $CO/Testdokument/
run svn commit -m 'Import 2' $CO
runSpooler
assertOutputContains 'web cust=test' '/Testdokument/'
assertOutputContains 'web cust=test&doc=Testdokument' "Import 2"
assertOutput "ls $ZPUB/test/output/Testdokument/archive/" "$(echo 3; echo 4)"
assertOutput "ls $ZPUB/test/output/zpub-Redakteurhandbuch/archive/" 1
assertOutput "ls $ZPUB/test/output/zpub-Technik/archive/" 1
assertOutput "readlink $ZPUB/test/output/Testdokument/latest/plain" \
	$ZPUB/test/output/Testdokument/archive/4/plain

echo "Manually triggering rebuild of version 3"
echo -e 'test\n3\nTestdokument\nplain\n' > $ZPUB/spool/todo/todo
runSpooler
assertOutput "ls $ZPUB/test/output/Testdokument/archive/" "$(echo 3; echo 4)"
assertOutput "readlink $ZPUB/test/output/Testdokument/latest/plain" \
	$ZPUB/test/output/Testdokument/archive/4/plain

echo "Verifying that releasing is only possible for the admin"
echo admin > $ZPUB/test/conf/admins
assertOutputContainsNot "web cust=test&doc=Testdokument&archive=" '"/static/icons/stock_mark.png"'
assertOutputContainsNot "web cust=test&doc=Testdokument" 'Diese Version Freigeben'
assertOutputContains "web_admin cust=test&doc=Testdokument" 'Diese Version Freigeben'
assertOutputContainsNot "web cust=test&doc=Testdokument&archive=" '<input type="submit" name="approve" value="Freigeben"/>'
assertOutputContains "web_admin cust=test&doc=Testdokument&archive=" '<input type="submit" name="approve" value="Freigeben"/>'


ln -s plain $ZPUB/test/style/plain_final
echo plain_final > $ZPUB/test/conf/final_style
echo "Releasing version 3 of the Testdokument"
echo -n revn=3\&approve=Freigeben | CONTENT_LENGTH=100 QUERY_STRING=cust=test\&doc=Testdokument\&archive= REMOTE_USER=admin REQUEST_METHOD=POST $ZPUB/bin/zpub-cgi.pl
assertNotEmpty $ZPUB/spool/todo
runSpooler
assertNotEmpty $ZPUB/test/output/Testdokument/archive/3/plain_final/
assertOutputContains "web_admin cust=test&doc=Testdokument&archive=" '"/static/icons/stock_mark.png"'
assertOutputContains "web cust=test&doc=Testdokument" 'Diese Revision ist neuer als die letzte'
assertOutputContainsNot "web cust=test&doc=Testdokument" 'Diese Version Freigeben'
assertOutputContains "web_admin cust=test&doc=Testdokument" 'Diese Version Freigeben'
assertOutput "readlink $ZPUB/test/output/Testdokument/latest/plain" \
	$ZPUB/test/output/Testdokument/archive/4/plain
assertOutput "readlink $ZPUB/test/output/Testdokument/latest/plain_final" \
	$ZPUB/test/output/Testdokument/archive/3/plain_final

echo "Adding a file to the top level directory does not do anything."
echo Foo > $CO/TopLevelFile.xml
run svn add $CO/TopLevelFile.xml
run svn commit -m 'Added top level file' $CO/TopLevelFile.xml
assertEmpty $ZPUB/spool/todo
assertEmpty $ZPUB/spool/fail
assertEmpty $ZPUB/spool/wip
assertOutputContainsNot "cat $ZPUB/test/cache/documents" 'TopLevelFile'

echo "Adding a document with XIncludes"
run rsync -ri tests/testdoc3/ $CO/Testdokument/
run rsync -ri tests/common3/ $CO/common/
svn add $CO/Testdokument --force
svn add $CO/common --force
svn ci $CO -m 'Adding document with XIncludes'
runSpooler
assertOutputContainsNot "cat $ZPUB/test/cache/documents" 'common'
assertOutputContains \
	"pdftotext $ZPUB/test/output/Testdokument/latest/plain/Testdokument.pdf  -" \
	"Sektion 1"
assertOutputContains \
	"pdftotext $ZPUB/test/output/Testdokument/latest/plain/Testdokument.pdf  -" \
	"Per xinclude"
assertOutputContains \
	"pdftotext $ZPUB/test/output/Testdokument/latest/plain/Testdokument.pdf  -" \
	"Also per xinclude"
assertOutputContains \
	"epub_dump $ZPUB/test/output/Testdokument/latest/plain/Testdokument.epub" \
	"Sektion 1"
assertOutputContains \
	"epub_dump $ZPUB/test/output/Testdokument/latest/plain/Testdokument.epub" \
	"Per xinclude"
assertOutputContains \
	"epub_dump $ZPUB/test/output/Testdokument/latest/plain/Testdokument.epub" \
	"Also per xinclude"
assertOutputContains \
	"cat $ZPUB/test/cache/deps/Testdokument" \
	"commonsection.xml"


echo "All tests passed successfully!"
echo "Ran $cmds commands and checked $tests tests."
