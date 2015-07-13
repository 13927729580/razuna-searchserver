<!---
*
* Copyright (C) 2005-2008 Razuna
*
* This file is part of Razuna - Enterprise Digital Asset Management.
*
* Razuna is free software: you can redistribute it and/or modify
* it under the terms of the GNU Affero Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* Razuna is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU Affero Public License for more details.
*
* You should have received a copy of the GNU Affero Public License
* along with Razuna. If not, see <http://www.gnu.org/licenses/>.
*
* You may restribute this Program with a special exception to the terms
* and conditions of version 3.0 of the AGPL as described in Razuna"s
* FLOSS exception. You should have received a copy of the FLOSS exception
* along with Razuna. If not, see <http://www.razuna.com/licenses/>.
*
--->
<cfcomponent output="false" extends="authentication">

	<!--- Create search collection --->
	<cffunction name="search" access="remote" output="false" returntype="struct" returnformat="json">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<cfargument name="secret" required="true" type="string">
		<cfargument name="startrow" required="true" type="numeric">
		<cfargument name="maxrows" required="true" type="numeric">
		<cfargument name="folderid" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Starting Search")>
		<!--- Check login --->
		<cfset auth(arguments.secret)>
		<!--- Param --->
		<cfset r.success = true>
		<cfset r.error = "">
		<cfset r.results = "">
		<!--- Call internal function --->
		<cfinvoke method="_search" returnvariable="r.results">
			<cfinvokeargument name="collection" value="#arguments.collection#" />
			<cfinvokeargument name="criteria" value="#arguments.criteria#" />
			<cfinvokeargument name="category" value="#arguments.category#" />
			<cfinvokeargument name="startrow" value="#arguments.startrow#" />
			<cfinvokeargument name="maxrows" value="#arguments.maxrows#" />
			<cfinvokeargument name="folderid" value="#arguments.folderid#" />
			<cfinvokeargument name="search_type" value="#arguments.search_type#" />
			<cfinvokeargument name="search_rendition" value="#arguments.search_rendition#" />
		</cfinvoke>
		<!--- Return --->
		<cfreturn r />
	</cffunction>

	


	<!--- PRIVATE --->


	

	<!--- Internal search --->
	<cffunction name="_search" access="private" output="false" returntype="query">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<cfargument name="startrow" required="true" type="numeric">
		<cfargument name="maxrows" required="true" type="numeric">
		<cfargument name="folderid" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">
		<!--- Param --->
		<cfset var results = "">
		<cfset var folderlist = "" />
		<!--- Search --->
		<cftry>
			<!--- Syntax --->
			<cfset var _criteria = _searchSyntax(criteria=arguments.criteria, search_type=arguments.search_type, search_rendition=arguments.search_rendition) />
			<!--- if the folderid is not 0 we need to filter by folderid --->
			<cfif arguments.folderid NEQ 0>
				<!--- New list var --->
				<cfset var counter_folderlist = 0>
				<!--- If more than 200 folders do the split, else normal operation --->
				<cfif listlen(arguments.folderid) GTE 200>
					<!--- Create new temp query for lucene results --->
					<cfset var results = queryNew("category, categorytree, rank, searchcount")>
					<!--- Create new list --->
					<cfset "variables.folderlist_#counter_folderlist#" = "">
					<!--- Loop over folders --->
					<cfloop list="#arguments.folderid#" index="folderid">
						<!--- If we have more than 200 in the current list create a new list --->
						<cfif listlen(variables["folderlist_" & counter_folderlist], " ") GTE 200>
							<!--- Increase counter --->
							<cfset counter_folderlist++>
							<!--- Create new list with new counter --->
							<cfset "variables.folderlist_#counter_folderlist#" = "">
						</cfif>
						<!--- Append to list --->
						<cfset "variables.folderlist_#counter_folderlist#" = variables["folderlist_" & counter_folderlist] & ' folder:("#folderid#")'>
						<cfset console("Folderlist: #counter_folderlist# " & variables["folderlist_" & counter_folderlist])>
					</cfloop>
					<!--- We go the individual folder lists, now loop over it and put together the criteria and search in Lucene --->
					<cfloop from="0" to="#counter_folderlist#" index="n">
						<!--- If the returning _criteria is empty we only tag on the folderlist (with this fix user can search with *) --->
						<cfif _criteria EQ "">
							<cfset "variables.criteria_#n#" = "( " & variables["folderlist_" & n] & " )" />
						<cfelse>
							<cfset "variables.criteria_#n#" = "( #_criteria# ) AND ( " & variables["folderlist_" & n] & " )" />
						</cfif>
						<!--- Call internal function --->
						<cfset "variables.results_#n#" = _embeddedSearch(collection=arguments.collection, criteria=variables["criteria_" & n], category=arguments.category, startrow=arguments.startrow, maxrows=arguments.maxrows)>
						<!--- Set result in variable as QoQ can't handle complex variables --->
						<cfset var _thisqry = variables["results_" & n]>
						<!--- Take the resultset from lucene and combine the searches --->
						<cfquery dbtype="query" name="results">
						SELECT category, categorytree, rank, searchcount
						FROM results
						UNION
						SELECT category, categorytree, rank, searchcount
						FROM _thisqry
						</cfquery>
					</cfloop>
					<!--- Now get the temp results table and sum up searchcount --->
					<cfquery dbtype="query" name="resultssum">
					SELECT sum(searchcount) as newcount
					FROM results
					</cfquery>
					<!--- And update all records --->
					<cfquery dbtype="query" name="results">
					SELECT category, categorytree, rank, '#resultssum.newcount#' AS searchcount
					FROM results
					</cfquery>
				<cfelse>
					<!--- Since it could be a list --->
					<cfloop list="#arguments.folderid#" index="i" delimiters=",">
						<cfset var folderlist = folderlist & ' folder:("#i#")' />
					</cfloop>
					<!--- If the returning _criteria is empty we only tag on the folderlist (with this fix user can search with *) --->
					<cfif _criteria EQ "">
						<cfset var _criteria = "( #folderlist# )" />
					<cfelse>
						<cfset var _criteria = "( #_criteria# ) AND ( #folderlist# )" />
					</cfif>
					<!--- Call internal function --->
					<cfset var results = _embeddedSearch(collection=arguments.collection, criteria=_criteria, category=arguments.category, startrow=arguments.startrow, maxrows=arguments.maxrows)>
				</cfif>
			<cfelse>
				<!--- Call internal function --->
				<cfset var results = _embeddedSearch(collection=arguments.collection, criteria=_criteria, category=arguments.category, startrow=arguments.startrow, maxrows=arguments.maxrows)>
			</cfif>
			<cfcatch type="any">
				<cfset consoleoutput(true)>
				<cfset console("#now()# ---------------------- START Error on search")>
				<cfset console(cfcatch)>
				<cfset console("#now()# ---------------------- END Error on search")>
				<cfset results = querynew("x")>
			</cfcatch>
		</cftry>
		<!--- Return --->
		<cfreturn results />
	</cffunction>

	<!--- Function for internal searches coming from above --->
	<cffunction name="_embeddedSearch" access="private" output="false">
		<cfargument name="collection" required="true" type="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="category" required="true" type="string">
		<cfargument name="startrow" required="true" type="string">
		<cfargument name="maxrows" required="true" type="string">
		<!--- Var --->
		<cfset var results = querynew("category, categorytree, rank, searchcount")>
		<!--- Log --->
		<cfset consoleoutput(true)>
		<cfset console("#now()# ---------------------- Search with start")>
		<cfset console(arguments.criteria)>
		<cfset console("#now()# ---------------------- Search with end")>
		<!--- Search in Lucene --->
		<cfsearch collection="#arguments.collection#" criteria="#arguments.criteria#" name="results" category="#arguments.category#" startrow="#arguments.startrow#" maxrows="#arguments.maxrows#">
		<!--- Only return the columns we need from Lucene --->
		<cfif results.recordcount NEQ 0>
			<cfquery dbtype="query" name="results">
			SELECT category, categorytree, rank, searchcount
			FROM results
			</cfquery>
		</cfif>
		<!--- Return --->
		<cfreturn results>
	</cffunction>

	<!--- Internal search --->
	<cffunction name="_searchSyntax" access="private" output="false" returntype="string">
		<cfargument name="criteria" required="true" type="string">
		<cfargument name="search_type" required="true" type="string">
		<cfargument name="search_rendition" required="true" type="string">

		<!--- 
		 Decode URL encoding that is encoded using the encodeURIComponent javascript method. 
		 Preserve the '+' sign during decoding as the URLDecode methode will remove it if present.
		 Do not use escape(deprecated) or encodeURI (doesn't encode '+' sign) methods to encode. Use the encodeURIComponent javascript method only.
		--->
		<cfset var criteria = replace(urlDecode(replace(arguments.criteria,"+","PLUSSIGN","ALL")),"PLUSSIGN","+","ALL")>
		<!--- If criteria is empty --->
		<cfif criteria EQ "" OR criteria EQ "*">
			<cfset var criteria = "">
		<!--- FOR DETAIL SEARCH WE LEAVE IT ALONE --->
		<cfelseif arguments.search_type EQ "adv">
			<cfset var criteria = criteria>
		<!--- SIMPLE SEARCH --->
		<!--- Put search together. If the criteria contains a ":" then we assume the user wants to search with his own fields --->
		<cfelseif NOT criteria CONTAINS ":" AND NOT criteria EQ "*">
			<cfset criteria = _escapelucenechars(criteria)>
			<!--- Replace spaces with AND if query doesn't contain AND, OR  or " --->
			<cfif find(" AND ", criteria) EQ 0 AND find(" OR ", criteria) EQ 0 AND find('"', criteria) EQ 0 >
				<cfset var criteria_sp = replace(criteria,chr(32)," AND ", "ALL")>
			<cfelse>	
				<cfset var criteria_sp = criteria>
			</cfif>
			<cfif criteria CONTAINS '"' OR criteria CONTAINS "*" OR find(" AND ", criteria) NEQ 0 OR find(" OR ", criteria) NEQ 0>
				<cfset var criteria = 'filename:("#criteria#") keywords:("#criteria_sp#") description:("#criteria_sp#") id:("#criteria_sp#") labels:("#criteria_sp#") customfieldvalue:("#criteria_sp#")'>
			<cfelse>
				<cfset var criteria = 'filename:(#criteria#*) keywords:(#criteria_sp#) description:(#criteria_sp#) id:(#criteria_sp#*) labels:(#criteria_sp#) customfieldvalue:(#criteria_sp#*) filename:("#criteria#") keywords:("#criteria_sp#") description:("#criteria_sp#") id:("#criteria_sp#") labels:("#criteria_sp#") customfieldvalue:("#criteria_sp#")'>
			</cfif>
			<cfset var criteria = '(' & criteria_sp  & ') ' & criteria />
		</cfif>
		<!--- Add rendition search to it --->
		<cfif arguments.search_rendition EQ "t">
			<cfif criteria EQ "" OR criteria EQ "*">
				<cfset var criteria = 'file_type:original'>
			<cfelse>
				<cfset var criteria = '(' & criteria & ') AND file_type:original'>
			</cfif>
		</cfif>
		<!--- Return --->
		<cfreturn criteria />
	</cffunction>

	<!--- Escapes lucene special characters in a given string --->
	<cffunction name="_escapelucenechars" returntype="String" access="private" returntype="string">
		<cfargument name="lucenestr" type="String" required="true">
		<!--- 
		The following lucene special characters will be escaped in searches
		\ ! {} [] - && || ()
		The following lucene special characters  will NOT be escaped as we want to allow users to use these in their search criterion 
		+ " ~ * ? : ^
		--->
		<cfset lucenestr = replace(arguments.lucenestr,"\","\\","ALL")>
		<cfset lucenestr = replace(lucenestr,"!","\!","ALL")>	
		<cfset lucenestr = replace(lucenestr,"{","\{","ALL")>
		<cfset lucenestr = replace(lucenestr,"}","\}","ALL")>
		<cfset lucenestr = replace(lucenestr,"[","\[","ALL")>
		<cfset lucenestr = replace(lucenestr,"]","\]","ALL")>
		<cfset lucenestr = replace(lucenestr,"-","\-","ALL")>
		<cfset lucenestr = replace(lucenestr,"&&","\&&","ALL")>	
		<cfset lucenestr = replace(lucenestr,"||","\||","ALL")>	
		<cfset lucenestr = replace(lucenestr,"||","\||","ALL")>	
		<cfset lucenestr = replace(lucenestr,"(","\(","ALL")>
		<cfset lucenestr = replace(lucenestr,")","\)","ALL")>		
		<!--- Return --->
		<cfreturn lucenestr>	
	</cffunction>


</cfcomponent>
