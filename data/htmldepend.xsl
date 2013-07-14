<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet
  version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<!--
htmldepend.xsl - Find images that an HTML document refers to/depends on.

Based on xmldepend.xsl

Dependencies are defined as:
- Files named by the src attribute of any image element.

Who-to-blame:
Paul DuBois
paul@kitebird.com
2005-08-16

Change history:
2005-08-16
- Version 1.00.
2013-07-14
- Adopted to html

-->

<xsl:output method="text" indent="no"/>

<!-- BEGIN PARAMETERS -->

<xsl:param name="xmldepend.terminator" select="'&#x0A;'"/>

<!-- END PARAMETERS -->

<!-- BEGIN UTILITY TEMPLATES -->

<!--
  Given a pathname, return the basename (part after last '/'):
  - If path contains no '/' separators, return entire value
  - If path contains '/' separator, recurse using part after first one
-->

<xsl:template name="path-basename">
  <xsl:param name="path"/>
  <xsl:choose>
    <xsl:when test="not(contains($path,'/'))">
      <xsl:value-of select="$path"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="path-basename">
        <xsl:with-param name="path" select="substring-after($path,'/')"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!--
  Given a pathname, return the dirname (part up through last '/'):
  - If path contains no '/' separators, return empty string
  - If path contains '/' separator, return part up through last one
    (which is the same as the part before the basename)
-->

<xsl:template name="path-dirname">
  <xsl:param name="path"/>
  <xsl:choose>
    <xsl:when test="not(contains($path,'/'))">
      <!-- return nothing -->
    </xsl:when>
    <xsl:otherwise>
      <xsl:variable name="basename">
        <xsl:call-template name="path-basename">
          <xsl:with-param name="path" select="$path"/>
        </xsl:call-template>
      </xsl:variable>
      <xsl:value-of select="substring(
          $path,1,string-length($path) - string-length($basename)
      )"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- END UTILITY TEMPLATES -->

<!--
  Several elements have a fileref attribute.  Spit out the file named
  by any of them.  Resolve the filename relative to the directory of
  the referencing file unless the name is an absolute pathname.
-->

<xsl:template match="html:img[@src]" xmlns:html="http://www.w3.org/1999/xhtml">
  <xsl:param name="curdir"/>
  <xsl:if test="not(starts-with(@src,'/'))">
    <xsl:value-of select="$curdir"/>
  </xsl:if>
  <xsl:value-of select="@src"/>
  <xsl:value-of select="$xmldepend.terminator"/>
</xsl:template> 

<xsl:template match="img[@src]"> 
  <xsl:param name="curdir"/>
  <xsl:if test="not(starts-with(@src,'/'))">
    <xsl:value-of select="$curdir"/>
  </xsl:if>
  <xsl:value-of select="@src"/>
  <xsl:value-of select="$xmldepend.terminator"/>
</xsl:template> 

<!-- Identity transform, but keep track of current document directory -->

<xsl:template match="*">
  <xsl:param name="curdir"/>
  <xsl:apply-templates select="*">
    <xsl:with-param name="curdir" select="$curdir"/>
  </xsl:apply-templates>
</xsl:template>

</xsl:stylesheet>
